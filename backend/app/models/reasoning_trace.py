"""Agent reasoning transparency logs — mirrors Swift v3 schema."""

from sqlalchemy import Column, Float, Integer, Text

from app.models.base import Base, PKMixin, TimestampMixin


class ReasoningTrace(Base, PKMixin, TimestampMixin):
    __tablename__ = "reasoning_traces"

    symptom = Column(Text, nullable=False)
    phase = Column(Text, nullable=False)  # pulse / hypothesis / probe / inference
    hypotheses_json = Column(Text, nullable=False)  # JSON array
    observations_json = Column(Text, nullable=False)  # JSON array
    conclusion = Column(Text, nullable=True)  # metabolic / digital / null
    confidence = Column(Float, nullable=True)
    duration_ms = Column(Integer, nullable=True)
    causal_chain_json = Column(Text, nullable=True)  # JSON array of edge IDs
    narrative = Column(Text, nullable=True)
