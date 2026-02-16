"""Normalized meal events — mirrors Swift MealEvent."""

from sqlalchemy import Column, Float, ForeignKey, Index, Integer, Text

from app.models.base import Base, PKMixin, TimestampMixin


class MealEvent(Base, PKMixin, TimestampMixin):
    __tablename__ = "meal_events"

    timestamp_ms = Column(Integer, nullable=False)
    source = Column(Text, nullable=False)
    event_type = Column(Text, nullable=False)
    ingredients = Column(Text, nullable=False)  # JSON array
    cooking_method = Column(Text, nullable=True)
    estimated_glycemic_load = Column(Float, nullable=True)
    bioavailability_modifier = Column(Float, nullable=True)
    confidence = Column(Float, default=0.5)
    kitchen_state_id = Column(Integer, ForeignKey("kitchen_states.id"), nullable=True)
    appliance_event_id = Column(
        Integer, ForeignKey("appliance_events.id"), nullable=True
    )
    synced_to_mobile = Column(Integer, default=0)

    __table_args__ = (Index("idx_meal_events_ts", "timestamp_ms"),)
