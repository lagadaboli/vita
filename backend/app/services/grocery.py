"""Grocery receipt fetcher and appliance cross-reference service."""

from __future__ import annotations

import logging
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.grocery_receipt import GroceryItem, GroceryReceipt
from app.models.meal_event import MealEvent
from app.schemas.grocery import CrossReferenceResult, GroceryItemResponse

logger = logging.getLogger(__name__)


class GroceryService:
    """Handles receipt fetching and grocery-to-meal cross-referencing."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def fetch_instacart_receipts(self, session_cookie: str) -> list[dict[str, Any]]:
        """Fetch recent Instacart orders using stored session cookie.

        Returns raw receipt data. Actual parsing happens in store_receipt().
        """
        if not session_cookie:
            logger.warning("No Instacart session cookie configured")
            return []

        try:
            async with httpx.AsyncClient(
                headers={"Cookie": f"session={session_cookie}"},
                timeout=30.0,
            ) as client:
                resp = await client.get("https://www.instacart.com/api/v3/orders")
                resp.raise_for_status()
                return resp.json().get("orders", [])
        except Exception:
            logger.exception("Instacart receipt fetch failed")
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
