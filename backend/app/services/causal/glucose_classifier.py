"""Glucose trend and energy state classification — mirrors Swift GlucoseReading."""

from __future__ import annotations

from enum import Enum


class GlucoseTrend(str, Enum):
    """Rate-of-change classification for CGM readings."""

    rapidly_rising = "rapidlyRising"  # > +3 mg/dL/min
    rising = "rising"  # +1 to +3 mg/dL/min
    stable = "stable"  # -1 to +1 mg/dL/min
    falling = "falling"  # -1 to -3 mg/dL/min
    rapidly_falling = "rapidlyFalling"  # < -3 mg/dL/min


class EnergyState(str, Enum):
    """Metabolic energy state derived from glucose trajectory."""

    stable = "stable"  # 70-120 mg/dL, flat curve
    rising = "rising"  # Post-meal spike in progress
    crashing = "crashing"  # Rapid decline >30 mg/dL from peak
    reactive_low = "reactiveLow"  # Below baseline after a spike


def classify_trend(rate_mg_per_min: float) -> GlucoseTrend:
    """Classify glucose rate of change into a trend category.

    Boundaries mirror Swift: rising = [1, 3), stable = (-1, 1).
    Rate of exactly 1.0 is `rising`, exactly -1.0 is `falling`.
    """
    if rate_mg_per_min > 3.0:
        return GlucoseTrend.rapidly_rising
    elif rate_mg_per_min >= 1.0:
        return GlucoseTrend.rising
    elif rate_mg_per_min > -1.0:
        return GlucoseTrend.stable
    elif rate_mg_per_min >= -3.0:
        return GlucoseTrend.falling
    else:
        return GlucoseTrend.rapidly_falling


def classify_energy_state(
    current_mg_dl: float,
    delta_from_peak: float,
    baseline_mg_dl: float = 90.0,
) -> EnergyState:
    """Classify metabolic energy state from glucose trajectory.

    Mirrors Swift classifyEnergyState exactly:
    - reactiveLow: below (baseline - 10) AND delta from peak < -30
    - crashing: delta from peak < -30
    - rising: current > 140 OR delta from peak > 20
    - stable: everything else
    """
    if current_mg_dl < (baseline_mg_dl - 10) and delta_from_peak < -30:
        return EnergyState.reactive_low
    elif delta_from_peak < -30:
        return EnergyState.crashing
    elif current_mg_dl > 140 or delta_from_peak > 20:
        return EnergyState.rising
    else:
        return EnergyState.stable
