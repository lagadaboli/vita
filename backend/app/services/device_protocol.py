"""Abstract base class for appliance protocol adapters."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class ApplianceProtocol(ABC):
    """Interface for device-specific polling and discovery."""

    @abstractmethod
    async def discover(self) -> list[dict[str, Any]]:
        """Discover devices on the network. Returns list of device info dicts."""
        ...

    @abstractmethod
    async def poll(self, device_id: str, ip_address: str | None = None) -> list[dict[str, Any]]:
        """Poll a device for new events. Returns list of raw event dicts."""
        ...

    @abstractmethod
    async def get_session_history(
        self, device_id: str, since_ms: int | None = None
    ) -> list[dict[str, Any]]:
        """Fetch historical session data for gap recovery."""
        ...

    @property
    @abstractmethod
    def device_type(self) -> str:
        """The device type identifier (e.g. 'rotimatic_next')."""
        ...
