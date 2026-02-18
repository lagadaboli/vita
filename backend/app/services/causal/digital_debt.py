"""Digital Debt Scorer — mirrors Swift DigitalDebtScorer exactly.

Formula:
  digitalDebt = min(screenTimeFactor + dopamineFactor, 100)
  screenTimeFactor = min(genuineMinutes / 60, 1.0) × 60
  dopamineFactor = maxDopamineDebt × 0.4
  genuineMinutes excludes reactive scrolling (within 30min of glucose crash)

Dopamine debt (per behavioral event):
  = (0.4×passiveNorm + 0.3×switchFreqNorm + 0.2×(1-focusNorm) + 0.1×lateNightNorm) × 100
  clamped [0, 100]
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class ScreenEvent:
    """A passive screen consumption event."""

    start_ms: int
    duration_seconds: float
    dopamine_debt_score: float = 0.0  # Pre-computed per-event dopamine debt


@dataclass
class GlucoseCrash:
    """A glucose crash event for reactive scrolling detection."""

    timestamp_ms: int  # When the crash/reactiveLow was detected


REACTIVE_WINDOW_MS = 30 * 60 * 1000  # 30 minutes in milliseconds


def _is_reactive(event: ScreenEvent, crashes: list[GlucoseCrash]) -> bool:
    """Check if a screen event is reactive scrolling (within 30min of a crash)."""
    for crash in crashes:
        if 0 <= (event.start_ms - crash.timestamp_ms) <= REACTIVE_WINDOW_MS:
            return True
    return False


def compute_dopamine_debt(
    passive_minutes_last_3h: float,
    app_switch_frequency_z_score: float,
    focus_mode_ratio: float,
    late_night_penalty: float,
) -> float:
    """Compute dopamine debt score for a behavioral event.

    Returns score clamped to [0, 100].
    """
    passive_norm = min(passive_minutes_last_3h / 60.0, 1.0)
    switch_norm = min(max(app_switch_frequency_z_score, 0.0), 1.0)
    focus_norm = min(max(focus_mode_ratio, 0.0), 1.0)
    late_norm = min(max(late_night_penalty, 0.0), 1.0)

    score = (
        0.4 * passive_norm
        + 0.3 * switch_norm
        + 0.2 * (1.0 - focus_norm)
        + 0.1 * late_norm
    ) * 100.0

    return max(0.0, min(score, 100.0))


def compute_digital_debt(
    events: list[ScreenEvent],
    crashes: list[GlucoseCrash] | None = None,
) -> float:
    """Compute digital debt score.

    Returns score clamped to [0, 100].
    """
    if not events:
        return 0.0

    crashes = crashes or []

    # Filter out reactive scrolling, sum genuine minutes
    genuine_minutes = 0.0
    max_dopamine_debt = 0.0

    for evt in events:
        if not _is_reactive(evt, crashes):
            genuine_minutes += evt.duration_seconds / 60.0
        max_dopamine_debt = max(max_dopamine_debt, evt.dopamine_debt_score)

    # Screen time factor: 0-60 points
    screen_time_factor = min(genuine_minutes / 60.0, 1.0) * 60.0

    # Dopamine factor: 0-40 points
    dopamine_factor = max_dopamine_debt * 0.4

    return min(screen_time_factor + dopamine_factor, 100.0)
