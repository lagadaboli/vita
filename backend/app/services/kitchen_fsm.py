"""Kitchen State Finite State Machine.

States: idle → cooking → meal_ready → meal_consumed → idle

The FSM is persisted in the kitchen_states table so it survives restarts.
"""

from __future__ import annotations

import json
import logging
import time

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.kitchen_state import KitchenStateRecord
from app.schemas.kitchen import VALID_TRANSITIONS, KitchenStateEnum

logger = logging.getLogger(__name__)


class KitchenFSM:
    """Manages kitchen state transitions with DB persistence."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_current_state(self) -> KitchenStateRecord | None:
        """Get the most recent state record (the one without an exit time)."""
        result = await self._session.execute(
            select(KitchenStateRecord)
            .where(KitchenStateRecord.exited_at_ms.is_(None))
            .order_by(KitchenStateRecord.entered_at_ms.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def get_current_state_enum(self) -> KitchenStateEnum:
        """Get the current state as an enum, defaulting to idle."""
        record = await self.get_current_state()
        if record is None:
            return KitchenStateEnum.idle
        return KitchenStateEnum(record.state)

    async def transition(
        self,
        trigger: str,
        device_type: str | None = None,
        event_id: int | None = None,
        metadata: dict | None = None,
    ) -> KitchenStateRecord:
        """Attempt a state transition.

        Raises ValueError if the transition is invalid.
        Returns the new state record.
        """
        current = await self.get_current_state()
        current_enum = KitchenStateEnum(current.state) if current else KitchenStateEnum.idle

        key = (current_enum, trigger)
        next_state = VALID_TRANSITIONS.get(key)

        if next_state is None:
            raise ValueError(
                f"Invalid transition: {current_enum.value} + {trigger}. "
                f"Valid triggers from {current_enum.value}: "
                f"{[t for (s, t), _ in VALID_TRANSITIONS.items() if s == current_enum]}"
            )

        now_ms = int(time.time() * 1000)

        # Close the current state record
        if current is not None:
            current.exited_at_ms = now_ms
            self._session.add(current)

        # Create new state record
        new_record = KitchenStateRecord(
            state=next_state.value,
            entered_at_ms=now_ms,
            trigger_event_id=event_id,
            device_type=device_type,
            extra_metadata=json.dumps(metadata) if metadata else None,
        )
        self._session.add(new_record)
        await self._session.commit()
        await self._session.refresh(new_record)

        logger.info(
            "Kitchen FSM: %s -[%s]-> %s",
            current_enum.value,
            trigger,
            next_state.value,
        )
        return new_record

    async def ensure_initial_state(self) -> None:
        """Create the initial idle state if no state exists."""
        current = await self.get_current_state()
        if current is None:
            record = KitchenStateRecord(
                state=KitchenStateEnum.idle.value,
                entered_at_ms=int(time.time() * 1000),
            )
            self._session.add(record)
            await self._session.commit()

    async def get_history(
        self, from_ms: int | None = None, to_ms: int | None = None
    ) -> list[KitchenStateRecord]:
        """Get state transition history within a time range."""
        query = select(KitchenStateRecord).order_by(
            KitchenStateRecord.entered_at_ms.desc()
        )
        if from_ms is not None:
            query = query.where(KitchenStateRecord.entered_at_ms >= from_ms)
        if to_ms is not None:
            query = query.where(KitchenStateRecord.entered_at_ms <= to_ms)
        result = await self._session.execute(query)
        return list(result.scalars().all())
