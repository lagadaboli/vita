"""Normalization pipeline: Raw appliance event → classified MealEvent.

Pipeline stages:
  1. Parse: Device JSON → RotimaticRawEvent or InstantPotRawEvent
  2. Classify: Cooking semantics based on mode + duration
  3. Enrich: Compute GL and bioavailability modifier
  4. Normalize: Produce MealEventCreate
"""

from __future__ import annotations

import json
import logging

from app.schemas.appliance import InstantPotRawEvent, RotimaticRawEvent
from app.schemas.meal import Ingredient, MealEventCreate, MealEventType, MealSource
from app.services.glycemic import (
    compute_bioavailability_modifier,
    compute_glycemic_load,
    rotimatic_ingredients,
)

logger = logging.getLogger(__name__)


def classify_instant_pot_method(mode: str | None, duration_minutes: float | None) -> str | None:
    """Classify cooking method based on Instant Pot mode and duration.

    - Pressure Cook >20min → high_lectin_neutralization
    - Pressure Cook 10-20min → moderate_lectin_neutralization
    - Slow Cook → baseline_lectin_retention
    - Sauté → fat_soluble_vitamin_enhancement
    - Steam → water_soluble_vitamin_reduction
    - Yogurt → probiotic_generation
    """
    if mode is None:
        return None

    mode_lower = mode.lower().replace(" ", "_")

    if mode_lower == "pressure_cook":
        if duration_minutes is not None and duration_minutes > 20:
            return "high_lectin_neutralization"
        elif duration_minutes is not None and duration_minutes >= 10:
            return "moderate_lectin_neutralization"
        else:
            return "moderate_lectin_neutralization"
    elif mode_lower == "slow_cook":
        return "baseline_lectin_retention"
    elif mode_lower in ("saute", "sauté"):
        return "fat_soluble_vitamin_enhancement"
    elif mode_lower == "steam":
        return "water_soluble_vitamin_reduction"
    elif mode_lower == "yogurt":
        return "probiotic_generation"

    return None


def parse_rotimatic_event(raw_payload: str) -> RotimaticRawEvent | None:
    """Parse a raw appliance event payload into a RotimaticRawEvent."""
    try:
        data = json.loads(raw_payload)
        return RotimaticRawEvent(**data)
    except Exception:
        logger.exception("Failed to parse Rotimatic event")
        return None


def parse_instant_pot_event(raw_payload: str) -> InstantPotRawEvent | None:
    """Parse a raw appliance event payload into an InstantPotRawEvent."""
    try:
        data = json.loads(raw_payload)
        return InstantPotRawEvent(**data)
    except Exception:
        logger.exception("Failed to parse Instant Pot event")
        return None


def normalize_rotimatic_event(event: RotimaticRawEvent) -> MealEventCreate:
    """Normalize a Rotimatic event into a MealEvent."""
    ingredients = rotimatic_ingredients(event.flour_type, event.roti_count)
    gl = compute_glycemic_load(ingredients)

    return MealEventCreate(
        timestamp_ms=event.timestamp_ms,
        source=MealSource.rotimatic_next,
        event_type=MealEventType.meal_preparation,
        ingredients=ingredients,
        cooking_method=None,  # Rotimatic is a fixed process
        estimated_glycemic_load=gl if gl > 0 else None,
        bioavailability_modifier=None,
        confidence=0.9,  # High confidence — direct device data
    )


def normalize_instant_pot_event(event: InstantPotRawEvent) -> MealEventCreate:
    """Normalize an Instant Pot event into a MealEvent."""
    cooking_method = classify_instant_pot_method(event.mode, event.duration_minutes)
    bioavailability = compute_bioavailability_modifier(cooking_method)

    # Instant Pot ingredients are unknown without grocery cross-reference;
    # create a placeholder that can be enriched later.
    ingredients: list[Ingredient] = []

    return MealEventCreate(
        timestamp_ms=event.timestamp_ms,
        source=MealSource.instant_pot,
        event_type=MealEventType.meal_preparation,
        ingredients=ingredients,
        cooking_method=cooking_method,
        estimated_glycemic_load=None,
        bioavailability_modifier=bioavailability,
        confidence=0.7,  # Medium-high; we know cooking method but not ingredients
    )


def normalize_raw_event(device_type: str, raw_payload: str) -> MealEventCreate | None:
    """Main entry point: normalize any raw appliance event into a MealEvent.

    Returns None if parsing fails.
    """
    if device_type == "rotimatic_next":
        parsed = parse_rotimatic_event(raw_payload)
        if parsed is None:
            return None
        return normalize_rotimatic_event(parsed)
    elif device_type == "instant_pot":
        parsed_ip = parse_instant_pot_event(raw_payload)
        if parsed_ip is None:
            return None
        return normalize_instant_pot_event(parsed_ip)
    else:
        logger.warning("Unknown device type: %s", device_type)
        return None
