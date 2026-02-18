"""Tests for MetabolicDebtScorer — verifies exact Swift formula alignment."""

import pytest

from app.services.causal.metabolic_debt import (
    MealDebtInput,
    compute_meal_debt,
    compute_metabolic_debt,
)


def _make_meal(**overrides) -> MealDebtInput:
    """Helper to create a MealDebtInput with sensible defaults."""
    defaults = dict(
        glycemic_load=25.0,
        peak_glucose=160.0,
        nadir_glucose=90.0,
        post_meal_hrv_avg=45.0,
        baseline_hrv_avg=60.0,
        bioavailability_modifier=None,
        meal_hour=12,
    )
    defaults.update(overrides)
    return MealDebtInput(**defaults)


class TestComputeMealDebt:
    def test_zero_gl(self):
        meal = _make_meal(glycemic_load=0.0, peak_glucose=90.0, nadir_glucose=90.0,
                          post_meal_hrv_avg=60.0, baseline_hrv_avg=60.0)
        debt = compute_meal_debt(meal)
        # glFactor=0, spike=0, hrvDrop=0, cookingMod=1.0 → (1.0-0.8)*0.15 = 0.03
        assert pytest.approx(debt, abs=0.01) == 0.03

    def test_gl_factor_clamped(self):
        """GL of 100 should clamp glFactor to 1.0 (100/50 = 2.0 → 1.0)."""
        meal = _make_meal(glycemic_load=100.0, peak_glucose=90.0, nadir_glucose=90.0,
                          post_meal_hrv_avg=60.0, baseline_hrv_avg=60.0)
        debt = compute_meal_debt(meal)
        # glFactor=1.0, spike=0, hrvDrop=0, cooking=0.03 → 0.3 + 0.03 = 0.33
        assert pytest.approx(debt, abs=0.01) == 0.33

    def test_spike_magnitude(self):
        """Peak-nadir of 80 gives spike_magnitude = 1.0."""
        meal = _make_meal(glycemic_load=0.0, peak_glucose=170.0, nadir_glucose=90.0,
                          post_meal_hrv_avg=60.0, baseline_hrv_avg=60.0)
        debt = compute_meal_debt(meal)
        # glFactor=0, spike=1.0 → 0.3, hrvDrop=0, cooking=0.03 → 0.33
        assert pytest.approx(debt, abs=0.01) == 0.33

    def test_hrv_drop(self):
        """HRV drop from 60 to 30 → 50% drop."""
        meal = _make_meal(glycemic_load=0.0, peak_glucose=90.0, nadir_glucose=90.0,
                          post_meal_hrv_avg=30.0, baseline_hrv_avg=60.0)
        debt = compute_meal_debt(meal)
        # glFactor=0, spike=0, hrvDrop=0.5 → 0.5*0.25=0.125, cooking=0.03 → 0.155
        assert pytest.approx(debt, abs=0.01) == 0.155

    def test_cooking_modifier_good_bio(self):
        """bioavailability > 1.0 → cooking_modifier = 0.8 → (0.8-0.8)*0.15 = 0."""
        meal = _make_meal(glycemic_load=0.0, peak_glucose=90.0, nadir_glucose=90.0,
                          post_meal_hrv_avg=60.0, baseline_hrv_avg=60.0,
                          bioavailability_modifier=1.35)
        debt = compute_meal_debt(meal)
        assert pytest.approx(debt, abs=0.001) == 0.0

    def test_cooking_modifier_poor_bio(self):
        """bioavailability ≤ 1.0 → cooking_modifier = 1.2 → (1.2-0.8)*0.15 = 0.06."""
        meal = _make_meal(glycemic_load=0.0, peak_glucose=90.0, nadir_glucose=90.0,
                          post_meal_hrv_avg=60.0, baseline_hrv_avg=60.0,
                          bioavailability_modifier=0.9)
        debt = compute_meal_debt(meal)
        assert pytest.approx(debt, abs=0.01) == 0.06

    def test_timing_penalty_late_meal(self):
        """Meal at 8 PM or later gets 1.3x penalty."""
        meal_early = _make_meal(meal_hour=18)
        meal_late = _make_meal(meal_hour=20)
        debt_early = compute_meal_debt(meal_early)
        debt_late = compute_meal_debt(meal_late)
        assert pytest.approx(debt_late / debt_early, abs=0.01) == 1.3

    def test_timing_penalty_exact_boundary(self):
        """Hour 20 is late, hour 19 is not."""
        meal_19 = _make_meal(meal_hour=19)
        meal_20 = _make_meal(meal_hour=20)
        assert compute_meal_debt(meal_20) > compute_meal_debt(meal_19)

    def test_full_formula(self):
        """Full formula with all components active."""
        meal = _make_meal(
            glycemic_load=50.0,       # glFactor = 1.0
            peak_glucose=170.0,       # spike = 80/80 = 1.0
            nadir_glucose=90.0,
            post_meal_hrv_avg=30.0,   # hrvDrop = (60-30)/60 = 0.5
            baseline_hrv_avg=60.0,
            bioavailability_modifier=0.9,  # cooking = 1.2, delta = 0.4
            meal_hour=21,             # timing = 1.3
        )
        debt = compute_meal_debt(meal)
        # (1.0*0.3 + 1.0*0.3 + 0.5*0.25 + 0.4*0.15) * 1.3
        # (0.3 + 0.3 + 0.125 + 0.06) * 1.3 = 0.785 * 1.3 = 1.0205
        assert pytest.approx(debt, abs=0.01) == 1.0205


class TestComputeMetabolicDebt:
    def test_empty(self):
        assert compute_metabolic_debt([]) == 0.0

    def test_single_meal(self):
        meal = _make_meal(glycemic_load=25.0)
        score = compute_metabolic_debt([meal])
        assert 0.0 <= score <= 100.0

    def test_clamped_to_100(self):
        """Even extreme values should be clamped to 100."""
        meals = [
            _make_meal(
                glycemic_load=200.0,
                peak_glucose=300.0,
                nadir_glucose=50.0,
                post_meal_hrv_avg=10.0,
                baseline_hrv_avg=80.0,
                bioavailability_modifier=0.5,
                meal_hour=23,
            )
        ]
        score = compute_metabolic_debt(meals)
        assert score <= 100.0

    def test_averages_over_meals(self):
        """Score is average of meal debts × 100."""
        meal1 = _make_meal(glycemic_load=0.0, peak_glucose=90.0, nadir_glucose=90.0,
                           post_meal_hrv_avg=60.0, baseline_hrv_avg=60.0)
        meal2 = _make_meal(glycemic_load=50.0, peak_glucose=170.0, nadir_glucose=90.0,
                           post_meal_hrv_avg=30.0, baseline_hrv_avg=60.0)
        score_single = compute_metabolic_debt([meal2])
        score_avg = compute_metabolic_debt([meal1, meal2])
        # Averaging with a low-debt meal should reduce the score
        assert score_avg < score_single

    def test_zero_baseline_hrv(self):
        """Zero baseline HRV should not cause division by zero."""
        meal = _make_meal(baseline_hrv_avg=0.0)
        score = compute_metabolic_debt([meal])
        assert score >= 0.0
