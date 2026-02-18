"""FastAPI router for SMS escalation notifications."""

import logging

from fastapi import APIRouter, HTTPException

from app.schemas.notifications import EscalationRequest, EscalationResponse
from app.services.twilio_service import twilio_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.post("/escalate", response_model=EscalationResponse)
async def escalate(request: EscalationRequest) -> EscalationResponse:
    """Receive an escalation request from the iOS client and send SMS via Twilio.

    Only fires when HighPainClassifier score >= 0.75 (enforced client-side,
    validated here as a defense-in-depth check).
    """
    # Defense-in-depth: reject low-confidence escalations
    if request.confidence_score < 0.75:
        return EscalationResponse(
            status="rejected",
            reason=f"Confidence {request.confidence_score:.2f} below threshold 0.75",
        )

    logger.info(
        f"Escalation received: symptom={request.symptom}, "
        f"confidence={request.confidence_score:.2f}, "
        f"hash={request.phone_number_hash[:8]}..."
    )

    result = await twilio_service.send_escalation_sms(
        symptom=request.symptom,
        reason=request.escalation_reason,
        confidence=request.confidence_score,
    )

    return EscalationResponse(
        status=result["status"],
        message_sid=result.get("message_sid"),
        reason=result.get("reason"),
    )
