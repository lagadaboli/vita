"""Kitchen State FSM history records."""

from sqlalchemy import Column, ForeignKey, Integer, Text

from app.models.base import Base, PKMixin


class KitchenStateRecord(Base, PKMixin):
    __tablename__ = "kitchen_states"

    state = Column(Text, nullable=False)
    entered_at_ms = Column(Integer, nullable=False)
    exited_at_ms = Column(Integer, nullable=True)
    trigger_event_id = Column(
        Integer, ForeignKey("appliance_events.id"), nullable=True
    )
    device_type = Column(Text, nullable=True)
    extra_metadata = Column("metadata", Text, nullable=True)  # JSON
