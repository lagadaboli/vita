"""Meal event endpoints."""

from __future__ import annotations

import json
import time

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models.meal_event import MealEvent
from app.schemas.meal import Ingredient, MealEventCreate, MealEventResponse
from app.services.glycemic import compute_glycemic_load

router = APIRouter(prefix="/api/v1/meals", tags=["meals"])


def _meal_to_response(m: MealEvent) -> MealEventResponse:
    """Convert a MealEvent DB model to a response schema."""
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


@router.get("/", response_model=list[MealEventResponse])
async def list_meals(
    from_ms: int | None = Query(None),
    to_ms: int | None = Query(None),
    source: str | None = Query(None),
    limit: int = Query(50, ge=1, le=500),
    session: AsyncSession = Depends(get_session),
):
    """Query meal events with optional filters."""
    query = select(MealEvent).order_by(MealEvent.timestamp_ms.desc()).limit(limit)
    if from_ms is not None:
        query = query.where(MealEvent.timestamp_ms >= from_ms)
    if to_ms is not None:
        query = query.where(MealEvent.timestamp_ms <= to_ms)
    if source is not None:
        query = query.where(MealEvent.source == source)
    result = await session.execute(query)
    return [_meal_to_response(m) for m in result.scalars().all()]


@router.post("/", response_model=MealEventResponse, status_code=201)
async def create_meal(
    meal: MealEventCreate,
    session: AsyncSession = Depends(get_session),
):
    """Create a manual meal log entry."""
    # Auto-compute glycemic load if not provided
    gl = meal.estimated_glycemic_load
    if gl is None and meal.ingredients:
        computed = compute_glycemic_load(meal.ingredients)
        if computed > 0:
            gl = computed

    db_meal = MealEvent(
        timestamp_ms=meal.timestamp_ms,
        source=meal.source.value,
        event_type=meal.event_type.value,
        ingredients=json.dumps([i.model_dump() for i in meal.ingredients]),
        cooking_method=meal.cooking_method,
        estimated_glycemic_load=gl,
        bioavailability_modifier=meal.bioavailability_modifier,
        confidence=meal.confidence,
    )
    session.add(db_meal)
    await session.commit()
    await session.refresh(db_meal)
    return _meal_to_response(db_meal)


@router.get("/recent", response_model=list[MealEventResponse])
async def recent_meals(session: AsyncSession = Depends(get_session)):
    """Get meal events from the last 24 hours."""
    since = int(time.time() * 1000) - (24 * 60 * 60 * 1000)
    query = (
        select(MealEvent)
        .where(MealEvent.timestamp_ms >= since)
        .order_by(MealEvent.timestamp_ms.desc())
    )
    result = await session.execute(query)
    return [_meal_to_response(m) for m in result.scalars().all()]


@router.get("/{meal_id}", response_model=MealEventResponse)
async def get_meal(meal_id: int, session: AsyncSession = Depends(get_session)):
    """Get a specific meal event by ID."""
    result = await session.execute(
        select(MealEvent).where(MealEvent.id == meal_id)
    )
    meal = result.scalar_one_or_none()
    if meal is None:
        raise HTTPException(status_code=404, detail="Meal not found")
    return _meal_to_response(meal)
