"""Tests for the sync API endpoints."""

import pytest


@pytest.mark.asyncio
class TestSyncAPI:
    async def test_sync_status_empty(self, client):
        resp = await client.get("/api/v1/sync/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["pending_events"] == 0
        assert data["last_pull_ms"] is None

    async def test_sync_pull_empty(self, client):
        resp = await client.get("/api/v1/sync/pull?since_ms=0")
        assert resp.status_code == 200
        data = resp.json()
        assert data["events"] == []
        assert data["watermark_ms"] == 0
        assert data["has_more"] is False

    async def test_sync_pull_with_events(self, client):
        # Create a meal event
        await client.post(
            "/api/v1/meals/",
            json={
                "timestamp_ms": 1700000000000,
                "source": "manual",
                "event_type": "manual_log",
                "ingredients": [],
            },
        )
        # Pull
        resp = await client.get("/api/v1/sync/pull?since_ms=0")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["events"]) == 1
        assert data["watermark_ms"] == 1700000000000
        assert data["has_more"] is False

    async def test_sync_pull_marks_as_synced(self, client):
        await client.post(
            "/api/v1/meals/",
            json={
                "timestamp_ms": 1700000000000,
                "source": "manual",
                "event_type": "manual_log",
                "ingredients": [],
            },
        )
        # First pull
        await client.get("/api/v1/sync/pull?since_ms=0")
        # Second pull should return nothing (already synced)
        resp = await client.get("/api/v1/sync/pull?since_ms=0")
        data = resp.json()
        assert len(data["events"]) == 0

    async def test_sync_push(self, client):
        resp = await client.post(
            "/api/v1/sync/push",
            json={
                "events": [
                    {
                        "type": "glucose",
                        "timestamp_ms": 1700000000000,
                        "value": 120.5,
                        "unit": "mg/dL",
                    },
                    {
                        "type": "hrv",
                        "timestamp_ms": 1700000001000,
                        "value": 45.0,
                        "unit": "ms",
                    },
                ]
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["received"] == 2

    async def test_sync_status_after_sync(self, client):
        # Create and pull a meal
        await client.post(
            "/api/v1/meals/",
            json={
                "timestamp_ms": 1700000000000,
                "source": "manual",
                "event_type": "manual_log",
                "ingredients": [],
            },
        )
        await client.get("/api/v1/sync/pull?since_ms=0")
        # Check status
        resp = await client.get("/api/v1/sync/status")
        data = resp.json()
        assert data["pending_events"] == 0
        assert data["last_pull_ms"] == 1700000000000
