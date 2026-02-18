"""Tests for causal engine API endpoints."""

import time

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import get_session
from app.models.base import Base
from app.models.health_event import HealthEvent
from app.models.reasoning_trace import ReasoningTrace


@pytest_asyncio.fixture
async def causal_client():
    """FastAPI test client with in-memory DB for causal tests."""
    engine = create_async_engine("sqlite+aiosqlite://", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    from app.main import app

    async def override_get_session():
        async with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_get_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac, session_factory

    app.dependency_overrides.clear()
    await engine.dispose()


@pytest.mark.asyncio
async def test_query_endpoint(causal_client):
    client, _ = causal_client
    resp = await client.post("/api/v1/causal/query", json={"symptom": "fatigue"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["symptom"] == "fatigue"
    assert "narrative" in data
    assert "confidence" in data
    assert "causal_chain" in data


@pytest.mark.asyncio
async def test_debt_endpoint(causal_client):
    client, _ = causal_client
    resp = await client.get("/api/v1/causal/debt?window_hours=6")
    assert resp.status_code == 200
    data = resp.json()
    assert "metabolic_debt" in data
    assert "digital_debt" in data
    assert data["window_hours"] == 6


@pytest.mark.asyncio
async def test_debt_with_glucose_data(causal_client):
    client, session_factory = causal_client
    now_ms = int(time.time() * 1000)

    async with session_factory() as session:
        session.add(HealthEvent(event_type="glucose", timestamp_ms=now_ms, value=160.0, unit="mg/dL"))
        session.add(HealthEvent(event_type="glucose", timestamp_ms=now_ms - 60_000, value=90.0, unit="mg/dL"))
        await session.commit()

    resp = await client.get("/api/v1/causal/debt?window_hours=1")
    assert resp.status_code == 200
    data = resp.json()
    assert data["metabolic_debt"] >= 0


@pytest.mark.asyncio
async def test_glucose_current_empty(causal_client):
    client, _ = causal_client
    resp = await client.get("/api/v1/causal/glucose/current")
    assert resp.status_code == 200
    data = resp.json()
    assert data["value_mg_dl"] is None


@pytest.mark.asyncio
async def test_glucose_current_with_data(causal_client):
    client, session_factory = causal_client
    now_ms = int(time.time() * 1000)

    async with session_factory() as session:
        session.add(HealthEvent(event_type="glucose", timestamp_ms=now_ms - 60_000, value=100.0, unit="mg/dL"))
        session.add(HealthEvent(event_type="glucose", timestamp_ms=now_ms, value=145.0, unit="mg/dL"))
        await session.commit()

    resp = await client.get("/api/v1/causal/glucose/current")
    assert resp.status_code == 200
    data = resp.json()
    assert data["value_mg_dl"] == 145.0
    assert data["energy_state"] is not None


@pytest.mark.asyncio
async def test_traces_empty(causal_client):
    client, _ = causal_client
    resp = await client.get("/api/v1/causal/traces")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_traces_after_query(causal_client):
    client, _ = causal_client

    # Run a query first
    await client.post("/api/v1/causal/query", json={"symptom": "headache"})

    resp = await client.get("/api/v1/causal/traces")
    assert resp.status_code == 200
    traces = resp.json()
    assert len(traces) >= 1
    assert traces[0]["symptom"] == "headache"


@pytest.mark.asyncio
async def test_trace_detail_not_found(causal_client):
    client, _ = causal_client
    resp = await client.get("/api/v1/causal/traces/999")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_trace_detail_found(causal_client):
    client, session_factory = causal_client

    async with session_factory() as session:
        trace = ReasoningTrace(
            symptom="test", phase="inference",
            hypotheses_json="[]", observations_json="[]",
            conclusion="metabolic", confidence=0.8,
            narrative="Test trace",
        )
        session.add(trace)
        await session.commit()
        trace_id = trace.id

    resp = await client.get(f"/api/v1/causal/traces/{trace_id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["symptom"] == "test"
    assert data["hypotheses_json"] == "[]"


@pytest.mark.asyncio
async def test_counterfactual_meal(causal_client):
    client, _ = causal_client
    resp = await client.post("/api/v1/causal/counterfactual", json={"node_id": "meal_1"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["node_id"] == "meal_1"
    assert len(data["counterfactuals"]) > 0


@pytest.mark.asyncio
async def test_counterfactual_behavioral(causal_client):
    client, _ = causal_client
    resp = await client.post("/api/v1/causal/counterfactual", json={"node_id": "behavioral_1"})
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["counterfactuals"]) > 0


@pytest.mark.asyncio
async def test_sync_push_persists_events(causal_client):
    """Verify that POST /sync/push now persists health events."""
    client, session_factory = causal_client
    payload = {
        "events": [
            {"type": "glucose", "timestamp_ms": 1000000, "value": 142.0, "unit": "mg/dL"},
            {"type": "hrv", "timestamp_ms": 1000001, "value": 45.0, "unit": "ms"},
        ]
    }
    resp = await client.post("/api/v1/sync/push", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["received"] == 2

    # Verify they're in the DB
    from sqlalchemy import select
    async with session_factory() as session:
        result = await session.execute(select(HealthEvent))
        events = list(result.scalars().all())
        assert len(events) == 2
        assert events[0].event_type in ("glucose", "hrv")


@pytest.mark.asyncio
async def test_safety_bypass_via_api(causal_client):
    """HRV < 20 should trigger safety bypass through the API."""
    client, session_factory = causal_client
    now_ms = int(time.time() * 1000)

    async with session_factory() as session:
        session.add(HealthEvent(event_type="hrv", timestamp_ms=now_ms, value=12.0, unit="ms"))
        await session.commit()

    resp = await client.post("/api/v1/causal/query", json={"symptom": "dizziness"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["safety_bypass"] is True
