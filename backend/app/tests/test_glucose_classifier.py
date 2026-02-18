"""Tests for glucose trend and energy state classification."""

import pytest

from app.services.causal.glucose_classifier import (
    EnergyState,
    GlucoseTrend,
    classify_energy_state,
    classify_trend,
)


class TestClassifyTrend:
    def test_rapidly_rising(self):
        assert classify_trend(3.5) == GlucoseTrend.rapidly_rising
        assert classify_trend(10.0) == GlucoseTrend.rapidly_rising

    def test_rising_boundary(self):
        """Rate of 1.0 is on the rising boundary (mirrors Swift)."""
        assert classify_trend(1.0) == GlucoseTrend.rising
        assert classify_trend(2.5) == GlucoseTrend.rising

    def test_rising_upper_boundary(self):
        """Rate of exactly 3.0 is still rising, not rapidly rising."""
        assert classify_trend(3.0) == GlucoseTrend.rising

    def test_stable(self):
        assert classify_trend(0.0) == GlucoseTrend.stable
        assert classify_trend(0.5) == GlucoseTrend.stable
        assert classify_trend(-0.5) == GlucoseTrend.stable
        assert classify_trend(0.99) == GlucoseTrend.stable

    def test_falling_boundary(self):
        """Rate of -1.0 is falling."""
        assert classify_trend(-1.0) == GlucoseTrend.falling
        assert classify_trend(-2.5) == GlucoseTrend.falling

    def test_falling_lower_boundary(self):
        """Rate of exactly -3.0 is still falling, not rapidly falling."""
        assert classify_trend(-3.0) == GlucoseTrend.falling

    def test_rapidly_falling(self):
        assert classify_trend(-3.5) == GlucoseTrend.rapidly_falling
        assert classify_trend(-10.0) == GlucoseTrend.rapidly_falling


class TestClassifyEnergyState:
    def test_stable(self):
        assert classify_energy_state(95.0, 0.0) == EnergyState.stable
        assert classify_energy_state(100.0, 10.0) == EnergyState.stable

    def test_rising_high_glucose(self):
        """Current > 140 → rising."""
        assert classify_energy_state(145.0, 10.0) == EnergyState.rising

    def test_rising_delta_from_peak(self):
        """Delta from peak > 20 → rising (even if current < 140)."""
        assert classify_energy_state(130.0, 25.0) == EnergyState.rising

    def test_crashing(self):
        """Delta from peak < -30 → crashing."""
        assert classify_energy_state(100.0, -35.0) == EnergyState.crashing

    def test_reactive_low(self):
        """Below (baseline - 10) AND delta < -30 → reactiveLow."""
        assert classify_energy_state(75.0, -40.0) == EnergyState.reactive_low

    def test_reactive_low_custom_baseline(self):
        """Custom baseline: below (baseline - 10) AND delta < -30."""
        assert classify_energy_state(85.0, -35.0, baseline_mg_dl=100.0) == EnergyState.reactive_low

    def test_crashing_not_reactive_low(self):
        """Delta < -30 but above baseline → crashing, not reactiveLow."""
        assert classify_energy_state(85.0, -35.0, baseline_mg_dl=90.0) == EnergyState.crashing

    def test_boundary_140(self):
        """Exactly 140 is stable (condition is > 140)."""
        assert classify_energy_state(140.0, 0.0) == EnergyState.stable

    def test_boundary_delta_20(self):
        """Exactly 20 is stable (condition is > 20)."""
        assert classify_energy_state(100.0, 20.0) == EnergyState.stable
