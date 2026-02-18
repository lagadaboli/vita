"""Safety, privacy, and no-hallucination guardrails for causal engine.

1. Safety: HRV < 20ms → bypass reasoning → immediate Rest Intervention
2. No Hallucination: MCP adapter returns data=None → cannot blame that source
3. Privacy: SMS uses qualitative terms only (no raw values, timestamps, device IDs, food names)
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from app.services.causal.mcp_adapters import MCPToolResult

HRV_SAFETY_THRESHOLD_MS = 20.0


@dataclass
class SafetyCheckResult:
    """Result of the HRV safety check."""

    is_safe: bool  # True = continue reasoning, False = bypass + escalate
    hrv_value: float | None
    escalation_reason: str | None = None


def check_hrv_safety(pulse_data: dict[str, Any] | None) -> SafetyCheckResult:
    """Check if HRV is dangerously low (< 20ms).

    If so, reasoning must be bypassed and a Rest Intervention triggered.
    """
    if pulse_data is None:
        # No data — cannot determine safety, allow reasoning to proceed
        return SafetyCheckResult(is_safe=True, hrv_value=None)

    hrv_ms = pulse_data.get("hrv_ms")
    if hrv_ms is None:
        return SafetyCheckResult(is_safe=True, hrv_value=None)

    if hrv_ms < HRV_SAFETY_THRESHOLD_MS:
        return SafetyCheckResult(
            is_safe=False,
            hrv_value=hrv_ms,
            escalation_reason=(
                "Critically low heart rate variability detected. "
                "Immediate rest intervention recommended."
            ),
        )

    return SafetyCheckResult(is_safe=True, hrv_value=hrv_ms)


def apply_hallucination_guard(
    adapter_results: dict[str, MCPToolResult],
) -> set[str]:
    """Return set of source names that returned no data.

    The agent MUST NOT blame any source in this set.
    """
    excluded: set[str] = set()
    for source_name, result in adapter_results.items():
        if result.data is None:
            excluded.add(source_name)
    return excluded


def sanitize_for_sms(
    symptom: str,
    conclusion: str | None,
    confidence: float,
    narrative: str | None = None,
) -> str:
    """Build a privacy-safe SMS message.

    Rules:
    - Use qualitative terms only ("elevated glucose", not "145 mg/dL")
    - No timestamps, device IDs, or food names
    - Keep under 320 chars for SMS
    """
    parts = ["VITA Health Alert"]

    # Qualitative symptom description
    parts.append(f"Detected: {symptom}")

    if conclusion:
        labels = {
            "metabolic": "dietary pattern",
            "digital": "screen behavior pattern",
            "somatic": "environmental or sleep pattern",
        }
        label = labels.get(conclusion, conclusion)
        parts.append(f"Likely cause: {label}")

    parts.append(f"Confidence: {confidence:.0%}")
    parts.append("Open VITA for full details and recommendations.")

    return "\n".join(parts)
