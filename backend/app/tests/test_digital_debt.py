"""Tests for DigitalDebtScorer — verifies exact Swift formula alignment."""

import pytest

from app.services.causal.digital_debt import (
    GlucoseCrash,
    ScreenEvent,
    compute_digital_debt,
    compute_dopamine_debt,
)


class TestComputeDopamineDebt:
    def test_all_zero(self):
        score = compute_dopamine_debt(0.0, 0.0, 1.0, 0.0)
        assert score == 0.0

    def test_max_passive(self):
        """60 min passive → passive_norm = 1.0 → 40 points."""
        score = compute_dopamine_debt(60.0, 0.0, 1.0, 0.0)
        assert pytest.approx(score, abs=0.1) == 40.0

    def test_max_switch_freq(self):
        """z-score ≥ 1.0 → switch_norm = 1.0 → 30 points."""
        score = compute_dopamine_debt(0.0, 1.5, 1.0, 0.0)
        assert pytest.approx(score, abs=0.1) == 30.0

    def test_no_focus_mode(self):
        """focus_ratio = 0 → (1-0)*0.2 → 20 points."""
        score = compute_dopamine_debt(0.0, 0.0, 0.0, 0.0)
        assert pytest.approx(score, abs=0.1) == 20.0

    def test_late_night(self):
        """late_night = 1.0 → 10 points."""
        score = compute_dopamine_debt(0.0, 0.0, 1.0, 1.0)
        assert pytest.approx(score, abs=0.1) == 10.0

    def test_full_max(self):
        """All maxed out → 100 points."""
        score = compute_dopamine_debt(60.0, 1.0, 0.0, 1.0)
        assert pytest.approx(score, abs=0.1) == 100.0

    def test_clamped_to_100(self):
        """Even extreme inputs should not exceed 100."""
        score = compute_dopamine_debt(999.0, 999.0, -999.0, 999.0)
        assert score <= 100.0

    def test_clamped_to_0(self):
        """Negative inputs should not produce negative scores."""
        score = compute_dopamine_debt(-10.0, -10.0, 2.0, -10.0)
        assert score >= 0.0

    def test_negative_z_score_clamped(self):
        """Negative z-score clamped to 0."""
        score = compute_dopamine_debt(0.0, -2.0, 1.0, 0.0)
        assert score >= 0.0


class TestComputeDigitalDebt:
    def test_empty(self):
        assert compute_digital_debt([]) == 0.0

    def test_screen_time_only(self):
        """60 minutes of screen time → screenTimeFactor = 60."""
        events = [ScreenEvent(start_ms=1000, duration_seconds=3600, dopamine_debt_score=0.0)]
        score = compute_digital_debt(events)
        assert pytest.approx(score, abs=0.1) == 60.0

    def test_screen_time_capped_at_60(self):
        """More than 60 min still caps screen factor at 60."""
        events = [ScreenEvent(start_ms=1000, duration_seconds=7200, dopamine_debt_score=0.0)]
        score = compute_digital_debt(events)
        assert pytest.approx(score, abs=0.1) == 60.0

    def test_dopamine_factor(self):
        """Max dopamine debt contributes up to 40 points."""
        events = [ScreenEvent(start_ms=1000, duration_seconds=0, dopamine_debt_score=100.0)]
        score = compute_digital_debt(events)
        # screenTime=0, dopamine=100*0.4=40
        assert pytest.approx(score, abs=0.1) == 40.0

    def test_combined_max(self):
        """Screen + dopamine capped at 100."""
        events = [
            ScreenEvent(start_ms=1000, duration_seconds=7200, dopamine_debt_score=100.0)
        ]
        score = compute_digital_debt(events)
        # screen=60 + dopamine=40 = 100
        assert pytest.approx(score, abs=0.1) == 100.0

    def test_reactive_scrolling_excluded(self):
        """Scrolling within 30min of a glucose crash is excluded from genuine minutes."""
        crash_time_ms = 1_000_000
        events = [
            ScreenEvent(
                start_ms=crash_time_ms + 10 * 60 * 1000,  # 10 min after crash
                duration_seconds=3600,  # 60 min
                dopamine_debt_score=0.0,
            )
        ]
        crashes = [GlucoseCrash(timestamp_ms=crash_time_ms)]

        score = compute_digital_debt(events, crashes)
        # This event is reactive → excluded → genuine = 0 → score = 0
        assert score == 0.0

    def test_non_reactive_not_excluded(self):
        """Scrolling >30min after crash is NOT reactive."""
        crash_time_ms = 1_000_000
        events = [
            ScreenEvent(
                start_ms=crash_time_ms + 31 * 60 * 1000,  # 31 min after crash
                duration_seconds=3600,
                dopamine_debt_score=0.0,
            )
        ]
        crashes = [GlucoseCrash(timestamp_ms=crash_time_ms)]

        score = compute_digital_debt(events, crashes)
        assert score > 0.0

    def test_multiple_events_mixed(self):
        """Mix of reactive and genuine events."""
        crash_time_ms = 1_000_000
        events = [
            ScreenEvent(
                start_ms=crash_time_ms + 5 * 60 * 1000,  # reactive
                duration_seconds=1800,
                dopamine_debt_score=50.0,
            ),
            ScreenEvent(
                start_ms=crash_time_ms + 60 * 60 * 1000,  # genuine
                duration_seconds=1800,  # 30 min
                dopamine_debt_score=30.0,
            ),
        ]
        crashes = [GlucoseCrash(timestamp_ms=crash_time_ms)]

        score = compute_digital_debt(events, crashes)
        # Genuine: 30 min → screenFactor = 0.5 * 60 = 30
        # Max dopamine: 50 (from reactive event — max across ALL events)
        # dopamineFactor = 50 * 0.4 = 20
        # Total: 30 + 20 = 50
        assert pytest.approx(score, abs=0.1) == 50.0

    def test_no_crashes_all_genuine(self):
        """Without crash data, all events are genuine."""
        events = [
            ScreenEvent(start_ms=1000, duration_seconds=1800, dopamine_debt_score=0.0),
            ScreenEvent(start_ms=2000, duration_seconds=1800, dopamine_debt_score=0.0),
        ]
        score = compute_digital_debt(events)
        # 60 min genuine → screen = 60
        assert pytest.approx(score, abs=0.1) == 60.0
