"""Device registry and connectivity log."""

from sqlalchemy import Column, Integer, Text, UniqueConstraint

from app.models.base import Base, PKMixin


class DeviceConnection(Base, PKMixin):
    __tablename__ = "device_connections"

    device_type = Column(Text, nullable=False)
    device_id = Column(Text, nullable=False)
    ip_address = Column(Text, nullable=True)
    last_seen_ms = Column(Integer, nullable=True)
    status = Column(Text, nullable=False, default="discovered")
    consecutive_failures = Column(Integer, default=0)
    extra_metadata = Column("metadata", Text, nullable=True)  # JSON

    __table_args__ = (
        UniqueConstraint("device_type", "device_id", name="uq_device_type_id"),
    )
