"""Discovered causal relationships between health/behavior nodes."""

from sqlalchemy import Column, Float, Integer, Text

from app.models.base import Base, PKMixin, TimestampMixin


class CausalEdge(Base, PKMixin, TimestampMixin):
    __tablename__ = "causal_edges_backend"

    source_node_id = Column(Text, nullable=False)  # e.g. "meal_42"
    target_node_id = Column(Text, nullable=False)  # e.g. "glucose_7"
    edge_type = Column(Text, nullable=False)  # matches Swift EdgeType
    causal_strength = Column(Float, default=0.0)
    temporal_offset_seconds = Column(Float, default=0.0)
    confidence = Column(Float, default=0.5)
