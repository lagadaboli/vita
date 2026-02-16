"""Mobile sync endpoints — push/pull protocol for meal events and health data."""

from __future__ import annotations

import json

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models.meal_event import MealEvent
from app.schemas.meal import Ingredient, MealEventResponse
from app.schemas.sync import SyncPullResponse, SyncPushRequest, SyncStatusResponse

router = APIRouter(prefix="/api/v1/sync", tags=["sync"])


def _meal_to_response(m: MealEvent) -> MealEventResponse:
    try:
        ingredients = [Ingredient(**i) for i in json.loads(m.ingredients)]
    except (json.JSONDecodeError, TypeError):
        ingredients = []

    return MealEventResponse(
        id=m.id,
        timestamp_ms=m.timestamp_ms,
        source=m.source,
        event_type=m.event_type,
        ingredients=ingredients,
        cooking_method=m.cooking_method,
        estimated_glycemic_load=m.estimated_glycemic_load,
        bioavailability_modifier=m.bioavailability_modifier,
        confidence=m.confidence or 0.5,
        kitchen_state_id=m.kitchen_state_id,
        appliance_event_id=m.appliance_event_id,
        synced_to_mobile=bool(m.synced_to_mobile),
        created_at=m.created_at,
    )


@router.get("/pull", response_model=SyncPullResponse)
async def sync_pull(
    since_ms: int = Query(0),
    limit: int = Query(100, ge=1, le=1000),
    session: AsyncSession = Depends(get_session),
):
    """Pull new meal events for mobile since a watermark timestamp."""
    query = (
        select(MealEvent)
        .where(MealEvent.timestamp_ms > since_ms)
        .where(MealEvent.synced_to_mobile == 0)
        .order_by(MealEvent.timestamp_ms.asc())
        .limit(limit + 1)  # +1 to detect has_more
    )
    result = await session.execute(query)
    meals = list(result.scalars().all())

    has_more = len(meals) > limit
    if has_more:
        meals = meals[:limit]

    # Mark as synced
    if meals:
        meal_ids = [m.id for m in meals]
        await session.execute(
            update(MealEvent)
            .where(MealEvent.id.in_(meal_ids))
            .values(synced_to_mobile=1)
        )
        await session.commit()

    events = [_meal_to_response(m) for m in meals]
    watermark = meals[-1].timestamp_ms if meals else since_ms

    return SyncPullResponse(
        events=events,
        watermark_ms=watermark,
        has_more=has_more,
    )


@router.post("/push")
async def sync_push(req: SyncPushRequest):
    """Receive glucose/HRV data pushed from mobile.

    Stores health events for causal alignment with meal data.
    Currently logs receipt; full storage deferred to CausalityEngine integration.
    """
    return {
        "received": len(req.events),
        "message": "Health events received for causal alignment",
    }


@router.get("/status", response_model=SyncStatusResponse)
async def sync_status(session: AsyncSession = Depends(get_session)):
    """Get sync watermarks and pending event count."""
    # Count unsynced meals
    result = await session.execute(
        select(func.count(MealEvent.id)).where(MealEvent.synced_to_mobile == 0)
    )
    pending = result.scalar() or 0

    # Get latest synced timestamp
    result = await session.execute(
        select(func.max(MealEvent.timestamp_ms)).where(MealEvent.synced_to_mobile == 1)
    )
    last_pull = result.scalar()

    return SyncStatusResponse(
        last_pull_ms=last_pull,
        pending_events=pending,
    )
