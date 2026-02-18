"""Causal engine API schemas."""

from __future__ import annotations

from pydantic import BaseModel, Field


class SymptomQuery(BaseModel):
    """Request body for POST /causal/query."""

    symptom: str = Field(..., description="Symptom to investigate, e.g. 'fatigue', 'brain fog'")


class CausalChainLink(BaseModel):
    """A single link in the causal chain."""

    from_node: str = Field(..., alias="from")
    to_node: str = Field(..., alias="to")
    edge: str

    model_config = {"populate_by_name": True}


class CausalExplanationResponse(BaseModel):
    """Response from the causal agent query."""

    symptom: str
    conclusion: str | None = None
    confidence: float
    causal_chain: list[CausalChainLink]
    narrative: str
    metabolic_debt: float | None = None
    digital_debt: float | None = None
    counterfactuals: list[str] = Field(default_factory=list)
    safety_bypass: bool = False
    escalation_triggered: bool = False


class DebtScoreResponse(BaseModel):
    """Response for GET /causal/debt."""

    metabolic_debt: float = Field(..., description="Metabolic debt score 0-100")
    digital_debt: float = Field(..., description="Digital debt score 0-100")
    window_hours: int


class GlucoseCurrentResponse(BaseModel):
    """Response for GET /causal/glucose/current."""

    value_mg_dl: float | None = None
    trend: str | None = None
    rate_mg_per_min: float | None = None
    energy_state: str | None = None
    timestamp_ms: int | None = None


class TraceResponse(BaseModel):
    """A reasoning trace summary."""

    id: int
    symptom: str
    phase: str
    conclusion: str | None = None
    confidence: float | None = None
    narrative: str | None = None
    duration_ms: int | None = None
    created_at: str | None = None


class TraceDetailResponse(TraceResponse):
    """Full reasoning trace with JSON fields."""

    hypotheses_json: str | None = None
    observations_json: str | None = None
    causal_chain_json: str | None = None


class CounterfactualRequest(BaseModel):
    """Request body for POST /causal/counterfactual."""

    node_id: str = Field(..., description="Node ID to generate counterfactuals for")


class CounterfactualResponse(BaseModel):
    """Response from counterfactual generation."""

    node_id: str
    counterfactuals: list[str]
