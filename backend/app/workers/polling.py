"""Asyncio polling orchestrator for appliance devices.

Started during FastAPI lifespan. Manages one polling task per registered device
with adaptive intervals and exponential backoff on failure.
"""

from __future__ import annotations

import asyncio
import json
import logging
import random
import time

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import async_session
from app.models.appliance_event import ApplianceEvent
from app.models.device_connection import DeviceConnection
from app.services.device_protocol import ApplianceProtocol
from app.services.kitchen_fsm import KitchenFSM
from app.services.normalizer import normalize_raw_event

logger = logging.getLogger(__name__)


class PollingManager:
    """Manages polling tasks for all registered devices."""

    def __init__(self, adapters: dict[str, ApplianceProtocol]) -> None:
        self._adapters = adapters
        self._tasks: dict[str, asyncio.Task] = {}  # type: ignore[type-arg]
        self._running = False

    async def start(self) -> None:
        """Start polling for all known devices."""
        self._running = True
        async with async_session() as session:
            result = await session.execute(
                select(DeviceConnection).where(
                    DeviceConnection.status.in_(["connected", "polling", "discovered"])
                )
            )
            devices = result.scalars().all()

            for device in devices:
                adapter = self._adapters.get(device.device_type)
                if adapter:
                    task_key = f"{device.device_type}:{device.device_id}"
                    self._tasks[task_key] = asyncio.create_task(
                        self._poll_loop(adapter, device.device_id, device.ip_address)
                    )
                    logger.info("Started polling %s", task_key)

    async def stop(self) -> None:
        """Stop all polling tasks."""
        self._running = False
        for key, task in self._tasks.items():
            task.cancel()
            logger.info("Cancelled polling %s", key)
        self._tasks.clear()

    async def _poll_loop(
        self, adapter: ApplianceProtocol, device_id: str, ip_address: str | None
    ) -> None:
        """Poll a single device in a loop with adaptive intervals and retry."""
        consecutive_failures = 0
        device_type = adapter.device_type

        while self._running:
            try:
                events = await adapter.poll(device_id, ip_address)
                consecutive_failures = 0

                async with async_session() as session:
                    # Update device status
                    await session.execute(
                        update(DeviceConnection)
                        .where(DeviceConnection.device_type == device_type)
                        .where(DeviceConnection.device_id == device_id)
                        .values(
                            status="polling",
                            last_seen_ms=int(time.time() * 1000),
                            consecutive_failures=0,
                        )
                    )

                    for event_data in events:
                        # Deduplicate by session_id
                        session_id = event_data.get("session_id")
                        if session_id:
                            existing = await session.execute(
                                select(ApplianceEvent)
                                .where(ApplianceEvent.session_id == session_id)
                                .where(ApplianceEvent.device_type == device_type)
                                .where(ApplianceEvent.device_id == device_id)
                                .where(
                                    ApplianceEvent.timestamp_ms
                                    == event_data["timestamp_ms"]
                                )
                            )
                            if existing.scalar_one_or_none() is not None:
                                continue

                        # Store raw event
                        ae = ApplianceEvent(
                            device_type=event_data["device_type"],
                            device_id=event_data["device_id"],
                            timestamp_ms=event_data["timestamp_ms"],
                            raw_payload=event_data["raw_payload"],
                            session_id=session_id,
                        )
                        session.add(ae)
                        await session.flush()

                        # Normalize and store meal event
                        meal_create = normalize_raw_event(
                            device_type, event_data["raw_payload"]
                        )
                        if meal_create:
                            from app.models.meal_event import MealEvent

                            me = MealEvent(
                                timestamp_ms=meal_create.timestamp_ms,
                                source=meal_create.source.value,
                                event_type=meal_create.event_type.value,
                                ingredients=json.dumps(
                                    [i.model_dump() for i in meal_create.ingredients]
                                ),
                                cooking_method=meal_create.cooking_method,
                                estimated_glycemic_load=meal_create.estimated_glycemic_load,
                                bioavailability_modifier=meal_create.bioavailability_modifier,
                                confidence=meal_create.confidence,
                                appliance_event_id=ae.id,
                            )
                            session.add(me)

                        # Update kitchen FSM
                        raw = json.loads(event_data["raw_payload"])
                        status = raw.get("status", "")
                        fsm = KitchenFSM(session)
                        try:
                            if status in ("cooking", "kneading", "preheating"):
                                await fsm.transition(
                                    "appliance_start",
                                    device_type=device_type,
                                    event_id=ae.id,
                                )
                            elif status in ("done", "keep_warm"):
                                await fsm.transition(
                                    "appliance_stop",
                                    device_type=device_type,
                                    event_id=ae.id,
                                )
                        except ValueError:
                            pass  # Transition not valid from current state

                    await session.commit()

                # Adaptive interval: shorter when device is active
                raw_payload = events[0]["raw_payload"] if events else "{}"
                raw_data = json.loads(raw_payload)
                device_status = raw_data.get("status", "idle")
                if device_status in ("idle", "done", "unknown"):
                    interval = settings.idle_poll_interval
                elif device_type == "rotimatic_next":
                    interval = settings.rotimatic_poll_interval
                else:
                    interval = settings.instant_pot_poll_interval

            except asyncio.CancelledError:
                break
            except Exception:
                consecutive_failures += 1
                logger.exception(
                    "Poll failed for %s:%s (failure #%d)",
                    device_type,
                    device_id,
                    consecutive_failures,
                )

                # Exponential backoff with jitter
                delay = min(
                    settings.base_retry_delay * (2**consecutive_failures),
                    settings.max_retry_backoff,
                )
                jitter = random.uniform(0, delay * 0.1)
                interval = delay + jitter

                # Update failure count in DB
                async with async_session() as session:
                    await session.execute(
                        update(DeviceConnection)
                        .where(DeviceConnection.device_type == device_type)
                        .where(DeviceConnection.device_id == device_id)
                        .values(
                            consecutive_failures=consecutive_failures,
                            status="offline"
                            if consecutive_failures >= 10
                            else "connected",
                        )
                    )
                    await session.commit()

            await asyncio.sleep(interval)
