"""Glycemic load and bioavailability computation.

Mirrors the Swift MealEvent.computedGlycemicLoad formula:
  GL = Σ (GI × grams × 0.7) / 100
"""

from __future__ import annotations

from app.schemas.meal import Ingredient

# Known flour glycemic indices (Rotimatic)
FLOUR_GI: dict[str, float] = {
    "white": 71.0,
    "whole_wheat": 54.0,
    "multigrain": 45.0,
}

ROTI_WEIGHT_GRAMS = 30.0  # approximate weight per roti

# Pressure cooking bioavailability modifiers
PRESSURE_COOK_MODIFIERS: dict[str, float] = {
    "protein": 1.35,
    "lectin": -0.40,
}


def compute_glycemic_load(ingredients: list[Ingredient]) -> float:
    """Compute glycemic load from a list of ingredients.

    Formula: GL = Σ (GI × grams × 0.7) / 100
    Assumes 70% of grain weight is available carbohydrate.
    """
    total = 0.0
    for ing in ingredients:
        gi = ing.glycemic_index
        grams = ing.quantity_grams
        if gi is not None and grams is not None:
            carb_grams = grams * 0.7
            total += (gi * carb_grams) / 100.0
    return round(total, 2)


def compute_bioavailability_modifier(cooking_method: str | None) -> float | None:
    """Compute bioavailability modifier based on cooking method.

    Returns a multiplier representing net nutritional impact.
    """
    modifiers: dict[str, float] = {
        "high_lectin_neutralization": 1.35,
        "moderate_lectin_neutralization": 1.15,
        "baseline_lectin_retention": 0.90,
        "fat_soluble_vitamin_enhancement": 1.20,
        "water_soluble_vitamin_reduction": 0.85,
        "probiotic_generation": 1.10,
    }
    if cooking_method is None:
        return None
    return modifiers.get(cooking_method)


def rotimatic_ingredients(
    flour_type: str | None, roti_count: int | None
) -> list[Ingredient]:
    """Create ingredient list from Rotimatic parameters."""
    if flour_type is None or roti_count is None:
        return []
    gi = FLOUR_GI.get(flour_type)
    total_grams = ROTI_WEIGHT_GRAMS * roti_count
    return [
        Ingredient(
            name=f"{flour_type} flour roti",
            quantity_grams=total_grams,
            glycemic_index=gi,
            type="grain",
        )
    ]
