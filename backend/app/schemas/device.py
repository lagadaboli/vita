"""Device registration and status schemas."""

from __future__ import annotations

from enum import Enum

from pydantic import BaseModel


class DeviceStatus(str, Enum):
    discovered = "discovered"
    connected = "connected"
    polling = "polling"
    offline = "offline"


class DeviceRegistration(BaseModel):
    id: int
    device_type: str
    device_id: str
    ip_address: str | None
    last_seen_ms: int | None
    status: DeviceStatus
    consecutive_failures: int
