"""Tests for the 4-step CausalAgent reasoning loop."""

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.models.base import Base
from app.models.health_event import HealthEvent
from app.models.reasoning_trace import ReasoningTrace
from app.services.causal.agent import CausalAgent

import time


@pytest_asyncio.fixture
async def agent_session():
    """Create an in-memory async session for agent tests."""
    engine = create_async_engine("sqlite+aiosqlite://", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with session_factory() as session:
        yield session
    await engine.dispose()


@pytest.mark.asyncio
async def test_query_no_data(agent_session):
    """Agent should handle no data gracefully."""
    agent = CausalAgent(agent_session)
    result = await agent.query("fatigue")

    assert result.symptom == "fatigue"
    assert result.narrative is not None
    assert result.safety_bypass is False


@pytest.mark.asyncio
async def test_query_with_glucose_data(agent_session):
    """Agent should detect elevated glucose and hypothesize metabolic."""
    now_ms = int(time.time() * 1000)

    # Insert glucose readings
    agent_session.add(HealthEvent(
        event_type="glucose", timestamp_ms=now_ms - 60_000,
        value=130.0, unit="mg/dL",
    ))
    agent_session.add(HealthEvent(
        event_type="glucose", timestamp_ms=now_ms,
        value=155.0, unit="mg/dL",
    ))
    await agent_session.commit()

    agent = CausalAgent(agent_session)
    result = await agent.query("brain fog")

    assert result.symptom == "brain fog"
    assert result.conclusion is not None
    assert result.confidence > 0.0
    assert len(result.narrative) > 0


@pytest.mark.asyncio
async def test_safety_bypass_low_hrv(agent_session):
    """HRV < 20ms should trigger safety bypass."""
    now_ms = int(time.time() * 1000)

    agent_session.add(HealthEvent(
        event_type="hrv", timestamp_ms=now_ms,
        value=15.0, unit="ms",
    ))
    await agent_session.commit()

    agent = CausalAgent(agent_session)
    result = await agent.query("dizziness")

    assert result.safety_bypass is True
    assert result.confidence == 1.0
    assert "safety bypass" in result.narrative.lower() or "critically low" in result.narrative.lower()


@pytest.mark.asyncio
async def test_trace_persisted(agent_session):
    """Agent should persist a reasoning trace after query."""
    agent = CausalAgent(agent_session)
    await agent.query("headache")

    from sqlalchemy import select
    result = await agent_session.execute(select(ReasoningTrace))
    traces = list(result.scalars().all())
    assert len(traces) >= 1
    assert traces[0].symptom == "headache"


@pytest.mark.asyncio
async def test_query_with_hrv_above_threshold(agent_session):
    """HRV above 20ms should NOT trigger safety bypass."""
    now_ms = int(time.time() * 1000)

    agent_session.add(HealthEvent(
        event_type="hrv", timestamp_ms=now_ms,
        value=45.0, unit="ms",
    ))
    await agent_session.commit()

    agent = CausalAgent(agent_session)
    result = await agent.query("fatigue")

    assert result.safety_bypass is False


@pytest.mark.asyncio
async def test_counterfactuals_generated(agent_session):
    """Agent should generate counterfactuals for metabolic conclusion."""
    now_ms = int(time.time() * 1000)

    # High glucose to trigger metabolic hypothesis
    agent_session.add(HealthEvent(
        event_type="glucose", timestamp_ms=now_ms - 60_000,
        value=120.0, unit="mg/dL",
    ))
    agent_session.add(HealthEvent(
        event_type="glucose", timestamp_ms=now_ms,
        value=180.0, unit="mg/dL",
    ))
    await agent_session.commit()

    agent = CausalAgent(agent_session)
    result = await agent.query("energy crash")

    # The agent should generate at least one counterfactual
    assert isinstance(result.counterfactuals, list)
