"""Health events persisted from mobile push (glucose, HRV, heart rate, etc.)."""

from sqlalchemy import Column, Float, Index, Integer, Text

from app.models.base import Base, PKMixin, TimestampMixin


class HealthEvent(Base, PKMixin, TimestampMixin):
    __tablename__ = "health_events"

    event_type = Column(Text, nullable=False)  # glucose / hrv / heartRate / sleep / screenTime
    timestamp_ms = Column(Integer, nullable=False)
    value = Column(Float, nullable=False)
    unit = Column(Text, nullable=True)  # mg/dL, ms, bpm
    metadata_json = Column(Text, nullable=True)  # JSON blob
    processed = Column(Integer, default=0)  # 0=pending, 1=ingested

    __table_args__ = (
        Index("idx_health_events_type_ts", "event_type", "timestamp_ms"),
        Index("idx_health_events_processed", "processed"),
    )
