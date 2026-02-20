# Health Score (Home Screen)

This document explains the current **home-screen Health Score** logic used by VITA.

Source of truth in code:
- `/Users/aditya/repos/hacks/vita/mobile-swift/VITA/ViewModels/DashboardViewModel.swift` (`computeHealthScore()`)

## What this score is

- A **heuristic weighted score**, not an ML model.
- Starts from a baseline of `100`.
- Adds penalties/bonuses from current health signals.
- Clamped to `[0, 100]`.

## Formula

Let:
- `G = currentGlucose` (mg/dL)
- `Hrv = currentHRV` (ms)
- `S = sleepHours`
- `D = dopamineDebt` (0-100)
- `Hr = currentHR` (bpm)
- `A = currentAQI`
- `WU = 1` if `weightTrend == .up`, else `0`

Then:

```text
score = 100

if G > 140: score -= (G - 140) * 0.5
if G < 70:  score -= (70 - G) * 0.8

if Hrv < 40: score -= (40 - Hrv) * 0.8
if Hrv > 60: score += min((Hrv - 60) * 0.3, 5)

if S < 7.0: score -= (7.0 - S) * 8

score -= D * 0.15

if Hr > 72: score -= (Hr - 72) * 0.5

if A > 100: score -= (A - 100) * 0.1

if WU == 1: score -= 3

healthScore = clamp(score, 0, 100)
```

## Heuristic intent by component

- **Glucose**
  - Penalizes hyperglycemia (`>140`) and hypoglycemia (`<70`).
  - Low glucose is penalized more steeply (`0.8`) than high glucose (`0.5`) per unit.

- **HRV**
  - Penalizes low HRV (`<40`) as stress/recovery concern.
  - Gives a capped bonus above `60` (max `+5`) for strong recovery state.

- **Sleep**
  - Penalizes sleep deficit below `7h` heavily (`8` points per missing hour).

- **Dopamine Debt**
  - Linear penalty from digital-behavior overload (`0.15` per debt point).

- **Heart Rate**
  - Penalizes elevated resting/current HR above `72 bpm`.

- **Air Quality (AQI)**
  - Penalizes only when AQI crosses `100`, with a lighter slope.

- **Weight Trend**
  - Fixed penalty (`-3`) if weight is currently trending up.

## Interpretation labels (UI)

From `/Users/aditya/repos/hacks/vita/mobile-swift/VITA/Views/Dashboard/HealthScoreGauge.swift`:

- `80...100`: **Excellent**
- `60..<80`: **Good**
- `40..<60`: **Fair**
- `<40`: **Needs Attention**

## Notes

- This is a product heuristic for readability and responsiveness, not a clinical diagnostic score.
- Coefficients/thresholds are hand-tuned and can be recalibrated as validation data grows.
