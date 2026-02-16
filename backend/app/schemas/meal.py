"""Meal event schemas — mirrors Swift MealEvent."""

from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, Field


class MealSource(str, Enum):
    rotimatic_next = "rotimatic_next"
    instant_pot = "instant_pot"
    instacart = "instacart"
    doordash = "doordash"
    manual = "manual"


class MealEventType(str, Enum):
    meal_preparation = "meal_preparation"
    meal_delivery = "meal_delivery"
    grocery_purchase = "grocery_purchase"
    manual_log = "manual_log"


class Ingredient(BaseModel):
    name: str
    quantity_grams: float | None = None
    quantity_ml: float | None = None
    glycemic_index: float | None = None
    type: str | None = None


class MealEventCreate(BaseModel):
    """Schema for creating a meal event (manual log or from normalization)."""

    timestamp_ms: int
    source: MealSource = MealSource.manual
    event_type: MealEventType = MealEventType.manual_log
    ingredients: list[Ingredient] = Field(default_factory=list)
    cooking_method: str | None = None
    estimated_glycemic_load: float | None = None
    bioavailability_modifier: float | None = None
    confidence: float = 0.5


class MealEventResponse(BaseModel):
    id: int
    timestamp_ms: int
    source: str
    event_type: str
    ingredients: list[Ingredient]
    cooking_method: str | None
    estimated_glycemic_load: float | None
    bioavailability_modifier: float | None
    confidence: float
    kitchen_state_id: int | None
    appliance_event_id: int | None
    synced_to_mobile: bool
    created_at: str | None
