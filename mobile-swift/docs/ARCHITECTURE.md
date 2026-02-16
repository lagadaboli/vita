# VITA — Personal Health Causality Engine

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        VITA Core Runtime                           │
│                    (On-Device / Local-First)                       │
│                                                                     │
│  ┌───────────────┐  ┌───────────────┐  ┌──────────────────────┐    │
│  │  Layer 1       │  │  Layer 2       │  │  Layer 3              │    │
│  │  Consumption   │  │  Physiological │  │  Intentionality       │    │
│  │  Bridge        │  │  Pulse         │  │  Tracker              │    │
│  └───────┬───────┘  └───────┬───────┘  └──────────┬───────────┘    │
│          │                  │                      │                │
│          ▼                  ▼                      ▼                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Unified Health Graph (SQLite + GRDB)            │   │
│  └─────────────────────────┬───────────────────────────────────┘   │
│                            │                                        │
│                            ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │         Causality Engine (CGNN + Counterfactual Gen)         │   │
│  └─────────────────────────┬───────────────────────────────────┘   │
│                            │                                        │
│                            ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Query Resolution Interface (NL → Causal)       │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │         Privacy Layer (Encrypted Embeddings / FHE Lite)     │   │
│  └─────────────────────────────────────────────────────────────┘   │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ (anonymized causality patterns only)
                               ▼
                ┌──────────────────────────┐
                │   Cloud Sync (Optional)   │
                │   Pattern Aggregation     │
                └──────────────────────────┘
```

---

## Layer 1: The Consumption Bridge (Input)

### 1A. Metabolic Ingestion Pipeline

**Problem:** Rotimatic NEXT and Instant Pot Pro Plus don't expose open APIs. They use proprietary cloud backends (Zimplistic and Instant Brands respectively).

**Architecture — User-Agent Proxy Pattern:**

```
┌──────────────┐     ┌───────────────────┐     ┌──────────────────┐
│ Smart Device  │────▶│  Device Cloud API  │────▶│  VITA User-Agent │
│ (Rotimatic /  │     │  (Zimplistic /     │     │  Proxy           │
│  Instant Pot) │     │   Instant Brands)  │     │                  │
└──────────────┘     └───────────────────┘     └────────┬─────────┘
                                                         │
                                                         ▼
                                               ┌──────────────────┐
                                               │ Ingredient Graph  │
                                               │ Normalizer        │
                                               └──────────────────┘
```

**Rotimatic NEXT Ingestion:**
- Intercept the Rotimatic mobile app's API traffic or use the Rotimatic's local network API (UDP broadcast discovery on port 5353, then REST calls to the device's local IP).
- The device exposes `/api/v1/session` with flour type, water ratio, oil ratio, and kneading duration.
- Normalize into a `MealEvent` schema with glycemic load calculations.

**Instant Pot Pro Plus Ingestion:**
- The Instant Pot Pro Plus connects via Bluetooth LE to the Instant Brands app. Capture BLE GATT characteristic writes (service UUID `0xFFE0`) for: program selected, pressure level (kPa), duration, and temperature curve.
- Map cooking programs to nutrient bioavailability modifiers:

| Program       | Pressure (kPa) | Bioavailability Modifier   |
|---------------|-----------------|----------------------------|
| Pressure Cook | 70-80           | +35% protein, -40% lectin  |
| Slow Cook     | 0               | baseline                   |
| Sauté         | 0               | +10% fat-soluble vitamin   |
| Steam         | 30-50           | -15% water-soluble vitamin |
| Yogurt        | 0               | +probiotic_generation      |

### 1B. Economic Ingestion — Virtual Receipt Parser

**Architecture — Authenticated Scraping Agent:**
1. User authenticates once via OAuth or stored session cookies (kept in the iOS Keychain).
2. A headless browser navigates to Instacart/DoorDash order pages on a daily schedule.
3. DOM parser extracts: item name, quantity, store, price, substitutions.
4. Each item is resolved against USDA FoodData Central and Open Food Facts for: macronutrients, micronutrients, allergens, additives, glycemic index.
5. Substitution tracking is critical for detecting gut sensitivity changes.

**Legal posture:** The system acts as the user's authorized agent under CFAA safe harbor for accessing one's own data.

---

## Layer 2: The Physiological Pulse (Signal)

### 2A. HealthKit Integration

**Sync Strategy:**

| Metric         | Priority | Sync Interval          |
|----------------|----------|------------------------|
| HRV (SDNN)     | CRITICAL | Every sample (~5 min)  |
| Resting HR     | CRITICAL | Hourly aggregate       |
| Sleep Stages   | CRITICAL | On wake event          |
| Blood Oxygen   | HIGH     | Every sample           |
| Resp Rate      | HIGH     | Nightly                |
| Active Energy  | MEDIUM   | 15-min buckets         |
| Step Count     | LOW      | Hourly                 |
| Workout Sessions| MEDIUM  | On completion          |

**Strategy:** `HKObserverQuery` (background delivery) for CRITICAL metrics. `HKStatisticsCollectionQuery` for aggregated metrics. Batch read on app foreground.

**Key design decision:** Use `HKAnchoredObjectQuery` (not `HKSampleQuery`) to get only new samples since last sync. This prevents redundant processing and keeps the on-device SQLite writes minimal.

### 2B. CGM as Metabolic Ground Truth

**Data Source:** Dexcom G7 or Libre 3 via their respective HealthKit integrations (both write `HKQuantityType.bloodGlucose` to HealthKit automatically).

**Signal Processing Pipeline:**

```
Raw CGM (every 5 min)
        │
        ▼
┌───────────────────┐
│ Glucose Curve      │    Detect: spike onset, peak, nadir, recovery
│ Feature Extractor  │    Output: GlucoseEvent { type, magnitude,
│                     │            duration, area_under_curve }
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│ Meal-Glucose       │    Temporal join: MealEvent ± 120min window
│ Correlator         │    Output: MealGlucoseResponse
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│ Energy State       │    Map glucose derivatives to energy states:
│ Classifier         │    STABLE | RISING | CRASHING | REACTIVE_LOW
└───────────────────┘
```

**The critical insight:** CGM data turns the Causality Engine from probabilistic to deterministic for metabolic questions.

---

## Layer 3: The Intentionality Tracker (Context)

### Behavioral Classification Engine

**Categories:**

- **ACTIVE_WORK**: IDE/Editor >10min, Docs/Research, Focus Mode ON, Calendar "Deep Work" block
- **PASSIVE_CONSUMPTION**: Social media, Short-form video, Rapid app-switch (>5 switches/min)
- **STRESS_SIGNAL**: Calendar density >6 meetings/day, Back-to-back meetings, Evening email

**Dopamine Debt Score (0-100):**

```
dopamine_debt = (
    0.4 * passive_screen_minutes_last_3h / 60 +
    0.3 * app_switch_frequency_zscore +
    0.2 * (1 - time_in_focus_mode_ratio) +
    0.1 * late_night_screen_penalty
) * 100
```

---

## The Causality Engine (CGNN)

### CGNN Model Architecture

1. **Input Layer**: Meal Embeddings, Glucose Curves, HRV Timeseries, Screen Behavior
2. **Temporal Graph Attention Network (TGAT)**: Learns edge weights = causal strength, time-decay attention, multi-hop reasoning
3. **Structural Causal Model (SCM) Layer**: do-calculus interventions, backdoor/frontdoor adjustment, confounding detection
4. **Counterfactual Generator**: "What if" simulations, intervention recommendations, confidence intervals

### Debt Detection Patterns

**Digestive Debt**: The delayed physiological cost of a meal that doesn't manifest immediately but compounds. Detected by correlating glycemic load, glucose spike/crash magnitude, HRV suppression, cooking method modifiers, and meal timing.

**Dopamine Debt**: Behavioral cost of passive consumption patterns that correlate with cognitive fog.

### Counterfactual Generation

Simulates alternate realities by modifying one variable at a time through the SCM layer:
- Cooking method interventions (e.g., pressure cook vs slow cook)
- Ingredient swap interventions (e.g., white flour → whole wheat)
- Timing interventions (e.g., eating 2 hours earlier)

### Cold Start Strategy

1. **Week 1-2:** Passive collection only. Build the Health Graph. No causal claims.
2. **Week 3-4:** Begin correlation detection. Surface patterns.
3. **Week 5-8:** Begin causal structure learning using PC algorithm. Tentative counterfactuals.
4. **Week 9+:** Active learning — VITA suggests small experiments to generate interventional data.

---

## Privacy & Legal Architecture

### Local-First, Cloud-Assisted Model

All raw ingredient and health data is processed on-device. Only anonymized "Causality Patterns" are synced to the cloud:

```json
{
  "pattern": "high_GL_meal → glucose_spike_L → hrv_suppression → fatigue_report",
  "strength": 0.83,
  "n_observations": 12,
  "demographic_bucket": "30s_south_asian"
}
```

No timestamps, no food names, no glucose values, no PII.

**Cloud sync**: TLS 1.3 + Certificate Pinning. Federated pattern library with differential privacy (ε = 1.0, δ = 10⁻⁵).

### Legal Posture — User-Agent Doctrine

| Risk Vector | Mitigation |
|---|---|
| **CFAA** | User explicitly authorizes VITA as their agent. System uses user's own credentials. |
| **HIPAA** | VITA is a personal tool, not a covered entity. No PHI leaves the device. |
| **Apple HealthKit Guidelines** | No health data transmitted to third parties. Cloud contains only abstract patterns. |
| **GDPR/CCPA** | User is both data controller and data subject. Local-first = no data processor relationship. |

---

## Tech Stack

| Component | Technology | Rationale |
|---|---|---|
| On-device DB | SQLite + GRDB (Swift) | HealthKit-native, no server dependency |
| ML runtime | CoreML + MLX | Apple silicon optimized, on-device inference |
| GNN framework | PyTorch Geometric → CoreML export | Train on Mac, deploy on iPhone |
| Credential storage | iOS Keychain | OS-level encryption for API tokens |
| Cloud sync | CloudKit (private database) | Apple-native, E2E encrypted option |

---

## Target Output Example

*"Your 9pm Rotimatic rotis (white flour, GL 33) caused a glucose spike to 168 then crash to 74. Your HRV dropped 22% overnight. If you'd used whole wheat and eaten at 7pm, your deep sleep would likely improve by ~25 minutes."*
