"""Appliance telemetry schemas."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class RotimaticRawEvent(BaseModel):
    """Parsed Rotimatic Next REST event."""

    device_id: str
    session_id: str | None = None
    timestamp_ms: int
    flour_type: str | None = None  # white / whole_wheat / multigrain
    roti_count: int | None = None
    thickness: str | None = None  # thin / medium / thick
    roast_level: str | None = None  # light / medium / dark
    oil_applied: bool = False
    status: str = "unknown"  # idle / kneading / cooking / done / error
    raw: dict[str, Any] = Field(default_factory=dict)


class InstantPotRawEvent(BaseModel):
    """Parsed Instant Connect cloud API event."""

    device_id: str
    session_id: str | None = None
    timestamp_ms: int
    mode: str | None = None  # pressure_cook / slow_cook / saute / steam / yogurt / ...
    pressure_level: str | None = None  # high / low
    temperature_f: float | None = None
    duration_minutes: float | None = None
    status: str = "unknown"  # idle / preheating / cooking / keep_warm / done
    raw: dict[str, Any] = Field(default_factory=dict)


class ApplianceEventResponse(BaseModel):
    id: int
    device_type: str
    device_id: str
    timestamp_ms: int
    raw_payload: str
    session_id: str | None
    created_at: str | None
