"""Grocery receipt and cross-reference schemas."""

from __future__ import annotations

from pydantic import BaseModel


class GroceryItemResponse(BaseModel):
    id: int
    receipt_id: int
    item_name: str
    quantity: float | None
    unit: str | None
    price_cents: int | None
    glycemic_index: float | None
    category: str | None
    resolved: bool


class GroceryReceiptResponse(BaseModel):
    id: int
    source: str
    order_id: str
    order_timestamp_ms: int | None
    total_price_cents: int | None
    fetched_at: str | None
    items: list[GroceryItemResponse] = []


class CrossReferenceResult(BaseModel):
    """Links grocery items to appliance cooking events."""

    grocery_item: GroceryItemResponse
    matched_meal_event_id: int | None = None
    match_confidence: float = 0.0
    reasoning: str | None = None
