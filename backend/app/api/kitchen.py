"""Kitchen state FSM endpoints."""

from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.schemas.kitchen import (
    KitchenStateHistoryEntry,
    KitchenStateResponse,
    KitchenTransitionRequest,
)
from app.services.kitchen_fsm import KitchenFSM

router = APIRouter(prefix="/api/v1/kitchen", tags=["kitchen"])


@router.get("/state", response_model=KitchenStateResponse)
async def get_kitchen_state(session: AsyncSession = Depends(get_session)):
    """Get the current kitchen FSM state."""
    fsm = KitchenFSM(session)
    await fsm.ensure_initial_state()

    record = await fsm.get_current_state()
    if record is None:
        return KitchenStateResponse(state="idle", entered_at_ms=0)

    meta = None
    if record.extra_metadata:
        try:
            meta = json.loads(record.extra_metadata)
        except json.JSONDecodeError:
            pass

    return KitchenStateResponse(
        state=record.state,
        entered_at_ms=record.entered_at_ms,
        device_type=record.device_type,
        metadata=meta,
    )


@router.get("/history", response_model=list[KitchenStateHistoryEntry])
async def get_kitchen_history(
    from_ms: int | None = Query(None),
    to_ms: int | None = Query(None),
    session: AsyncSession = Depends(get_session),
):
    """Get kitchen state transition history."""
    fsm = KitchenFSM(session)
    records = await fsm.get_history(from_ms=from_ms, to_ms=to_ms)
    return [
        KitchenStateHistoryEntry(
            id=r.id,
            state=r.state,
            entered_at_ms=r.entered_at_ms,
            exited_at_ms=r.exited_at_ms,
            trigger_event_id=r.trigger_event_id,
            device_type=r.device_type,
        )
        for r in records
    ]


@router.post("/transition", response_model=KitchenStateResponse)
async def force_transition(
    req: KitchenTransitionRequest,
    session: AsyncSession = Depends(get_session),
):
    """Force a kitchen state transition."""
    fsm = KitchenFSM(session)
    await fsm.ensure_initial_state()

    try:
        record = await fsm.transition(
            trigger=req.trigger,
            device_type=req.device_type,
            event_id=req.event_id,
            metadata=req.metadata,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    meta = None
    if record.extra_metadata:
        try:
            meta = json.loads(record.extra_metadata)
        except json.JSONDecodeError:
            pass

    return KitchenStateResponse(
        state=record.state,
        entered_at_ms=record.entered_at_ms,
        device_type=record.device_type,
        metadata=meta,
    )
