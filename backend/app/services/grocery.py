"""Grocery receipt fetcher and appliance cross-reference service."""

from __future__ import annotations

import logging
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.grocery_receipt import GroceryItem, GroceryReceipt
from app.models.meal_event import MealEvent
from app.schemas.grocery import CrossReferenceResult, GroceryItemResponse
from app.services.mcp_stdio import call_mcp_tool_stdio

logger = logging.getLogger(__name__)


class GroceryService:
    """Handles receipt fetching and grocery-to-meal cross-referencing."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    @staticmethod
    def _cookie_header(raw_cookie: str, default_cookie_name: str) -> str:
        raw = raw_cookie.strip()
        if not raw:
            return ""

        # Supports both full Cookie header values and bare token values.
        if ";" in raw or "=" in raw:
            return raw

        return f"{default_cookie_name}={raw}"

    @staticmethod
    def _extract_raw_orders(payload: Any) -> list[dict[str, Any]]:
        if payload is None:
            return []

        if isinstance(payload, list):
            return [o for o in payload if isinstance(o, dict)]

        if not isinstance(payload, dict):
            return []

        candidate_lists = [
            payload.get("orders"),
            payload.get("receipts"),
            payload.get("items"),
            payload.get("results"),
            payload.get("data", {}).get("orders")
            if isinstance(payload.get("data"), dict)
            else None,
            payload.get("data", {}).get("receipts")
            if isinstance(payload.get("data"), dict)
            else None,
            payload.get("order_history", {}).get("orders")
            if isinstance(payload.get("order_history"), dict)
            else None,
            payload.get("orderHistory", {}).get("orders")
            if isinstance(payload.get("orderHistory"), dict)
            else None,
        ]
        for candidate in candidate_lists:
            if isinstance(candidate, list):
                return [o for o in candidate if isinstance(o, dict)]

        return []

    @staticmethod
    def _normalize_orders(raw_orders: list[dict[str, Any]]) -> list[dict[str, Any]]:
        normalized: list[dict[str, Any]] = []
        for order in raw_orders:
            raw_items = (
                order.get("items")
                or order.get("line_items")
                or order.get("lineItems")
                or order.get("order_items")
                or order.get("orderItems")
                or []
            )
            items: list[dict[str, Any]] = []
            if isinstance(raw_items, list):
                for item in raw_items:
                    if not isinstance(item, dict):
                        continue
                    items.append(
                        {
                            "name": item.get("name")
                            or item.get("item_name")
                            or item.get("itemName")
                            or item.get("title")
                            or "unknown",
                            "quantity": item.get("quantity") or item.get("qty"),
                            "unit": item.get("unit"),
                            "price_cents": item.get("price_cents")
                            or item.get("priceCents")
                            or item.get("price")
                            or item.get("total_price_cents")
                            or item.get("totalPriceCents"),
                            "glycemic_index": item.get("glycemic_index")
                            or item.get("glycemicIndex"),
                            "category": item.get("category"),
                        }
                    )

            normalized.append(
                {
                    "id": order.get("id")
                    or order.get("order_id")
                    or order.get("orderId")
                    or order.get("receipt_id")
                    or order.get("receiptId")
                    or order.get("uuid"),
                    "created_at_ms": order.get("created_at_ms")
                    or order.get("createdAtMs")
                    or order.get("timestamp_ms")
                    or order.get("timestampMs")
                    or order.get("order_timestamp_ms")
                    or order.get("orderTimestampMs"),
                    "total_cents": order.get("total_cents")
                    or order.get("totalCents")
                    or order.get("total_price_cents")
                    or order.get("totalPriceCents")
                    or order.get("subtotal_cents")
                    or order.get("subtotalCents"),
                    "items": items,
                }
            )

        return [o for o in normalized if o.get("id")]

    async def fetch_receipts_via_mcp(
        self,
        command: str,
        tool_name: str,
        source: str,
        days: int = 7,
    ) -> list[dict[str, Any]]:
        """Fetch receipt/order payloads via MCP stdio and normalize shape."""
        if not command.strip():
            return []

        try:
            payload = await call_mcp_tool_stdio(
                command=command,
                tool_name=tool_name,
                arguments={"days": days},
                timeout_seconds=settings.mcp_stdio_timeout_seconds,
            )
        except Exception:
            logger.exception("%s MCP stdio fetch failed", source)
            return []

        if not payload:
            return []

        raw_orders = self._extract_raw_orders(payload)
        return self._normalize_orders(raw_orders)

    async def fetch_instacart_receipts_mcp(self, days: int = 7) -> list[dict[str, Any]]:
        return await self.fetch_receipts_via_mcp(
            command=settings.instacart_mcp_stdio_command,
            tool_name=settings.instacart_mcp_tool_name,
            source="instacart",
            days=days,
        )

    async def fetch_doordash_receipts_mcp(self, days: int = 7) -> list[dict[str, Any]]:
        return await self.fetch_receipts_via_mcp(
            command=settings.doordash_mcp_stdio_command,
            tool_name=settings.doordash_mcp_tool_name,
            source="doordash",
            days=days,
        )

    async def fetch_instacart_receipts(self, session_cookie: str) -> list[dict[str, Any]]:
        """Fetch recent Instacart orders using stored session cookie.

        Returns normalized order data.
        """
        if not session_cookie:
            logger.warning("No Instacart session cookie configured")
            return []

        cookie_header = self._cookie_header(session_cookie, default_cookie_name="session")

        try:
            async with httpx.AsyncClient(
                headers={
                    "Cookie": cookie_header,
                    "Accept": "application/json,text/plain,*/*",
                    "User-Agent": "VITA/0.2.0 (+local-dev)",
                },
                follow_redirects=True,
                timeout=30.0,
            ) as client:
                for url in (
                    "https://www.instacart.com/api/v3/orders",
                    "https://www.instacart.com/api/v3/orders?limit=100",
                ):
                    resp = await client.get(url)
                    if resp.status_code >= 400:
                        continue
                    payload = resp.json()
                    normalized = self._normalize_orders(self._extract_raw_orders(payload))
                    if normalized:
                        return normalized
        except Exception:
            logger.exception("Instacart receipt fetch failed")
        return []

    async def fetch_doordash_receipts(self, session_cookie: str) -> list[dict[str, Any]]:
        """Fetch recent DoorDash orders using stored session cookie.

        Returns normalized order data.
        """
        if not session_cookie:
            logger.warning("No DoorDash session cookie configured")
            return []

        cookie_header = self._cookie_header(
            session_cookie, default_cookie_name="dd_session_id"
        )

        try:
            async with httpx.AsyncClient(
                headers={
                    "Cookie": cookie_header,
                    "Accept": "application/json,text/plain,*/*",
                    "User-Agent": "VITA/0.2.0 (+local-dev)",
                },
                follow_redirects=True,
                timeout=30.0,
            ) as client:
                for url in (
                    "https://www.doordash.com/consumer/v1/orders?offset=0&limit=100",
                    "https://api-consumer-client.doordash.com/consumer/v1/orders?offset=0&limit=100",
                ):
                    resp = await client.get(url)
                    if resp.status_code >= 400:
                        continue

                    try:
                        payload = resp.json()
                    except ValueError:
                        continue

                    normalized = self._normalize_orders(self._extract_raw_orders(payload))
                    if normalized:
                        return normalized
        except Exception:
            logger.exception("DoorDash receipt fetch failed")
        return []

    async def store_receipt(
        self,
        source: str,
        order_id: str,
        order_timestamp_ms: int | None,
        total_price_cents: int | None,
        items: list[dict[str, Any]],
        raw_html: str | None = None,
    ) -> GroceryReceipt | None:
        """Store a grocery receipt, skipping if order_id already exists (idempotent)."""
        existing = await self._session.execute(
            select(GroceryReceipt).where(GroceryReceipt.order_id == order_id)
        )
        if existing.scalar_one_or_none() is not None:
            return None  # Already stored

        receipt = GroceryReceipt(
            source=source,
            order_id=order_id,
            order_timestamp_ms=order_timestamp_ms,
            total_price_cents=total_price_cents,
            raw_html=raw_html,
        )
        self._session.add(receipt)
        await self._session.flush()

        for item_data in items:
            gi = GroceryItem(
                receipt_id=receipt.id,
                item_name=item_data.get("name", "unknown"),
                quantity=item_data.get("quantity"),
                unit=item_data.get("unit"),
                price_cents=item_data.get("price_cents"),
                glycemic_index=item_data.get("glycemic_index"),
                category=item_data.get("category"),
            )
            self._session.add(gi)

        await self._session.commit()
        await self._session.refresh(receipt)
        return receipt

    async def get_receipts(
        self,
        source: str | None = None,
        from_ms: int | None = None,
        to_ms: int | None = None,
    ) -> list[GroceryReceipt]:
        """Query grocery receipts with optional filters."""
        query = select(GroceryReceipt).order_by(
            GroceryReceipt.order_timestamp_ms.desc()
        )
        if source is not None:
            query = query.where(GroceryReceipt.source == source)
        if from_ms is not None:
            query = query.where(GroceryReceipt.order_timestamp_ms >= from_ms)
        if to_ms is not None:
            query = query.where(GroceryReceipt.order_timestamp_ms <= to_ms)
        result = await self._session.execute(query)
        return list(result.scalars().all())

    async def get_receipt_items(self, receipt_id: int) -> list[GroceryItem]:
        """Get all items for a specific receipt."""
        result = await self._session.execute(
            select(GroceryItem).where(GroceryItem.receipt_id == receipt_id)
        )
        return list(result.scalars().all())

    async def cross_reference(
        self, from_ms: int | None = None, to_ms: int | None = None
    ) -> list[CrossReferenceResult]:
        """Cross-reference grocery items with meal events in a time window.

        Simple heuristic: match grocery items to meals that occurred within
        7 days after the grocery purchase, based on ingredient name similarity.
        """
        receipts = await self.get_receipts(from_ms=from_ms, to_ms=to_ms)
        results: list[CrossReferenceResult] = []

        for receipt in receipts:
            items = await self.get_receipt_items(receipt.id)
            for item in items:
                # Look for meal events within 7 days after purchase
                purchase_ms = receipt.order_timestamp_ms or 0
                window_end = purchase_ms + (7 * 24 * 60 * 60 * 1000)

                meal_query = (
                    select(MealEvent)
                    .where(MealEvent.timestamp_ms >= purchase_ms)
                    .where(MealEvent.timestamp_ms <= window_end)
                )
                meal_result = await self._session.execute(meal_query)
                meals = meal_result.scalars().all()

                matched_meal_id = None
                confidence = 0.0
                reasoning = None

                for meal in meals:
                    # Simple name-based matching on ingredients JSON
                    if item.item_name.lower() in (meal.ingredients or "").lower():
                        matched_meal_id = meal.id
                        confidence = 0.6
                        reasoning = f"Name match: '{item.item_name}' found in meal ingredients"
                        break

                results.append(
                    CrossReferenceResult(
                        grocery_item=GroceryItemResponse(
                            id=item.id,
                            receipt_id=item.receipt_id,
                            item_name=item.item_name,
                            quantity=item.quantity,
                            unit=item.unit,
                            price_cents=item.price_cents,
                            glycemic_index=item.glycemic_index,
                            category=item.category,
                            resolved=bool(item.resolved),
                        ),
                        matched_meal_event_id=matched_meal_id,
                        match_confidence=confidence,
                        reasoning=reasoning,
                    )
                )

        return results
