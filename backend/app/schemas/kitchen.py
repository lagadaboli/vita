"""Kitchen State FSM schemas."""

from __future__ import annotations

from enum import Enum

from pydantic import BaseModel


class KitchenStateEnum(str, Enum):
    idle = "idle"
    cooking = "cooking"
    meal_ready = "meal_ready"
    meal_consumed = "meal_consumed"


# Valid transitions: (from_state, trigger) → to_state
VALID_TRANSITIONS: dict[tuple[KitchenStateEnum, str], KitchenStateEnum] = {
    (KitchenStateEnum.idle, "appliance_start"): KitchenStateEnum.cooking,
    (KitchenStateEnum.cooking, "appliance_stop"): KitchenStateEnum.meal_ready,
    (KitchenStateEnum.cooking, "timeout"): KitchenStateEnum.idle,
    (KitchenStateEnum.meal_ready, "manual_confirm"): KitchenStateEnum.meal_consumed,
    (KitchenStateEnum.meal_ready, "glucose_spike_detected"): KitchenStateEnum.meal_consumed,
    (KitchenStateEnum.meal_ready, "timeout"): KitchenStateEnum.idle,
    (KitchenStateEnum.meal_consumed, "auto_reset"): KitchenStateEnum.idle,
    (KitchenStateEnum.meal_consumed, "timeout"): KitchenStateEnum.idle,
}


class KitchenStateResponse(BaseModel):
    state: KitchenStateEnum
    entered_at_ms: int
    device_type: str | None = None
    metadata: dict | None = None


class KitchenTransitionRequest(BaseModel):
    trigger: str
    device_type: str | None = None
    event_id: int | None = None
    metadata: dict | None = None


class KitchenStateHistoryEntry(BaseModel):
    id: int
    state: str
    entered_at_ms: int
    exited_at_ms: int | None
    trigger_event_id: int | None
    device_type: str | None
