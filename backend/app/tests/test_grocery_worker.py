"""Tests for GroceryWorker Instacart MCP ingestion."""

from __future__ import annotations

import json

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

import app.workers.grocery_worker as grocery_worker_module
from app.config import settings
from app.models.grocery_receipt import GroceryReceipt
from app.models.meal_event import MealEvent
from app.services.grocery import GroceryService
from app.workers.grocery_worker import GroceryWorker


def _mock_instacart_orders() -> list[dict]:
    return [
        {
            "id": "ic-test-order-001",
            "created_at_ms": 1_700_000_000_000,
            "total_cents": 4599,
            "items": [
                {
                    "name": "Bananas",
                    "category": "fruit",
                    "glycemic_index": 51.0,
                    "quantity": 510,
                    "unit": "g",
                },
                {
                    "name": "Greek Yogurt",
                    "category": "dairy",
                    "glycemic_index": 11.0,
                    "quantity": 32,
                    "unit": "oz",
                },
            ],
        }
    ]


@pytest.mark.asyncio
async def test_instacart_fetch_creates_receipt_and_meal(db_engine, monkeypatch):
    session_factory = async_sessionmaker(
        db_engine, class_=AsyncSession, expire_on_commit=False
    )
    monkeypatch.setattr(grocery_worker_module, "async_session", session_factory)
    monkeypatch.setattr(settings, "instacart_mcp_stdio_command", "mock-instacart")
    monkeypatch.setattr(settings, "doordash_mcp_stdio_command", "")

    async def fake_fetch(self, days: int = 7) -> list[dict]:
        return _mock_instacart_orders()

    monkeypatch.setattr(GroceryService, "fetch_instacart_receipts_mcp", fake_fetch)

    worker = GroceryWorker()
    await worker.fetch_now()

    async with session_factory() as session:
        receipts = list(
            (
                await session.execute(
                    select(GroceryReceipt).where(GroceryReceipt.source == "instacart")
                )
            )
            .scalars()
            .all()
        )
        meals = list(
            (
                await session.execute(
                    select(MealEvent).where(MealEvent.source == "instacart")
                )
            )
            .scalars()
            .all()
        )

    assert len(receipts) == 1
    assert len(meals) == 1
    assert meals[0].event_type == "grocery_purchase"
    assert meals[0].synced_to_mobile == 0

    ingredients = json.loads(meals[0].ingredients)
    assert ingredients[0]["name"] == "Bananas"
    assert ingredients[0]["quantity_grams"] == 510.0
    assert ingredients[1]["quantity_grams"] == pytest.approx(907.184)


@pytest.mark.asyncio
async def test_instacart_fetch_is_idempotent_for_meal_events(db_engine, monkeypatch):
    session_factory = async_sessionmaker(
        db_engine, class_=AsyncSession, expire_on_commit=False
    )
    monkeypatch.setattr(grocery_worker_module, "async_session", session_factory)
    monkeypatch.setattr(settings, "instacart_mcp_stdio_command", "mock-instacart")
    monkeypatch.setattr(settings, "doordash_mcp_stdio_command", "")

    async def fake_fetch(self, days: int = 7) -> list[dict]:
        return _mock_instacart_orders()

    monkeypatch.setattr(GroceryService, "fetch_instacart_receipts_mcp", fake_fetch)

    worker = GroceryWorker()
    await worker.fetch_now()
    await worker.fetch_now()

    async with session_factory() as session:
        receipt_count = (
            await session.execute(
                select(GroceryReceipt).where(GroceryReceipt.source == "instacart")
            )
        ).scalars().all()
        meal_count = (
            await session.execute(
                select(MealEvent).where(MealEvent.source == "instacart")
            )
        ).scalars().all()

    assert len(receipt_count) == 1
    assert len(meal_count) == 1


@pytest.mark.asyncio
async def test_doordash_fetch_from_session_cookie_creates_meal(db_engine, monkeypatch):
    session_factory = async_sessionmaker(
        db_engine, class_=AsyncSession, expire_on_commit=False
    )
    monkeypatch.setattr(grocery_worker_module, "async_session", session_factory)
    monkeypatch.setattr(settings, "doordash_session_cookie", "dd_session_id=live-cookie")
    monkeypatch.setattr(settings, "doordash_mcp_stdio_command", "")
    monkeypatch.setattr(settings, "instacart_session_cookie", "")
    monkeypatch.setattr(settings, "instacart_mcp_stdio_command", "")

    async def fake_fetch(self, session_cookie: str):
        assert "dd_session_id" in session_cookie
        return [
            {
                "id": "dd-live-order-001",
                "created_at_ms": 1_700_010_000_000,
                "total_cents": 2199,
                "items": [
                    {
                        "name": "Chicken Bowl",
                        "category": "main",
                        "glycemic_index": 40.0,
                        "quantity": 1,
                        "unit": "serving",
                    }
                ],
            }
        ]

    monkeypatch.setattr(GroceryService, "fetch_doordash_receipts", fake_fetch)

    worker = GroceryWorker()
    await worker.fetch_now()

    async with session_factory() as session:
        receipts = (
            await session.execute(
                select(GroceryReceipt).where(GroceryReceipt.source == "doordash")
            )
        ).scalars().all()
        meals = (
            await session.execute(
                select(MealEvent).where(MealEvent.source == "doordash")
            )
        ).scalars().all()

    assert len(receipts) == 1
    assert len(meals) == 1
    assert meals[0].event_type == "meal_delivery"
