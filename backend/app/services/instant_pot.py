"""Instant Pot adapter — Instant Connect cloud API polling."""

from __future__ import annotations

import json
import logging
import time
from typing import Any

import httpx

from app.config import settings
from app.services.device_protocol import ApplianceProtocol

logger = logging.getLogger(__name__)


class InstantPotAdapter(ApplianceProtocol):
    """Connects to Instant Pot via the Instant Connect cloud API."""

    def __init__(self) -> None:
        self._client = httpx.AsyncClient(
            timeout=15.0,
            base_url=settings.instant_connect_api_url,
            headers={"Authorization": f"Bearer {settings.instant_connect_token}"},
        )

    @property
    def device_type(self) -> str:
        return "instant_pot"

    async def discover(self) -> list[dict[str, Any]]:
        """List devices registered to the Instant Connect account."""
        try:
            resp = await self._client.get("/v1/devices")
            resp.raise_for_status()
            devices = resp.json().get("devices", [])
            return [
                {
                    "device_id": d.get("serial", d.get("id", "")),
                    "ip_address": None,
                    "name": d.get("name", "Instant Pot"),
                }
                for d in devices
            ]
        except Exception:
            logger.exception("Instant Connect device discovery failed")
            return []

    async def poll(self, device_id: str, ip_address: str | None = None) -> list[dict[str, Any]]:
        """Poll Instant Connect cloud API for device status."""
        try:
            resp = await self._client.get(f"/v1/devices/{device_id}/status")
            resp.raise_for_status()
            data = resp.json()
            return [
                {
                    "device_type": self.device_type,
                    "device_id": device_id,
                    "timestamp_ms": int(time.time() * 1000),
                    "raw_payload": json.dumps(data),
                    "session_id": data.get("session_id"),
                }
            ]
        except Exception:
            logger.exception("Instant Pot poll failed for %s", device_id)
            raise

    async def get_session_history(
        self, device_id: str, since_ms: int | None = None
    ) -> list[dict[str, Any]]:
        """Fetch cooking session history from Instant Connect API."""
        try:
            params: dict[str, Any] = {}
            if since_ms is not None:
                params["since"] = since_ms
            resp = await self._client.get(
                f"/v1/devices/{device_id}/sessions", params=params
            )
            resp.raise_for_status()
            sessions = resp.json().get("sessions", [])
            events = []
            for session in sessions:
                events.append(
                    {
                        "device_type": self.device_type,
                        "device_id": device_id,
                        "timestamp_ms": session.get("start_ms", int(time.time() * 1000)),
                        "raw_payload": json.dumps(session),
                        "session_id": session.get("session_id"),
                    }
                )
            return events
        except Exception:
            logger.exception("Instant Pot session history fetch failed for %s", device_id)
            return []

    async def close(self) -> None:
        await self._client.aclose()
