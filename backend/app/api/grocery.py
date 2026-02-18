"""Grocery receipt and cross-reference endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.schemas.grocery import CrossReferenceResult, GroceryItemResponse, GroceryReceiptResponse
from app.services.grocery import GroceryService

router = APIRouter(prefix="/api/v1/grocery", tags=["grocery"])


@router.get("/receipts", response_model=list[GroceryReceiptResponse])
async def list_receipts(
    source: str | None = Query(None),
    from_ms: int | None = Query(None),
    to_ms: int | None = Query(None),
    session: AsyncSession = Depends(get_session),
):
    """Query grocery receipts with optional filters."""
    service = GroceryService(session)
    receipts = await service.get_receipts(source=source, from_ms=from_ms, to_ms=to_ms)
    results = []
    for r in receipts:
        items = await service.get_receipt_items(r.id)
        results.append(
            GroceryReceiptResponse(
                id=r.id,
                source=r.source,
                order_id=r.order_id,
                order_timestamp_ms=r.order_timestamp_ms,
                total_price_cents=r.total_price_cents,
                fetched_at=r.fetched_at,
                items=[
                    GroceryItemResponse(
                        id=i.id,
                        receipt_id=i.receipt_id,
                        item_name=i.item_name,
                        quantity=i.quantity,
                        unit=i.unit,
                        price_cents=i.price_cents,
                        glycemic_index=i.glycemic_index,
                        category=i.category,
                        resolved=bool(i.resolved),
                    )
                    for i in items
                ],
            )
        )
    return results


@router.get("/receipts/{receipt_id}/items", response_model=list[GroceryItemResponse])
async def get_receipt_items(
    receipt_id: int,
    session: AsyncSession = Depends(get_session),
):
    """Get all items for a specific receipt."""
    service = GroceryService(session)
    items = await service.get_receipt_items(receipt_id)
    if not items:
        raise HTTPException(status_code=404, detail="Receipt not found or has no items")
    return [
        GroceryItemResponse(
            id=i.id,
            receipt_id=i.receipt_id,
            item_name=i.item_name,
            quantity=i.quantity,
            unit=i.unit,
            price_cents=i.price_cents,
            glycemic_index=i.glycemic_index,
            category=i.category,
            resolved=bool(i.resolved),
        )
        for i in items
    ]


@router.post("/fetch")
async def trigger_fetch():
    """Trigger a manual grocery receipt fetch."""
    from app.workers.grocery_worker import GroceryWorker
    worker = GroceryWorker()
    await worker.fetch_now()
    return {"message": "Grocery fetch complete"}


@router.get("/cross-reference", response_model=list[CrossReferenceResult])
async def cross_reference(
    from_ms: int | None = Query(None),
    to_ms: int | None = Query(None),
    session: AsyncSession = Depends(get_session),
):
    """Cross-reference grocery items with appliance cooking data."""
    service = GroceryService(session)
    return await service.cross_reference(from_ms=from_ms, to_ms=to_ms)
