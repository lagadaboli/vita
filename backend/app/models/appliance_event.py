"""Raw appliance telemetry events."""

from sqlalchemy import Column, Index, Integer, Text

from app.models.base import Base, PKMixin, TimestampMixin


class ApplianceEvent(Base, PKMixin, TimestampMixin):
    __tablename__ = "appliance_events"

    device_type = Column(Text, nullable=False)
    device_id = Column(Text, nullable=False)
    timestamp_ms = Column(Integer, nullable=False)
    raw_payload = Column(Text, nullable=False)
    session_id = Column(Text, nullable=True)

    __table_args__ = (
        Index("idx_appliance_events_type_ts", "device_type", "timestamp_ms"),
        Index("idx_appliance_events_session", "session_id"),
    )
