"""Pydantic models for SMS escalation notifications."""

from datetime import datetime

from pydantic import BaseModel, Field


class EscalationRequest(BaseModel):
    """Incoming escalation request from iOS client."""

    symptom: str = Field(..., description="The symptom that triggered escalation")
    escalation_reason: str = Field(..., description="Narrative explaining why escalation is needed")
    confidence_score: float = Field(..., ge=0.0, le=1.0, description="HighPainClassifier composite score")
    phone_number_hash: str = Field(..., description="SHA-256 hash of device identifier (never plaintext)")
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class EscalationResponse(BaseModel):
    """Response after processing an escalation request."""

    status: str = Field(..., description="'sent', 'queued', or 'rejected'")
    message_sid: str | None = Field(None, description="Twilio message SID if sent")
    reason: str | None = Field(None, description="Rejection reason if applicable")
