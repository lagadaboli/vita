"""Background worker for periodic grocery receipt fetching (6h interval)."""

from __future__ import annotations

import asyncio
import json
import logging
import time

from app.config import settings
from app.database import async_session
from app.models.meal_event import MealEvent
from app.services.grocery import GroceryService

logger = logging.getLogger(__name__)


class GroceryWorker:
    """Periodically fetches grocery receipts from configured sources."""

    def __init__(self) -> None:
        self._task: asyncio.Task | None = None  # type: ignore[type-arg]
        self._running = False

    async def start(self) -> None:
        self._running = True
        self._task = asyncio.create_task(self._run_loop())
        logger.info("Grocery worker started (interval: %ss)", settings.grocery_fetch_interval)

    async def stop(self) -> None:
        self._running = False
        if self._task:
            self._task.cancel()
            self._task = None

    async def _run_loop(self) -> None:
        while self._running:
            try:
                await self._fetch_all()
            except asyncio.CancelledError:
                break
            except Exception:
                logger.exception("Grocery fetch cycle failed")
            await asyncio.sleep(settings.grocery_fetch_interval)

    async def _fetch_all(self) -> None:
        """Fetch receipts from all configured sources."""
        async with async_session() as session:
            service = GroceryService(session)

            instacart_orders: list[dict] = []
            if settings.instacart_mcp_stdio_command:
                instacart_orders = await service.fetch_instacart_receipts_mcp()
            elif settings.instacart_session_cookie:
                instacart_orders = await service.fetch_instacart_receipts(
                    settings.instacart_session_cookie
                )

            for order in instacart_orders:
                await service.store_receipt(
                    source="instacart",
                    order_id=str(order.get("id", "")),
                    order_timestamp_ms=order.get("created_at_ms"),
                    total_price_cents=order.get("total_cents"),
                    items=order.get("items", []),
                    raw_html=None,
                )
            if instacart_orders:
                logger.info("Fetched %d Instacart orders", len(instacart_orders))

            doordash_orders: list[dict] = []
            if settings.doordash_mcp_stdio_command:
                doordash_orders = await service.fetch_doordash_receipts_mcp()

            new_doordash = 0
            for order in doordash_orders:
                receipt = await service.store_receipt(
                    source="doordash",
                    order_id=str(order.get("id", "")),
                    order_timestamp_ms=order.get("created_at_ms"),
                    total_price_cents=order.get("total_cents"),
                    items=order.get("items", []),
                    raw_html=None,
                )
                if receipt is not None:
                    # New receipt — create a MealEvent so /sync/pull serves it to iOS.
                    ingredients = [
                        {
                            "name": item.get("name", "unknown"),
                            "glycemic_index": item.get("glycemic_index"),
                            "type": item.get("category"),
                        }
                        for item in order.get("items", [])
                    ]
                    meal = MealEvent(
                        timestamp_ms=order.get("created_at_ms") or int(time.time() * 1000),
                        source="doordash",
                        event_type="meal_delivery",
                        ingredients=json.dumps(ingredients),
                        confidence=0.5,
                        synced_to_mobile=0,
                    )
                    session.add(meal)
                    new_doordash += 1

            if new_doordash:
                await session.commit()
                logger.info("Fetched %d DoorDash orders (%d new)", len(doordash_orders), new_doordash)
            elif doordash_orders:
                logger.info("Fetched %d DoorDash orders (all already stored)", len(doordash_orders))

    async def fetch_now(self) -> None:
        """Trigger an immediate fetch cycle (for the API endpoint)."""
        await self._fetch_all()
