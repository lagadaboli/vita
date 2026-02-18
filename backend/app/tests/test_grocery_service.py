"""Tests for MCP payload normalization in grocery services/adapters."""

from __future__ import annotations

import pytest

import app.services.grocery as grocery_module
from app.services.causal.mcp_adapters import InstacartServerAdapter
from app.services.grocery import GroceryService


@pytest.mark.asyncio
async def test_fetch_receipts_via_mcp_normalizes_camel_case(db_session, monkeypatch):
    async def fake_call(*args, **kwargs):
        return {
            "data": {
                "orders": [
                    {
                        "orderId": "ic-camel-001",
                        "createdAtMs": 1_700_001_000_000,
                        "totalPriceCents": 3299,
                        "lineItems": [
                            {
                                "itemName": "Steel Cut Oats",
                                "quantity": 680,
                                "unit": "g",
                                "priceCents": 899,
                                "glycemicIndex": 55.0,
                                "category": "grain",
                            }
                        ],
                    }
                ]
            }
        }

    monkeypatch.setattr(grocery_module, "call_mcp_tool_stdio", fake_call)

    service = GroceryService(db_session)
    orders = await service.fetch_receipts_via_mcp(
        command="mock-command",
        tool_name="get_recent_orders",
        source="instacart",
        days=7,
    )

    assert len(orders) == 1
    assert orders[0]["id"] == "ic-camel-001"
    assert orders[0]["created_at_ms"] == 1_700_001_000_000
    assert orders[0]["total_cents"] == 3299
    assert len(orders[0]["items"]) == 1
    assert orders[0]["items"][0]["name"] == "Steel Cut Oats"
    assert orders[0]["items"][0]["glycemic_index"] == 55.0


def test_instacart_adapter_normalizes_nested_data_orders():
    normalized = InstacartServerAdapter._normalize_mcp_payload(
        {
            "data": {
                "orders": [
                    {
                        "orderId": "ic-nested-001",
                        "createdAtMs": 1_700_002_000_000,
                        "lineItems": [
                            {
                                "itemName": "Brown Rice",
                                "glycemicIndex": 50.0,
                                "category": "grain",
                            }
                        ],
                    }
                ]
            }
        }
    )

    assert len(normalized) == 1
    assert normalized[0]["order_id"] == "ic-nested-001"
    assert normalized[0]["timestamp_ms"] == 1_700_002_000_000
    assert normalized[0]["items"][0]["name"] == "Brown Rice"
    assert normalized[0]["items"][0]["glycemic_index"] == 50.0


class _FakeResponse:
    def __init__(self, status_code: int, payload: dict):
        self.status_code = status_code
        self._payload = payload

    def json(self) -> dict:
        return self._payload


class _FakeAsyncClient:
    def __init__(self, responses_by_url: dict[str, _FakeResponse], **kwargs):
        self._responses = responses_by_url

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return None

    async def get(self, url: str):
        return self._responses.get(url, _FakeResponse(404, {}))


@pytest.mark.asyncio
async def test_fetch_instacart_receipts_uses_cookie_and_normalizes(db_session, monkeypatch):
    responses = {
        "https://www.instacart.com/api/v3/orders": _FakeResponse(
            200,
            {
                "orders": [
                    {
                        "orderId": "ic-live-001",
                        "createdAtMs": 1_700_003_000_000,
                        "lineItems": [
                            {
                                "itemName": "Milk",
                                "quantity": 1,
                                "unit": "quart",
                                "priceCents": 499,
                                "category": "dairy",
                            }
                        ],
                    }
                ]
            },
        )
    }

    monkeypatch.setattr(
        grocery_module,
        "httpx",
        type(
            "FakeHttpx",
            (),
            {"AsyncClient": lambda **kwargs: _FakeAsyncClient(responses_by_url=responses)},
        ),
    )

    service = GroceryService(db_session)
    orders = await service.fetch_instacart_receipts("session=abc123; csrftoken=xyz")

    assert len(orders) == 1
    assert orders[0]["id"] == "ic-live-001"
    assert orders[0]["items"][0]["name"] == "Milk"


@pytest.mark.asyncio
async def test_fetch_doordash_receipts_uses_cookie_and_normalizes(db_session, monkeypatch):
    responses = {
        "https://www.doordash.com/consumer/v1/orders?offset=0&limit=100": _FakeResponse(
            200,
            {
                "data": {
                    "orders": [
                        {
                            "orderId": "dd-live-001",
                            "createdAtMs": 1_700_004_000_000,
                            "orderItems": [
                                {
                                    "itemName": "Paneer Bowl",
                                    "quantity": 1,
                                    "priceCents": 1499,
                                    "category": "main",
                                }
                            ],
                        }
                    ]
                }
            },
        )
    }

    monkeypatch.setattr(
        grocery_module,
        "httpx",
        type(
            "FakeHttpx",
            (),
            {"AsyncClient": lambda **kwargs: _FakeAsyncClient(responses_by_url=responses)},
        ),
    )

    service = GroceryService(db_session)
    orders = await service.fetch_doordash_receipts("dd_session_id=abc123")

    assert len(orders) == 1
    assert orders[0]["id"] == "dd-live-001"
    assert orders[0]["items"][0]["name"] == "Paneer Bowl"
