"""MCP-shaped DB adapters for causal engine data access.

Each adapter queries existing DB tables and returns MCPToolResult.
data=None triggers the hallucination guard (agent cannot blame that source).
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass
from typing import Any

from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.appliance_event import ApplianceEvent
from app.models.causal_edge import CausalEdge
from app.models.grocery_receipt import GroceryItem, GroceryReceipt
from app.models.health_event import HealthEvent
from app.models.meal_event import MealEvent
from app.models.reasoning_trace import ReasoningTrace
from app.services.causal.glucose_classifier import (
    EnergyState,
    GlucoseTrend,
    classify_energy_state,
    classify_trend,
)


@dataclass
class MCPToolResult:
    """Standard result from an MCP adapter. data=None means no data available."""

    data: dict[str, Any] | None
    source: str


class AppleHealthAdapter:
    """Reads HRV and heart rate from health_events table."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_pulse(self, window_min: int = 30) -> MCPToolResult:
        """Get recent HRV and heart rate readings within window."""
        cutoff_ms = int((time.time() - window_min * 60) * 1000)

        # Get latest HRV
        hrv_q = (
            select(HealthEvent)
            .where(HealthEvent.event_type == "hrv")
            .where(HealthEvent.timestamp_ms >= cutoff_ms)
            .order_by(desc(HealthEvent.timestamp_ms))
            .limit(1)
        )
        hrv_result = await self.session.execute(hrv_q)
        hrv_row = hrv_result.scalar_one_or_none()

        # Get latest heart rate
        hr_q = (
            select(HealthEvent)
            .where(HealthEvent.event_type == "heartRate")
            .where(HealthEvent.timestamp_ms >= cutoff_ms)
            .order_by(desc(HealthEvent.timestamp_ms))
            .limit(1)
        )
        hr_result = await self.session.execute(hr_q)
        hr_row = hr_result.scalar_one_or_none()

        if hrv_row is None and hr_row is None:
            return MCPToolResult(data=None, source="apple_health")

        data: dict[str, Any] = {}
        if hrv_row:
            data["hrv_ms"] = hrv_row.value
            data["hrv_timestamp_ms"] = hrv_row.timestamp_ms
        if hr_row:
            data["heart_rate_bpm"] = hr_row.value
            data["hr_timestamp_ms"] = hr_row.timestamp_ms

        return MCPToolResult(data=data, source="apple_health")

    async def get_hrv_baseline(self, lookback_days: int = 7) -> float | None:
        """Get average HRV over the lookback period."""
        cutoff_ms = int((time.time() - lookback_days * 86400) * 1000)
        from sqlalchemy import func

        q = (
            select(func.avg(HealthEvent.value))
            .where(HealthEvent.event_type == "hrv")
            .where(HealthEvent.timestamp_ms >= cutoff_ms)
        )
        result = await self.session.execute(q)
        return result.scalar_one_or_none()


class CGMSteloAdapter:
    """Reads glucose data from health_events table."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_current_glucose(self) -> MCPToolResult:
        """Get most recent glucose reading with trend and energy state."""
        # Get last 2 glucose readings for trend calculation
        q = (
            select(HealthEvent)
            .where(HealthEvent.event_type == "glucose")
            .order_by(desc(HealthEvent.timestamp_ms))
            .limit(2)
        )
        result = await self.session.execute(q)
        readings = list(result.scalars().all())

        if not readings:
            return MCPToolResult(data=None, source="cgm_stelo")

        current = readings[0]
        data: dict[str, Any] = {
            "value_mg_dl": current.value,
            "timestamp_ms": current.timestamp_ms,
        }

        # Compute trend if we have 2 readings
        if len(readings) == 2:
            prev = readings[1]
            delta_min = (current.timestamp_ms - prev.timestamp_ms) / 60_000
            if delta_min > 0:
                rate = (current.value - prev.value) / delta_min
                data["trend"] = classify_trend(rate).value
                data["rate_mg_per_min"] = round(rate, 2)

        # Compute energy state — need peak glucose for delta
        peak = await self._get_recent_peak(window_min=150)
        delta_from_peak = current.value - peak if peak else 0.0
        energy = classify_energy_state(current.value, delta_from_peak)
        data["energy_state"] = energy.value

        return MCPToolResult(data=data, source="cgm_stelo")

    async def _get_recent_peak(self, window_min: int = 150) -> float | None:
        """Get peak glucose in the last N minutes."""
        from sqlalchemy import func

        cutoff_ms = int((time.time() - window_min * 60) * 1000)
        q = (
            select(func.max(HealthEvent.value))
            .where(HealthEvent.event_type == "glucose")
            .where(HealthEvent.timestamp_ms >= cutoff_ms)
        )
        result = await self.session.execute(q)
        return result.scalar_one_or_none()

    async def get_glucose_window(
        self, start_ms: int, end_ms: int
    ) -> list[dict[str, Any]]:
        """Get glucose readings in a time window."""
        q = (
            select(HealthEvent)
            .where(HealthEvent.event_type == "glucose")
            .where(HealthEvent.timestamp_ms >= start_ms)
            .where(HealthEvent.timestamp_ms <= end_ms)
            .order_by(HealthEvent.timestamp_ms.asc())
        )
        result = await self.session.execute(q)
        return [
            {"value": r.value, "timestamp_ms": r.timestamp_ms}
            for r in result.scalars().all()
        ]


class RotimaticServerAdapter:
    """Reads Rotimatic session data from appliance_events + meal_events."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_last_session(self) -> MCPToolResult:
        """Get most recent Rotimatic cooking session."""
        q = (
            select(ApplianceEvent)
            .where(ApplianceEvent.device_type == "rotimatic")
            .order_by(desc(ApplianceEvent.timestamp_ms))
            .limit(1)
        )
        result = await self.session.execute(q)
        event = result.scalar_one_or_none()

        if event is None:
            return MCPToolResult(data=None, source="rotimatic_server")

        data: dict[str, Any] = {
            "timestamp_ms": event.timestamp_ms,
            "session_id": event.session_id,
            "device_id": event.device_id,
        }

        # Parse raw payload for flour type, roti count
        try:
            payload = json.loads(event.raw_payload) if event.raw_payload else {}
            data["flour_type"] = payload.get("flour_type")
            data["roti_count"] = payload.get("roti_count")
        except (json.JSONDecodeError, TypeError):
            pass

        # Find associated meal event
        if event.id:
            meal_q = (
                select(MealEvent)
                .where(MealEvent.appliance_event_id == event.id)
                .limit(1)
            )
            meal_result = await self.session.execute(meal_q)
            meal = meal_result.scalar_one_or_none()
            if meal:
                data["glycemic_load"] = meal.estimated_glycemic_load
                data["bioavailability_modifier"] = meal.bioavailability_modifier

        return MCPToolResult(data=data, source="rotimatic_server")


class InstacartServerAdapter:
    """Reads grocery receipt data from grocery_receipts + grocery_items."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_recent_receipts(self, days: int = 7) -> MCPToolResult:
        """Get grocery receipts from the last N days."""
        cutoff_ms = int((time.time() - days * 86400) * 1000)

        q = (
            select(GroceryReceipt)
            .where(GroceryReceipt.order_timestamp_ms >= cutoff_ms)
            .order_by(desc(GroceryReceipt.order_timestamp_ms))
            .limit(10)
        )
        result = await self.session.execute(q)
        receipts = list(result.scalars().all())

        if not receipts:
            return MCPToolResult(data=None, source="instacart_server")

        receipt_data = []
        for receipt in receipts:
            items_q = select(GroceryItem).where(
                GroceryItem.receipt_id == receipt.id
            )
            items_result = await self.session.execute(items_q)
            items = [
                {
                    "name": item.item_name,
                    "category": item.category,
                    "glycemic_index": item.glycemic_index,
                }
                for item in items_result.scalars().all()
            ]
            receipt_data.append(
                {
                    "order_id": receipt.order_id,
                    "timestamp_ms": receipt.order_timestamp_ms,
                    "source": receipt.source,
                    "items": items,
                }
            )

        return MCPToolResult(data={"receipts": receipt_data}, source="instacart_server")


class StateStoreMCPAdapter:
    """Reads/writes reasoning traces and causal edges."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_state(self, limit: int = 10) -> MCPToolResult:
        """Get recent reasoning traces and causal edges."""
        traces_q = (
            select(ReasoningTrace)
            .order_by(desc(ReasoningTrace.id))
            .limit(limit)
        )
        traces_result = await self.session.execute(traces_q)
        traces = [
            {
                "id": t.id,
                "symptom": t.symptom,
                "phase": t.phase,
                "conclusion": t.conclusion,
                "confidence": t.confidence,
                "narrative": t.narrative,
            }
            for t in traces_result.scalars().all()
        ]

        edges_q = (
            select(CausalEdge)
            .order_by(desc(CausalEdge.id))
            .limit(limit)
        )
        edges_result = await self.session.execute(edges_q)
        edges = [
            {
                "id": e.id,
                "source": e.source_node_id,
                "target": e.target_node_id,
                "edge_type": e.edge_type,
                "strength": e.causal_strength,
                "confidence": e.confidence,
            }
            for e in edges_result.scalars().all()
        ]

        return MCPToolResult(
            data={"traces": traces, "edges": edges},
            source="state_store",
        )

    async def save_trace(self, trace: ReasoningTrace) -> int:
        """Persist a reasoning trace and return its ID."""
        self.session.add(trace)
        await self.session.flush()
        return trace.id

    async def save_edge(self, edge: CausalEdge) -> int:
        """Persist a causal edge and return its ID."""
        self.session.add(edge)
        await self.session.flush()
        return edge.id
