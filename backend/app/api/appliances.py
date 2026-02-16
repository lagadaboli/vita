"""Appliance device management endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models.appliance_event import ApplianceEvent
from app.models.device_connection import DeviceConnection
from app.schemas.appliance import ApplianceEventResponse
from app.schemas.device import DeviceRegistration, DeviceStatus

router = APIRouter(prefix="/api/v1/appliances", tags=["appliances"])


@router.get("/", response_model=list[DeviceRegistration])
async def list_devices(session: AsyncSession = Depends(get_session)):
    """List all registered appliance devices."""
    result = await session.execute(select(DeviceConnection))
    devices = result.scalars().all()
    return [
        DeviceRegistration(
            id=d.id,
            device_type=d.device_type,
            device_id=d.device_id,
            ip_address=d.ip_address,
            last_seen_ms=d.last_seen_ms,
            status=DeviceStatus(d.status),
            consecutive_failures=d.consecutive_failures or 0,
        )
        for d in devices
    ]


@router.post("/discover")
async def discover_devices(session: AsyncSession = Depends(get_session)):
    """Trigger mDNS/cloud discovery for all known device adapters.

    Currently a placeholder — actual discovery requires running adapters.
    """
    return {"message": "Discovery triggered", "devices_found": 0}


@router.get("/{device_type}/events", response_model=list[ApplianceEventResponse])
async def get_device_events(
    device_type: str,
    since_ms: int | None = Query(None),
    limit: int = Query(50, ge=1, le=500),
    session: AsyncSession = Depends(get_session),
):
    """Get raw telemetry events for a specific device type."""
    query = (
        select(ApplianceEvent)
        .where(ApplianceEvent.device_type == device_type)
        .order_by(ApplianceEvent.timestamp_ms.desc())
        .limit(limit)
    )
    if since_ms is not None:
        query = query.where(ApplianceEvent.timestamp_ms >= since_ms)
    result = await session.execute(query)
    events = result.scalars().all()
    return [
        ApplianceEventResponse(
            id=e.id,
            device_type=e.device_type,
            device_id=e.device_id,
            timestamp_ms=e.timestamp_ms,
            raw_payload=e.raw_payload,
            session_id=e.session_id,
            created_at=e.created_at,
        )
        for e in events
    ]


@router.post("/{device_type}/poll")
async def manual_poll(device_type: str):
    """Trigger a manual poll for a device type. Placeholder for now."""
    return {"message": f"Manual poll triggered for {device_type}"}
