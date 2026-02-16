"""Rotimatic Next device adapter — mDNS discovery + REST polling."""

from __future__ import annotations

import json
import logging
import time
from typing import Any

import httpx

from app.config import settings
from app.services.device_protocol import ApplianceProtocol

logger = logging.getLogger(__name__)


class RotimaticAdapter(ApplianceProtocol):
    """Connects to Rotimatic Next via local REST API discovered through mDNS."""

    def __init__(self) -> None:
        self._client = httpx.AsyncClient(timeout=10.0)

    @property
    def device_type(self) -> str:
        return "rotimatic_next"

    async def discover(self) -> list[dict[str, Any]]:
        """Discover Rotimatic devices via mDNS (DNS-SD).

        Uses zeroconf to find _rotimatic._tcp.local. services.
        Returns list of {device_id, ip_address, port, name}.
        """
        try:
            from zeroconf import Zeroconf, ServiceBrowser
            import asyncio

            devices: list[dict[str, Any]] = []
            zc = Zeroconf()

            class Listener:
                def add_service(self, zc: Any, type_: str, name: str) -> None:
                    info = zc.get_service_info(type_, name)
                    if info and info.addresses:
                        import socket

                        ip = socket.inet_ntoa(info.addresses[0])
                        devices.append(
                            {
                                "device_id": info.server or name,
                                "ip_address": ip,
                                "port": info.port,
                                "name": name,
                            }
                        )

                def remove_service(self, zc: Any, type_: str, name: str) -> None:
                    pass

                def update_service(self, zc: Any, type_: str, name: str) -> None:
                    pass

            ServiceBrowser(zc, settings.rotimatic_mdns_type, Listener())
            await asyncio.sleep(3)  # Wait for discovery
            zc.close()
            return devices
        except Exception:
            logger.exception("Rotimatic mDNS discovery failed")
            return []

    async def poll(self, device_id: str, ip_address: str | None = None) -> list[dict[str, Any]]:
        """Poll a Rotimatic device via its REST API for current status."""
        if not ip_address:
            logger.warning("No IP address for Rotimatic %s", device_id)
            return []
        try:
            url = f"http://{ip_address}/api/status"
            resp = await self._client.get(url)
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
            logger.exception("Rotimatic poll failed for %s", device_id)
            raise

    async def get_session_history(
        self, device_id: str, since_ms: int | None = None
    ) -> list[dict[str, Any]]:
        """Rotimatic does not expose session history via REST; returns empty."""
        return []

    async def close(self) -> None:
        await self._client.aclose()
