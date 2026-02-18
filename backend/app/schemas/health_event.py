"""Health event response schemas."""

from __future__ import annotations

from pydantic import BaseModel


class HealthEventResponse(BaseModel):
    """Response representation of a persisted health event."""

    id: int
    event_type: str
    timestamp_ms: int
    value: float
    unit: str | None = None
    processed: bool = False
    created_at: str | None = None
