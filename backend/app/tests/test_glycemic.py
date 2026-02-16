"""Tests for glycemic load and bioavailability computation."""

import pytest

from app.schemas.meal import Ingredient
from app.services.glycemic import (
    compute_bioavailability_modifier,
    compute_glycemic_load,
    rotimatic_ingredients,
)


class TestComputeGlycemicLoad:
    def test_single_ingredient(self):
        ingredients = [
            Ingredient(name="white rice", quantity_grams=150, glycemic_index=73)
        ]
        # GL = (73 * 150 * 0.7) / 100 = 76.65
        assert compute_glycemic_load(ingredients) == pytest.approx(76.65, abs=0.01)

    def test_multiple_ingredients(self):
        ingredients = [
            Ingredient(name="white rice", quantity_grams=100, glycemic_index=73),
            Ingredient(name="lentils", quantity_grams=50, glycemic_index=32),
        ]
        # GL = (73 * 100 * 0.7) / 100 + (32 * 50 * 0.7) / 100 = 51.1 + 11.2 = 62.3
        assert compute_glycemic_load(ingredients) == pytest.approx(62.3, abs=0.01)

    def test_missing_gi(self):
        ingredients = [
            Ingredient(name="olive oil", quantity_grams=15)  # No GI
        ]
        assert compute_glycemic_load(ingredients) == 0.0

    def test_missing_grams(self):
        ingredients = [
            Ingredient(name="sugar", glycemic_index=65)  # No grams
        ]
        assert compute_glycemic_load(ingredients) == 0.0

    def test_empty_ingredients(self):
        assert compute_glycemic_load([]) == 0.0

    def test_rotimatic_whole_wheat(self):
        """Mirrors Swift MealEvent.computedGlycemicLoad for 4 whole wheat rotis."""
        ingredients = rotimatic_ingredients("whole_wheat", 4)
        gl = compute_glycemic_load(ingredients)
        # GL = (54 * 120 * 0.7) / 100 = 45.36
        assert gl == pytest.approx(45.36, abs=0.01)


class TestBioavailabilityModifier:
    def test_high_lectin_neutralization(self):
        assert compute_bioavailability_modifier("high_lectin_neutralization") == 1.35

    def test_moderate_lectin_neutralization(self):
        assert compute_bioavailability_modifier("moderate_lectin_neutralization") == 1.15

    def test_baseline_lectin_retention(self):
        assert compute_bioavailability_modifier("baseline_lectin_retention") == 0.90

    def test_fat_soluble(self):
        assert compute_bioavailability_modifier("fat_soluble_vitamin_enhancement") == 1.20

    def test_water_soluble(self):
        assert compute_bioavailability_modifier("water_soluble_vitamin_reduction") == 0.85

    def test_probiotic(self):
        assert compute_bioavailability_modifier("probiotic_generation") == 1.10

    def test_none(self):
        assert compute_bioavailability_modifier(None) is None

    def test_unknown(self):
        assert compute_bioavailability_modifier("unknown_method") is None


class TestRotimaticIngredients:
    def test_white_flour(self):
        ingredients = rotimatic_ingredients("white", 3)
        assert len(ingredients) == 1
        assert ingredients[0].quantity_grams == 90.0
        assert ingredients[0].glycemic_index == 71.0

    def test_multigrain(self):
        ingredients = rotimatic_ingredients("multigrain", 2)
        assert ingredients[0].quantity_grams == 60.0
        assert ingredients[0].glycemic_index == 45.0

    def test_none_flour(self):
        assert rotimatic_ingredients(None, 3) == []

    def test_none_count(self):
        assert rotimatic_ingredients("white", None) == []
