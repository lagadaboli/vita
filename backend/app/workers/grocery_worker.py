"""Background worker for periodic grocery receipt fetching (6h interval)."""

from __future__ import annotations

import asyncio
import json
import logging
import time
from typing import Any

from app.config import settings
from app.database import async_session
from app.models.meal_event import MealEvent
from app.services.grocery import GroceryService

logger = logging.getLogger(__name__)


def _order_identifier(order: dict[str, Any]) -> str:
    raw = order.get("id") or order.get("order_id") or order.get("receipt_id") or ""
    return str(raw)


def _order_timestamp_ms(order: dict[str, Any]) -> int | None:
    raw = (
        order.get("created_at_ms")
        or order.get("timestamp_ms")
        or order.get("order_timestamp_ms")
    )
    return int(raw) if isinstance(raw, (int, float)) else None


def _order_total_cents(order: dict[str, Any]) -> int | None:
    raw = order.get("total_cents") or order.get("total_price_cents")
    return int(raw) if isinstance(raw, (int, float)) else None


def _item_to_ingredient(item: dict[str, Any]) -> dict[str, Any]:
    ingredient: dict[str, Any] = {
        "name": item.get("name", "unknown"),
        "glycemic_index": item.get("glycemic_index"),
        "type": item.get("category"),
    }

    quantity = item.get("quantity")
    unit_raw = item.get("unit")
    unit = unit_raw.lower() if isinstance(unit_raw, str) else ""
    if isinstance(quantity, (int, float)):
        if unit in {"g", "gram", "grams"}:
            ingredient["quantity_grams"] = float(quantity)
        elif unit in {"kg", "kilogram", "kilograms"}:
            ingredient["quantity_grams"] = float(quantity) * 1000.0
        elif unit in {"oz", "ounce", "ounces"}:
            ingredient["quantity_grams"] = float(quantity) * 28.3495
        elif unit in {"lb", "lbs", "pound", "pounds"}:
            ingredient["quantity_grams"] = float(quantity) * 453.592

    return ingredient


def _meal_event_from_order(
    order: dict[str, Any],
    source: str,
    event_type: str,
) -> MealEvent:
    raw_items = order.get("items")
    items = raw_items if isinstance(raw_items, list) else []
    ingredients = [
        _item_to_ingredient(item) for item in items if isinstance(item, dict)
    ]
    return MealEvent(
        timestamp_ms=_order_timestamp_ms(order) or int(time.time() * 1000),
        source=source,
        event_type=event_type,
        ingredients=json.dumps(ingredients),
        confidence=0.5,
        synced_to_mobile=0,
    )


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
            if settings.instacart_session_cookie:
                instacart_orders = await service.fetch_instacart_receipts(
                    settings.instacart_session_cookie
                )
            elif settings.instacart_mcp_stdio_command:
                instacart_orders = await service.fetch_instacart_receipts_mcp()

            new_instacart = 0
            for order in instacart_orders:
                receipt = await service.store_receipt(
                    source="instacart",
                    order_id=_order_identifier(order),
                    order_timestamp_ms=_order_timestamp_ms(order),
                    total_price_cents=_order_total_cents(order),
                    items=order.get("items", []),
                    raw_html=None,
                )
                if receipt is not None:
                    # New receipt — create a MealEvent so /sync/pull serves it to iOS.
                    session.add(
                        _meal_event_from_order(
                            order=order,
                            source="instacart",
                            event_type="grocery_purchase",
                        )
                    )
                    new_instacart += 1

            if new_instacart:
                await session.commit()
                logger.info(
                    "Fetched %d Instacart orders (%d new)",
                    len(instacart_orders),
                    new_instacart,
                )
            elif instacart_orders:
                logger.info(
                    "Fetched %d Instacart orders (all already stored)",
                    len(instacart_orders),
                )

            doordash_orders: list[dict] = []
            if settings.doordash_session_cookie:
                doordash_orders = await service.fetch_doordash_receipts(
                    settings.doordash_session_cookie
                )
            elif settings.doordash_mcp_stdio_command:
                doordash_orders = await service.fetch_doordash_receipts_mcp()

            new_doordash = 0
            for order in doordash_orders:
                receipt = await service.store_receipt(
                    source="doordash",
                    order_id=_order_identifier(order),
                    order_timestamp_ms=_order_timestamp_ms(order),
                    total_price_cents=_order_total_cents(order),
                    items=order.get("items", []),
                    raw_html=None,
                )
                if receipt is not None:
                    # New receipt — create a MealEvent so /sync/pull serves it to iOS.
                    session.add(
                        _meal_event_from_order(
                            order=order,
                            source="doordash",
                            event_type="meal_delivery",
                        )
                    )
                    new_doordash += 1

            if new_doordash:
                await session.commit()
                logger.info("Fetched %d DoorDash orders (%d new)", len(doordash_orders), new_doordash)
            elif doordash_orders:
                logger.info("Fetched %d DoorDash orders (all already stored)", len(doordash_orders))

    async def fetch_now(self) -> None:
        """Trigger an immediate fetch cycle (for the API endpoint)."""
        await self._fetch_all()
