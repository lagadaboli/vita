"""Tests for safety, privacy, and hallucination guardrails."""

import pytest

from app.services.causal.guardrails import (
    SafetyCheckResult,
    apply_hallucination_guard,
    check_hrv_safety,
    sanitize_for_sms,
)
from app.services.causal.mcp_adapters import MCPToolResult


class TestHRVSafety:
    def test_low_hrv_triggers_bypass(self):
        result = check_hrv_safety({"hrv_ms": 15.0})
        assert result.is_safe is False
        assert result.hrv_value == 15.0
        assert result.escalation_reason is not None

    def test_very_low_hrv(self):
        result = check_hrv_safety({"hrv_ms": 5.0})
        assert result.is_safe is False

    def test_boundary_20(self):
        """Exactly 20 is safe (threshold is < 20)."""
        result = check_hrv_safety({"hrv_ms": 20.0})
        assert result.is_safe is True

    def test_normal_hrv(self):
        result = check_hrv_safety({"hrv_ms": 55.0})
        assert result.is_safe is True
        assert result.hrv_value == 55.0

    def test_no_data(self):
        """No data → safe (can't determine danger)."""
        result = check_hrv_safety(None)
        assert result.is_safe is True
        assert result.hrv_value is None

    def test_no_hrv_key(self):
        """Data dict without hrv_ms → safe."""
        result = check_hrv_safety({"heart_rate_bpm": 72.0})
        assert result.is_safe is True
        assert result.hrv_value is None


class TestHallucinationGuard:
    def test_all_data_present(self):
        results = {
            "apple_health": MCPToolResult(data={"hrv_ms": 50}, source="apple_health"),
            "cgm_stelo": MCPToolResult(data={"value": 120}, source="cgm_stelo"),
        }
        excluded = apply_hallucination_guard(results)
        assert len(excluded) == 0

    def test_one_missing(self):
        results = {
            "apple_health": MCPToolResult(data=None, source="apple_health"),
            "cgm_stelo": MCPToolResult(data={"value": 120}, source="cgm_stelo"),
        }
        excluded = apply_hallucination_guard(results)
        assert excluded == {"apple_health"}

    def test_all_missing(self):
        results = {
            "apple_health": MCPToolResult(data=None, source="apple_health"),
            "rotimatic_server": MCPToolResult(data=None, source="rotimatic_server"),
        }
        excluded = apply_hallucination_guard(results)
        assert excluded == {"apple_health", "rotimatic_server"}


class TestSanitizeForSMS:
    def test_basic_message(self):
        msg = sanitize_for_sms("fatigue", "metabolic", 0.85)
        assert "VITA Health Alert" in msg
        assert "fatigue" in msg
        assert "dietary pattern" in msg
        assert "85%" in msg

    def test_no_raw_values(self):
        """Should NOT contain raw glucose values, timestamps, or food names."""
        msg = sanitize_for_sms("brain fog", "metabolic", 0.9)
        assert "mg/dL" not in msg
        assert "145" not in msg
        assert "roti" not in msg.lower()

    def test_digital_conclusion(self):
        msg = sanitize_for_sms("anxiety", "digital", 0.7)
        assert "screen behavior" in msg

    def test_no_conclusion(self):
        msg = sanitize_for_sms("dizziness", None, 1.0)
        assert "VITA Health Alert" in msg
        assert "Likely cause" not in msg

    def test_under_320_chars(self):
        """SMS should fit in 2 SMS segments max."""
        msg = sanitize_for_sms("fatigue", "metabolic", 0.85)
        assert len(msg) <= 320

    def test_open_vita_prompt(self):
        msg = sanitize_for_sms("fatigue", "metabolic", 0.85)
        assert "Open VITA" in msg
