"""Mobile sync schemas for push/pull protocol."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from app.schemas.meal import MealEventResponse


class SyncHealthEvent(BaseModel):
    """A health event pushed from mobile (glucose, HRV, etc.)."""

    type: str  # glucose / hrv / heartRate
    timestamp_ms: int
    value: float
    unit: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class SyncPullResponse(BaseModel):
    """Response for GET /sync/pull — new meal events for mobile."""

    events: list[MealEventResponse]
    watermark_ms: int = Field(
        ..., description="Timestamp watermark; pass as since_ms on next pull"
    )
    has_more: bool = False


class SyncPushRequest(BaseModel):
    """Request for POST /sync/push — mobile pushes glucose/HRV data."""

    events: list[SyncHealthEvent]


class SyncStatusResponse(BaseModel):
    last_pull_ms: int | None = None
    last_push_ms: int | None = None
    pending_events: int = 0
