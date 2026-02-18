"""Twilio REST client wrapper for SMS escalation."""

import logging

from app.config import settings

logger = logging.getLogger(__name__)


class TwilioService:
    """Sends SMS notifications via Twilio REST API."""

    def __init__(self):
        self.account_sid = settings.twilio_account_sid
        self.auth_token = settings.twilio_auth_token
        self.from_number = settings.twilio_from_number
        self.to_number = settings.twilio_escalation_to_number
        self._client = None

    @property
    def is_configured(self) -> bool:
        return bool(self.account_sid and self.auth_token and self.from_number and self.to_number)

    @property
    def client(self):
        if self._client is None:
            try:
                from twilio.rest import Client
                self._client = Client(self.account_sid, self.auth_token)
            except ImportError:
                logger.warning("twilio package not installed — SMS escalation disabled")
                return None
        return self._client

    async def send_escalation_sms(
        self,
        symptom: str,
        reason: str,
        confidence: float,
    ) -> dict:
        """Send an escalation SMS. Returns {'status': ..., 'message_sid': ...}."""
        if not self.is_configured:
            logger.warning("Twilio not configured — skipping SMS escalation")
            return {"status": "rejected", "message_sid": None, "reason": "Twilio not configured"}

        if self.client is None:
            return {"status": "rejected", "message_sid": None, "reason": "Twilio client unavailable"}

        body = (
            f"VITA Health Alert\n\n"
            f"Symptom: {symptom}\n"
            f"Confidence: {confidence:.0%}\n"
            f"Reason: {reason[:200]}\n\n"
            f"Open VITA for full details."
        )

        try:
            message = self.client.messages.create(
                body=body,
                from_=self.from_number,
                to=self.to_number,
            )

            logger.info(f"Escalation SMS sent: {message.sid}")
            return {"status": "sent", "message_sid": message.sid}

        except Exception as e:
            logger.error(f"Twilio send failed: {e}")
            return {"status": "rejected", "message_sid": None, "reason": str(e)}


twilio_service = TwilioService()
