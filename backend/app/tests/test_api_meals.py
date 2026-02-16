"""Tests for the meals API endpoints."""

import pytest


@pytest.mark.asyncio
class TestMealsAPI:
    async def test_create_manual_meal(self, client):
        resp = await client.post(
            "/api/v1/meals/",
            json={
                "timestamp_ms": 1700000000000,
                "source": "manual",
                "event_type": "manual_log",
                "ingredients": [
                    {
                        "name": "brown rice",
                        "quantity_grams": 200,
                        "glycemic_index": 50,
                    }
                ],
                "confidence": 0.8,
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["source"] == "manual"
        assert data["event_type"] == "manual_log"
        assert data["confidence"] == 0.8
        assert len(data["ingredients"]) == 1
        assert data["ingredients"][0]["name"] == "brown rice"
        # GL auto-computed: (50 * 200 * 0.7) / 100 = 70.0
        assert data["estimated_glycemic_load"] == pytest.approx(70.0, abs=0.01)

    async def test_list_meals_empty(self, client):
        resp = await client.get("/api/v1/meals/")
        assert resp.status_code == 200
        assert resp.json() == []

    async def test_list_meals_after_create(self, client):
        await client.post(
            "/api/v1/meals/",
            json={
                "timestamp_ms": 1700000000000,
                "source": "manual",
                "event_type": "manual_log",
                "ingredients": [],
            },
        )
        resp = await client.get("/api/v1/meals/")
        assert resp.status_code == 200
        assert len(resp.json()) == 1

    async def test_get_meal_by_id(self, client):
        create_resp = await client.post(
            "/api/v1/meals/",
            json={
                "timestamp_ms": 1700000000000,
                "source": "manual",
                "event_type": "manual_log",
                "ingredients": [],
            },
        )
        meal_id = create_resp.json()["id"]
        resp = await client.get(f"/api/v1/meals/{meal_id}")
        assert resp.status_code == 200
        assert resp.json()["id"] == meal_id

    async def test_get_meal_not_found(self, client):
        resp = await client.get("/api/v1/meals/999")
        assert resp.status_code == 404

    async def test_recent_meals(self, client):
        resp = await client.get("/api/v1/meals/recent")
        assert resp.status_code == 200
        assert resp.json() == []

    async def test_filter_by_source(self, client):
        await client.post(
            "/api/v1/meals/",
            json={
                "timestamp_ms": 1700000000000,
                "source": "manual",
                "event_type": "manual_log",
                "ingredients": [],
            },
        )
        await client.post(
            "/api/v1/meals/",
            json={
                "timestamp_ms": 1700000001000,
                "source": "instacart",
                "event_type": "grocery_purchase",
                "ingredients": [],
            },
        )
        resp = await client.get("/api/v1/meals/?source=manual")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["source"] == "manual"
