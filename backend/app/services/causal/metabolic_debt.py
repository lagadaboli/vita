"""Metabolic Debt Scorer — mirrors Swift MetabolicDebtScorer exactly.

Formula:
  mealDebt = (glFactor×0.3 + spikeMagnitude×0.3 + hrvDrop×0.25
              + (cookingModifier-0.8)×0.15) × timingPenalty
  totalDebt = (sum(mealDebts) / max(mealCount, 1)) × 100, clamped [0, 100]
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class MealDebtInput:
    """Input data for a single meal's debt calculation."""

    glycemic_load: float  # GL of the meal
    peak_glucose: float  # Max glucose 0-150 min post-meal (mg/dL)
    nadir_glucose: float  # Min glucose after peak (mg/dL)
    post_meal_hrv_avg: float  # Mean HRV 60-180 min post-meal (ms)
    baseline_hrv_avg: float  # Mean HRV 7-day lookback (ms)
    bioavailability_modifier: float | None  # From cooking method
    meal_hour: int  # 0-23, hour of the meal


def compute_meal_debt(meal: MealDebtInput) -> float:
    """Compute debt contribution for a single meal.

    Returns raw debt value (not yet scaled to 0-100).
    """
    # GL factor: normalized by 50
    gl_factor = min(meal.glycemic_load / 50.0, 1.0)

    # Spike magnitude: normalized by 80 mg/dL swing
    spike = meal.peak_glucose - meal.nadir_glucose
    spike_magnitude = min(spike / 80.0, 1.0) if spike > 0 else 0.0

    # HRV drop: fractional drop from baseline
    if meal.baseline_hrv_avg > 0:
        hrv_drop = max(
            (meal.baseline_hrv_avg - meal.post_meal_hrv_avg) / meal.baseline_hrv_avg,
            0.0,
        )
    else:
        hrv_drop = 0.0

    # Cooking modifier: better bioavailability → lower debt
    bio = meal.bioavailability_modifier
    if bio is not None:
        cooking_modifier = 0.8 if bio > 1.0 else 1.2
    else:
        cooking_modifier = 1.0

    # Timing penalty: late meals (≥ 8 PM) get 1.3x
    timing_penalty = 1.3 if meal.meal_hour >= 20 else 1.0

    # Weighted sum
    debt = (
        gl_factor * 0.3
        + spike_magnitude * 0.3
        + hrv_drop * 0.25
        + (cooking_modifier - 0.8) * 0.15
    ) * timing_penalty

    return debt


def compute_metabolic_debt(meals: list[MealDebtInput]) -> float:
    """Compute aggregate metabolic debt score for a time window.

    Returns score clamped to [0, 100].
    """
    if not meals:
        return 0.0

    total = sum(compute_meal_debt(m) for m in meals)
    score = (total / max(len(meals), 1)) * 100.0
    return max(0.0, min(score, 100.0))
