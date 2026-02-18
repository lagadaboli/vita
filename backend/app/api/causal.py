"""Causal engine API endpoints — /api/v1/causal/*."""

from __future__ import annotations

import time

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, desc, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models.health_event import HealthEvent
from app.models.reasoning_trace import ReasoningTrace
from app.schemas.causal import (
    CausalChainLink,
    CausalExplanationResponse,
    CounterfactualRequest,
    CounterfactualResponse,
    DebtScoreResponse,
    GlucoseCurrentResponse,
    SymptomQuery,
    TraceDetailResponse,
    TraceResponse,
)
from app.services.causal.agent import CausalAgent
from app.services.causal.digital_debt import (
    GlucoseCrash,
    ScreenEvent,
    compute_digital_debt,
)
from app.services.causal.glucose_classifier import (
    EnergyState,
    classify_energy_state,
    classify_trend,
)
from app.services.causal.metabolic_debt import MealDebtInput, compute_metabolic_debt
from app.services.causal.mcp_adapters import CGMSteloAdapter

router = APIRouter(prefix="/api/v1/causal", tags=["causal"])


@router.post("/query", response_model=CausalExplanationResponse)
async def causal_query(
    req: SymptomQuery,
    session: AsyncSession = Depends(get_session),
):
    """Run the 4-step causal reasoning agent for a symptom."""
    agent = CausalAgent(session)
    explanation = await agent.query(req.symptom)

    return CausalExplanationResponse(
        symptom=explanation.symptom,
        conclusion=explanation.conclusion,
        confidence=explanation.confidence,
        causal_chain=[
            CausalChainLink(**link) for link in explanation.causal_chain
        ],
        narrative=explanation.narrative,
        metabolic_debt=explanation.metabolic_debt,
        digital_debt=explanation.digital_debt,
        counterfactuals=explanation.counterfactuals,
        safety_bypass=explanation.safety_bypass,
        escalation_triggered=explanation.escalation_triggered,
    )


@router.get("/debt", response_model=DebtScoreResponse)
async def get_debt_scores(
    window_hours: int = Query(6, ge=1, le=168),
    session: AsyncSession = Depends(get_session),
):
    """Get current metabolic + digital debt scores for a time window."""
    cutoff_ms = int((time.time() - window_hours * 3600) * 1000)

    # Metabolic debt: gather glucose data around meal events
    # Simplified: use average glucose spike as proxy
    glucose_q = (
        select(HealthEvent)
        .where(HealthEvent.event_type == "glucose")
        .where(HealthEvent.timestamp_ms >= cutoff_ms)
        .order_by(HealthEvent.timestamp_ms.asc())
    )
    glucose_result = await session.execute(glucose_q)
    glucose_readings = list(glucose_result.scalars().all())

    metabolic_score = 0.0
    if glucose_readings:
        values = [r.value for r in glucose_readings]
        peak = max(values)
        nadir = min(values)
        avg_val = sum(values) / len(values)

        # Create a simplified meal debt input from available data
        meal_input = MealDebtInput(
            glycemic_load=avg_val * 0.3,  # Approximate GL
            peak_glucose=peak,
            nadir_glucose=nadir,
            post_meal_hrv_avg=50.0,  # Default if no HRV data
            baseline_hrv_avg=60.0,
            bioavailability_modifier=None,
            meal_hour=12,
        )

        # Check for HRV data
        hrv_q = (
            select(func.avg(HealthEvent.value))
            .where(HealthEvent.event_type == "hrv")
            .where(HealthEvent.timestamp_ms >= cutoff_ms)
        )
        hrv_result = await session.execute(hrv_q)
        hrv_avg = hrv_result.scalar_one_or_none()
        if hrv_avg:
            meal_input.post_meal_hrv_avg = hrv_avg
            meal_input.baseline_hrv_avg = hrv_avg * 1.1  # Rough baseline estimate

        metabolic_score = compute_metabolic_debt([meal_input])

    # Digital debt: gather screen time data
    screen_q = (
        select(HealthEvent)
        .where(HealthEvent.event_type == "screenTime")
        .where(HealthEvent.timestamp_ms >= cutoff_ms)
        .order_by(HealthEvent.timestamp_ms.asc())
    )
    screen_result = await session.execute(screen_q)
    screen_events = list(screen_result.scalars().all())

    digital_score = 0.0
    if screen_events:
        events = [
            ScreenEvent(
                start_ms=e.timestamp_ms,
                duration_seconds=e.value * 60,  # value in minutes
                dopamine_debt_score=0.0,
            )
            for e in screen_events
        ]
        digital_score = compute_digital_debt(events)

    return DebtScoreResponse(
        metabolic_debt=round(metabolic_score, 1),
        digital_debt=round(digital_score, 1),
        window_hours=window_hours,
    )


@router.get("/traces", response_model=list[TraceResponse])
async def list_traces(
    symptom: str | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    session: AsyncSession = Depends(get_session),
):
    """List reasoning traces, optionally filtered by symptom."""
    q = select(ReasoningTrace).order_by(desc(ReasoningTrace.id)).limit(limit)
    if symptom:
        q = q.where(ReasoningTrace.symptom == symptom)

    result = await session.execute(q)
    traces = result.scalars().all()

    return [
        TraceResponse(
            id=t.id,
            symptom=t.symptom,
            phase=t.phase,
            conclusion=t.conclusion,
            confidence=t.confidence,
            narrative=t.narrative,
            duration_ms=t.duration_ms,
            created_at=t.created_at,
        )
        for t in traces
    ]


@router.get("/traces/{trace_id}", response_model=TraceDetailResponse)
async def get_trace(
    trace_id: int,
    session: AsyncSession = Depends(get_session),
):
    """Get a specific reasoning trace with full detail."""
    result = await session.execute(
        select(ReasoningTrace).where(ReasoningTrace.id == trace_id)
    )
    trace = result.scalar_one_or_none()
    if trace is None:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="Trace not found")

    return TraceDetailResponse(
        id=trace.id,
        symptom=trace.symptom,
        phase=trace.phase,
        conclusion=trace.conclusion,
        confidence=trace.confidence,
        narrative=trace.narrative,
        duration_ms=trace.duration_ms,
        created_at=trace.created_at,
        hypotheses_json=trace.hypotheses_json,
        observations_json=trace.observations_json,
        causal_chain_json=trace.causal_chain_json,
    )


@router.get("/glucose/current", response_model=GlucoseCurrentResponse)
async def get_current_glucose(
    session: AsyncSession = Depends(get_session),
):
    """Get current glucose reading with trend and energy state."""
    cgm = CGMSteloAdapter(session)
    result = await cgm.get_current_glucose()

    if result.data is None:
        return GlucoseCurrentResponse()

    return GlucoseCurrentResponse(
        value_mg_dl=result.data.get("value_mg_dl"),
        trend=result.data.get("trend"),
        rate_mg_per_min=result.data.get("rate_mg_per_min"),
        energy_state=result.data.get("energy_state"),
        timestamp_ms=result.data.get("timestamp_ms"),
    )


@router.post("/counterfactual", response_model=CounterfactualResponse)
async def generate_counterfactual(
    req: CounterfactualRequest,
    session: AsyncSession = Depends(get_session),
):
    """Generate counterfactuals for a causal node."""
    counterfactuals: list[str] = []

    if req.node_id.startswith("meal_"):
        counterfactuals = [
            "Using multigrain flour instead could reduce glycemic load by ~35%",
            "Reducing portion by 1 serving could lower the glucose spike",
            "Eating earlier (before 8 PM) would remove the late-meal timing penalty",
        ]
    elif req.node_id.startswith("behavioral_"):
        counterfactuals = [
            "A 30-minute screen break could allow HRV recovery",
            "Enabling focus mode would reduce app-switching frequency",
            "Replacing passive scrolling with active engagement reduces dopamine debt",
        ]
    elif req.node_id.startswith("glucose_"):
        counterfactuals = [
            "A 10-minute walk post-meal could reduce the glucose spike by 20-30%",
            "Adding fiber-rich foods could flatten the glucose curve",
        ]
    else:
        counterfactuals = ["No counterfactuals available for this node type"]

    return CounterfactualResponse(
        node_id=req.node_id,
        counterfactuals=counterfactuals,
    )
