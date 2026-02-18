"""4-step ReAct causal reasoning agent.

Steps:
  1. Initial Pulse — read HRV + glucose, check safety
  2. Causal Hypothesis — generate hypotheses from DAG topology
  3. Targeted Probe — query MCP adapters for evidence
  4. Final Inference — compute debt scores, build causal chain, persist trace

Max 3 iterations, confidence ≥ 0.7 for early termination.
"""

from __future__ import annotations

import json
import logging
import time
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.causal_edge import CausalEdge
from app.models.reasoning_trace import ReasoningTrace
from app.services.causal.dag import (
    CausalDAG,
    DAGEdge,
    EdgeType,
    NodeType,
    TOPOLOGICAL_ORDER,
    node_type_from_id,
)
from app.services.causal.guardrails import (
    SafetyCheckResult,
    apply_hallucination_guard,
    check_hrv_safety,
    sanitize_for_sms,
)
from app.services.causal.mcp_adapters import (
    AppleHealthAdapter,
    CGMSteloAdapter,
    InstacartServerAdapter,
    MCPToolResult,
    RotimaticServerAdapter,
    StateStoreMCPAdapter,
)

logger = logging.getLogger(__name__)

MAX_ITERATIONS = 3
CONFIDENCE_THRESHOLD = 0.7


@dataclass
class Hypothesis:
    """A causal hypothesis generated during reasoning."""

    source_type: str  # e.g. "metabolic", "digital"
    description: str
    prior_probability: float = 0.5


@dataclass
class Observation:
    """An observation gathered from MCP adapters."""

    source: str
    data: dict[str, Any] | None
    supports_hypothesis: str | None = None  # which hypothesis it supports


@dataclass
class CausalExplanation:
    """Final output of the agent's reasoning loop."""

    symptom: str
    conclusion: str | None  # "metabolic" / "digital" / None
    confidence: float
    causal_chain: list[dict[str, Any]]
    narrative: str
    metabolic_debt: float | None = None
    digital_debt: float | None = None
    counterfactuals: list[str] = field(default_factory=list)
    safety_bypass: bool = False
    escalation_triggered: bool = False


class CausalAgent:
    """Neuro-symbolic causal reasoning agent."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.apple_health = AppleHealthAdapter(session)
        self.cgm = CGMSteloAdapter(session)
        self.rotimatic = RotimaticServerAdapter(session)
        self.instacart = InstacartServerAdapter(session)
        self.state_store = StateStoreMCPAdapter(session)
        self.dag = CausalDAG()

    async def query(self, symptom: str) -> CausalExplanation:
        """Run the 4-step reasoning loop for a symptom query.

        Returns a CausalExplanation with the agent's conclusion.
        """
        start_ms = int(time.time() * 1000)
        hypotheses: list[Hypothesis] = []
        observations: list[Observation] = []

        # === Step 1: Initial Pulse ===
        pulse_result = await self.apple_health.get_pulse()
        glucose_result = await self.cgm.get_current_glucose()

        safety = check_hrv_safety(pulse_result.data)
        if not safety.is_safe:
            explanation = await self._handle_safety_bypass(
                symptom, safety, start_ms
            )
            return explanation

        observations.append(
            Observation(source="apple_health", data=pulse_result.data)
        )
        observations.append(
            Observation(source="cgm_stelo", data=glucose_result.data)
        )

        # === Step 2: Causal Hypothesis ===
        hypotheses = self._generate_hypotheses(glucose_result)

        # === Step 3: Targeted Probe (iterative) ===
        adapter_results: dict[str, MCPToolResult] = {
            "apple_health": pulse_result,
            "cgm_stelo": glucose_result,
        }

        for iteration in range(MAX_ITERATIONS):
            # Probe based on current top hypothesis
            new_observations = await self._probe(hypotheses, adapter_results)
            observations.extend(new_observations)

            # Update adapter results for hallucination guard
            for obs in new_observations:
                if obs.source not in adapter_results:
                    adapter_results[obs.source] = MCPToolResult(
                        data=obs.data, source=obs.source
                    )

            # Check if we have enough confidence to stop
            confidence = self._compute_confidence(hypotheses, observations)
            if confidence >= CONFIDENCE_THRESHOLD:
                break

        # === Step 4: Final Inference ===
        excluded_sources = apply_hallucination_guard(adapter_results)
        explanation = self._infer(
            symptom, hypotheses, observations, excluded_sources, start_ms
        )

        # Persist reasoning trace
        await self._persist_trace(explanation, hypotheses, observations, start_ms)

        return explanation

    def _generate_hypotheses(
        self, glucose_result: MCPToolResult
    ) -> list[Hypothesis]:
        """Generate hypotheses based on available data and DAG topology."""
        hypotheses: list[Hypothesis] = []

        # If glucose > 140, prioritize metabolic branch
        glucose_value = None
        if glucose_result.data:
            glucose_value = glucose_result.data.get("value_mg_dl")

        if glucose_value and glucose_value > 140:
            hypotheses.append(
                Hypothesis(
                    source_type="metabolic",
                    description="Elevated glucose suggests recent meal is driving symptoms via metabolic pathway",
                    prior_probability=0.6,
                )
            )
            hypotheses.append(
                Hypothesis(
                    source_type="digital",
                    description="Digital behavior may be contributing to symptoms via HRV suppression",
                    prior_probability=0.3,
                )
            )
        else:
            # Default topological order
            hypotheses.append(
                Hypothesis(
                    source_type="metabolic",
                    description="Meal composition may be driving symptoms via glucose response",
                    prior_probability=0.4,
                )
            )
            hypotheses.append(
                Hypothesis(
                    source_type="digital",
                    description="Screen behavior may be driving symptoms via dopamine/HRV pathway",
                    prior_probability=0.4,
                )
            )

        return hypotheses

    async def _probe(
        self,
        hypotheses: list[Hypothesis],
        existing_results: dict[str, MCPToolResult],
    ) -> list[Observation]:
        """Probe MCP adapters based on current hypotheses."""
        observations: list[Observation] = []

        # Sort hypotheses by probability
        sorted_hyp = sorted(hypotheses, key=lambda h: h.prior_probability, reverse=True)

        for hyp in sorted_hyp:
            if hyp.source_type == "metabolic" and "rotimatic_server" not in existing_results:
                result = await self.rotimatic.get_last_session()
                existing_results["rotimatic_server"] = result
                observations.append(
                    Observation(
                        source="rotimatic_server",
                        data=result.data,
                        supports_hypothesis="metabolic",
                    )
                )

            if hyp.source_type in ("metabolic", "digital") and "instacart_server" not in existing_results:
                result = await self.instacart.get_recent_receipts()
                existing_results["instacart_server"] = result
                observations.append(
                    Observation(
                        source="instacart_server",
                        data=result.data,
                        supports_hypothesis="metabolic",
                    )
                )

        return observations

    def _compute_confidence(
        self,
        hypotheses: list[Hypothesis],
        observations: list[Observation],
    ) -> float:
        """Compute confidence based on available evidence."""
        if not observations:
            return 0.0

        data_sources = sum(1 for obs in observations if obs.data is not None)
        total = len(observations)

        if total == 0:
            return 0.0

        # Base confidence from data coverage
        coverage = data_sources / total

        # Boost for strong glucose signal
        glucose_obs = [
            obs for obs in observations
            if obs.source == "cgm_stelo" and obs.data
        ]
        glucose_boost = 0.0
        if glucose_obs:
            val = glucose_obs[0].data.get("value_mg_dl")
            if val and (val > 160 or val < 70):
                glucose_boost = 0.2

        return min(coverage * 0.6 + 0.3 + glucose_boost, 1.0)

    def _infer(
        self,
        symptom: str,
        hypotheses: list[Hypothesis],
        observations: list[Observation],
        excluded_sources: set[str],
        start_ms: int,
    ) -> CausalExplanation:
        """Build final causal explanation from evidence."""
        # Score each hypothesis
        scores: dict[str, float] = {}
        for hyp in hypotheses:
            score = hyp.prior_probability * 0.2
            for obs in observations:
                if obs.data is None:
                    continue
                if obs.source in excluded_sources:
                    continue
                if obs.supports_hypothesis == hyp.source_type:
                    score += 0.3
            scores[hyp.source_type] = score

        # Determine conclusion
        if not scores:
            conclusion = None
            confidence = 0.0
        else:
            conclusion = max(scores, key=scores.get)  # type: ignore[arg-type]
            total_score = sum(scores.values())
            confidence = scores[conclusion] / total_score if total_score > 0 else 0.0

        # Build causal chain
        causal_chain = self._build_causal_chain(conclusion, observations)

        # Generate narrative
        narrative = self._generate_narrative(
            symptom, conclusion, confidence, observations, excluded_sources
        )

        # Generate counterfactuals
        counterfactuals = self._generate_counterfactuals(conclusion, observations)

        return CausalExplanation(
            symptom=symptom,
            conclusion=conclusion,
            confidence=round(confidence, 3),
            causal_chain=causal_chain,
            narrative=narrative,
            counterfactuals=counterfactuals,
        )

    def _build_causal_chain(
        self,
        conclusion: str | None,
        observations: list[Observation],
    ) -> list[dict[str, Any]]:
        """Build causal chain from observations following DAG edges."""
        chain: list[dict[str, Any]] = []

        if conclusion == "metabolic":
            # meal → glucose → physiological → symptom
            chain.append({"from": "meal", "to": "glucose", "edge": EdgeType.meal_to_glucose.value})
            chain.append({"from": "glucose", "to": "physiological", "edge": EdgeType.glucose_to_hrv.value})
        elif conclusion == "digital":
            # behavioral → physiological → symptom
            chain.append({"from": "behavioral", "to": "physiological", "edge": EdgeType.behavior_to_hrv.value})

        return chain

    def _generate_narrative(
        self,
        symptom: str,
        conclusion: str | None,
        confidence: float,
        observations: list[Observation],
        excluded_sources: set[str],
    ) -> str:
        """Generate human-readable narrative of the reasoning."""
        parts = [f'Investigating symptom: "{symptom}".']

        data_sources = [
            obs.source for obs in observations
            if obs.data is not None and obs.source not in excluded_sources
        ]
        if data_sources:
            parts.append(f"Data from: {', '.join(data_sources)}.")

        if excluded_sources:
            parts.append(
                f"No data from: {', '.join(excluded_sources)} (excluded from reasoning)."
            )

        if conclusion == "metabolic":
            parts.append(
                "Evidence points to a metabolic pathway: meal composition affecting "
                "glucose response, which in turn impacts physiological markers."
            )
        elif conclusion == "digital":
            parts.append(
                "Evidence points to a digital pathway: screen behavior patterns "
                "affecting HRV and autonomic regulation."
            )
        else:
            parts.append("Insufficient evidence to determine a clear causal pathway.")

        parts.append(f"Confidence: {confidence:.0%}.")
        return " ".join(parts)

    def _generate_counterfactuals(
        self,
        conclusion: str | None,
        observations: list[Observation],
    ) -> list[str]:
        """Generate counterfactual suggestions."""
        counterfactuals: list[str] = []

        if conclusion == "metabolic":
            # Check if rotimatic data available
            roti_obs = [o for o in observations if o.source == "rotimatic_server" and o.data]
            if roti_obs:
                data = roti_obs[0].data
                flour = data.get("flour_type") if data else None
                if flour == "white":
                    counterfactuals.append(
                        "Switching from white to multigrain flour could reduce glycemic load by ~35%"
                    )
                count = data.get("roti_count") if data else None
                if count and count > 3:
                    counterfactuals.append(
                        "Reducing portion by 1 roti could lower the glucose spike"
                    )

            counterfactuals.append(
                "Eating earlier in the evening (before 8 PM) would remove the late-meal timing penalty"
            )

        elif conclusion == "digital":
            counterfactuals.append(
                "A 30-minute screen break could allow HRV recovery"
            )
            counterfactuals.append(
                "Enabling focus mode would reduce app-switching frequency"
            )

        return counterfactuals

    async def _handle_safety_bypass(
        self,
        symptom: str,
        safety: SafetyCheckResult,
        start_ms: int,
    ) -> CausalExplanation:
        """Handle HRV < 20ms safety bypass — immediate Rest Intervention."""
        logger.warning(
            f"HRV safety bypass triggered: {safety.hrv_value}ms < 20ms"
        )

        # Persist the safety bypass as a trace
        trace = ReasoningTrace(
            symptom=symptom,
            phase="pulse",
            hypotheses_json="[]",
            observations_json=json.dumps([{
                "source": "apple_health",
                "hrv_ms": safety.hrv_value,
                "safety_bypass": True,
            }]),
            conclusion=None,
            confidence=1.0,
            duration_ms=int(time.time() * 1000) - start_ms,
            causal_chain_json="[]",
            narrative=safety.escalation_reason,
        )
        await self.state_store.save_trace(trace)

        # Trigger Twilio escalation with privacy-safe message
        sms_body = sanitize_for_sms(
            symptom="Low heart rate variability",
            conclusion=None,
            confidence=1.0,
        )

        escalation_triggered = False
        try:
            from app.services.twilio_service import twilio_service

            if twilio_service.is_configured:
                await twilio_service.send_escalation_sms(
                    symptom="Low heart rate variability",
                    reason="Immediate rest intervention recommended",
                    confidence=1.0,
                )
                escalation_triggered = True
        except Exception:
            logger.exception("Failed to send safety escalation SMS")

        await self.session.commit()

        return CausalExplanation(
            symptom=symptom,
            conclusion=None,
            confidence=1.0,
            causal_chain=[],
            narrative=(
                "Safety bypass activated: critically low heart rate variability detected. "
                "All reasoning paused. Immediate rest intervention recommended."
            ),
            safety_bypass=True,
            escalation_triggered=escalation_triggered,
        )

    async def _persist_trace(
        self,
        explanation: CausalExplanation,
        hypotheses: list[Hypothesis],
        observations: list[Observation],
        start_ms: int,
    ) -> None:
        """Persist the reasoning trace to the database."""
        trace = ReasoningTrace(
            symptom=explanation.symptom,
            phase="inference",
            hypotheses_json=json.dumps([
                {"type": h.source_type, "description": h.description, "prior": h.prior_probability}
                for h in hypotheses
            ]),
            observations_json=json.dumps([
                {"source": o.source, "has_data": o.data is not None, "supports": o.supports_hypothesis}
                for o in observations
            ]),
            conclusion=explanation.conclusion,
            confidence=explanation.confidence,
            duration_ms=int(time.time() * 1000) - start_ms,
            causal_chain_json=json.dumps(explanation.causal_chain),
            narrative=explanation.narrative,
        )
        await self.state_store.save_trace(trace)
        await self.session.commit()
