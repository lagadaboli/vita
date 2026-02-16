"""Tests for the Kitchen State FSM."""

import pytest
import pytest_asyncio

from app.schemas.kitchen import KitchenStateEnum
from app.services.kitchen_fsm import KitchenFSM


@pytest.mark.asyncio
class TestKitchenFSM:
    async def test_initial_state_is_idle(self, db_session):
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()
        state = await fsm.get_current_state_enum()
        assert state == KitchenStateEnum.idle

    async def test_idle_to_cooking(self, db_session):
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()
        record = await fsm.transition("appliance_start", device_type="rotimatic_next")
        assert record.state == "cooking"

    async def test_cooking_to_meal_ready(self, db_session):
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()
        await fsm.transition("appliance_start")
        record = await fsm.transition("appliance_stop")
        assert record.state == "meal_ready"

    async def test_meal_ready_to_consumed(self, db_session):
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()
        await fsm.transition("appliance_start")
        await fsm.transition("appliance_stop")
        record = await fsm.transition("manual_confirm")
        assert record.state == "meal_consumed"

    async def test_meal_consumed_auto_reset(self, db_session):
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()
        await fsm.transition("appliance_start")
        await fsm.transition("appliance_stop")
        await fsm.transition("manual_confirm")
        record = await fsm.transition("auto_reset")
        assert record.state == "idle"

    async def test_full_cycle(self, db_session):
        """Test the complete FSM cycle: idle → cooking → meal_ready → meal_consumed → idle."""
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()

        assert await fsm.get_current_state_enum() == KitchenStateEnum.idle
        await fsm.transition("appliance_start")
        assert await fsm.get_current_state_enum() == KitchenStateEnum.cooking
        await fsm.transition("appliance_stop")
        assert await fsm.get_current_state_enum() == KitchenStateEnum.meal_ready
        await fsm.transition("glucose_spike_detected")
        assert await fsm.get_current_state_enum() == KitchenStateEnum.meal_consumed
        await fsm.transition("auto_reset")
        assert await fsm.get_current_state_enum() == KitchenStateEnum.idle

    async def test_invalid_transition_raises(self, db_session):
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()
        with pytest.raises(ValueError, match="Invalid transition"):
            await fsm.transition("appliance_stop")  # Can't stop from idle

    async def test_cooking_timeout_to_idle(self, db_session):
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()
        await fsm.transition("appliance_start")
        record = await fsm.transition("timeout")
        assert record.state == "idle"

    async def test_meal_ready_timeout_to_idle(self, db_session):
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()
        await fsm.transition("appliance_start")
        await fsm.transition("appliance_stop")
        record = await fsm.transition("timeout")
        assert record.state == "idle"

    async def test_history_records(self, db_session):
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()
        await fsm.transition("appliance_start")
        await fsm.transition("appliance_stop")
        history = await fsm.get_history()
        assert len(history) >= 3  # idle, cooking, meal_ready

    async def test_previous_state_gets_exit_time(self, db_session):
        fsm = KitchenFSM(db_session)
        await fsm.ensure_initial_state()
        await fsm.transition("appliance_start")

        history = await fsm.get_history()
        # The initial idle state should now have an exit time
        idle_records = [h for h in history if h.state == "idle"]
        assert len(idle_records) == 1
        assert idle_records[0].exited_at_ms is not None
