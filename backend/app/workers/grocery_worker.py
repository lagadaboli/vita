"""Background worker for periodic grocery receipt fetching (6h interval)."""

from __future__ import annotations

import asyncio
import logging
import time

from app.config import settings
from app.database import async_session
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

            if settings.instacart_session_cookie:
                orders = await service.fetch_instacart_receipts(
                    settings.instacart_session_cookie
                )
                for order in orders:
                    await service.store_receipt(
                        source="instacart",
                        order_id=order.get("id", ""),
                        order_timestamp_ms=order.get("created_at_ms"),
                        total_price_cents=order.get("total_cents"),
                        items=order.get("items", []),
                        raw_html=None,
                    )
                logger.info("Fetched %d Instacart orders", len(orders))

    async def fetch_now(self) -> None:
        """Trigger an immediate fetch cycle (for the API endpoint)."""
        await self._fetch_all()
