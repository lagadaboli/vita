"""Tests for the normalization pipeline."""

import json

import pytest

from app.schemas.appliance import InstantPotRawEvent, RotimaticRawEvent
from app.schemas.meal import MealSource
from app.services.normalizer import (
    classify_instant_pot_method,
    normalize_instant_pot_event,
    normalize_raw_event,
    normalize_rotimatic_event,
)


class TestClassifyInstantPotMethod:
    def test_pressure_cook_long(self):
        assert classify_instant_pot_method("pressure_cook", 25) == "high_lectin_neutralization"

    def test_pressure_cook_medium(self):
        assert classify_instant_pot_method("pressure_cook", 15) == "moderate_lectin_neutralization"

    def test_pressure_cook_short(self):
        assert classify_instant_pot_method("pressure_cook", 5) == "moderate_lectin_neutralization"

    def test_slow_cook(self):
        assert classify_instant_pot_method("slow_cook", 120) == "baseline_lectin_retention"

    def test_saute(self):
        assert classify_instant_pot_method("saute", 10) == "fat_soluble_vitamin_enhancement"

    def test_steam(self):
        assert classify_instant_pot_method("steam", 15) == "water_soluble_vitamin_reduction"

    def test_yogurt(self):
        assert classify_instant_pot_method("yogurt", 480) == "probiotic_generation"

    def test_none_mode(self):
        assert classify_instant_pot_method(None, 10) is None

    def test_unknown_mode(self):
        assert classify_instant_pot_method("air_fry", 10) is None


class TestNormalizeRotimaticEvent:
    def test_basic_roti(self):
        event = RotimaticRawEvent(
            device_id="roti-001",
            timestamp_ms=1700000000000,
            flour_type="whole_wheat",
            roti_count=4,
            status="done",
        )
        result = normalize_rotimatic_event(event)
        assert result.source == MealSource.rotimatic_next
        assert result.confidence == 0.9
        assert len(result.ingredients) == 1
        assert result.ingredients[0].name == "whole_wheat flour roti"
        assert result.ingredients[0].quantity_grams == 120.0  # 4 * 30g
        assert result.ingredients[0].glycemic_index == 54.0
        # GL = (54 * 120 * 0.7) / 100 = 45.36
        assert result.estimated_glycemic_load == pytest.approx(45.36, abs=0.01)

    def test_multigrain_roti(self):
        event = RotimaticRawEvent(
            device_id="roti-001",
            timestamp_ms=1700000000000,
            flour_type="multigrain",
            roti_count=2,
        )
        result = normalize_rotimatic_event(event)
        assert result.ingredients[0].glycemic_index == 45.0
        # GL = (45 * 60 * 0.7) / 100 = 18.9
        assert result.estimated_glycemic_load == pytest.approx(18.9, abs=0.01)

    def test_no_flour_type(self):
        event = RotimaticRawEvent(
            device_id="roti-001",
            timestamp_ms=1700000000000,
        )
        result = normalize_rotimatic_event(event)
        assert result.ingredients == []
        assert result.estimated_glycemic_load is None


class TestNormalizeInstantPotEvent:
    def test_pressure_cook(self):
        event = InstantPotRawEvent(
            device_id="ip-001",
            timestamp_ms=1700000000000,
            mode="pressure_cook",
            duration_minutes=30,
            status="done",
        )
        result = normalize_instant_pot_event(event)
        assert result.source == MealSource.instant_pot
        assert result.cooking_method == "high_lectin_neutralization"
        assert result.bioavailability_modifier == 1.35
        assert result.confidence == 0.7

    def test_yogurt_mode(self):
        event = InstantPotRawEvent(
            device_id="ip-001",
            timestamp_ms=1700000000000,
            mode="yogurt",
            duration_minutes=480,
        )
        result = normalize_instant_pot_event(event)
        assert result.cooking_method == "probiotic_generation"
        assert result.bioavailability_modifier == 1.10


class TestNormalizeRawEvent:
    def test_rotimatic_raw(self):
        payload = json.dumps(
            {
                "device_id": "roti-001",
                "timestamp_ms": 1700000000000,
                "flour_type": "white",
                "roti_count": 3,
                "status": "done",
            }
        )
        result = normalize_raw_event("rotimatic_next", payload)
        assert result is not None
        assert result.source == MealSource.rotimatic_next
        # GL = (71 * 90 * 0.7) / 100 = 44.73
        assert result.estimated_glycemic_load == pytest.approx(44.73, abs=0.01)

    def test_instant_pot_raw(self):
        payload = json.dumps(
            {
                "device_id": "ip-001",
                "timestamp_ms": 1700000000000,
                "mode": "steam",
                "duration_minutes": 15,
                "status": "done",
            }
        )
        result = normalize_raw_event("instant_pot", payload)
        assert result is not None
        assert result.cooking_method == "water_soluble_vitamin_reduction"

    def test_unknown_device(self):
        result = normalize_raw_event("unknown_device", "{}")
        assert result is None

    def test_invalid_json(self):
        result = normalize_raw_event("rotimatic_next", "not json")
        assert result is None
