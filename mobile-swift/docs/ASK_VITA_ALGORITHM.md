# Ask VITA — Query Resolution Algorithm

> **"Why am I tired?"** → causal chain → counterfactuals → provider-ready PDF

This document describes the complete algorithmic pipeline that powers the Ask VITA
interface: from a free-text natural-language question to a ranked, confidence-scored
set of causal explanations and actionable interventions.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Phase 0: Query Pre-processing](#2-phase-0-query-pre-processing)
3. [Phase 1: Health Context Window](#3-phase-1-health-context-window)
4. [Phase 2: DAG Construction](#4-phase-2-dag-construction)
5. [Phase 3: ReAct Reasoning Loop](#5-phase-3-react-reasoning-loop)
6. [Phase 4: Hypothesis Ranking](#6-phase-4-hypothesis-ranking)
7. [Phase 5: Counterfactual Generation](#7-phase-5-counterfactual-generation)
8. [Phase 6: Narrative Generation](#8-phase-6-narrative-generation)
9. [Phase 7: Escalation Check](#9-phase-7-escalation-check)
10. [Phase 8: Clinical PDF Pipeline](#10-phase-8-clinical-pdf-pipeline)
11. [Maturity Tiers](#11-maturity-tiers)
12. [Data Sources](#12-data-sources)
13. [Complexity Analysis](#13-complexity-analysis)

---

## 1. System Overview

```
User Query (NL)
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Ask VITA Pipeline                           │
│                                                                 │
│  [0] Query Pre-processing                                       │
│       └─ Trim, classify intent, identify symptom type          │
│                                                                 │
│  [1] Health Context Window (6h default)                        │
│       └─ Glucose readings, meals, HRV, sleep, behavior, env    │
│                                                                 │
│  [2] DAG Construction                                           │
│       └─ Build adjacency graph from persisted HealthGraphEdges  │
│       └─ Filter by CausalDirection validity rules               │
│                                                                 │
│  [3] ReAct Reasoning Loop (≤3 iterations)                      │
│       Thought → Act → Observe → Update                         │
│       └─ Tier A: Bio-Rule Engine (deterministic, always runs)   │
│       └─ Tier B: ReAct + ToolRegistry (Week 5+)                │
│                                                                 │
│  [4] Hypothesis Ranking (Bayesian update)                       │
│       └─ Debt classifier: Metabolic | Digital | Somatic         │
│                                                                 │
│  [5] Counterfactual Generation (SCM do-calculus)               │
│       └─ Intervention simulations via InterventionCalculator    │
│                                                                 │
│  [6] Narrative Generation                                       │
│       └─ Tier A: Template, Tier C: Local LLM (Week 9+)         │
│                                                                 │
│  [7] Escalation Check (Tier 4)                                  │
│       └─ HighPainClassifier → SMS if score ≥ 0.75              │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼
CausalExplanation[] + Counterfactual[] → UI + PDF
```

---

## 2. Phase 0: Query Pre-processing

```
Input:  raw_text = "Why am I so tired after dinner?"
Output: symptom_string (canonicalized)
```

**Steps:**

1. **Trim whitespace** — remove leading/trailing whitespace and newlines.
2. **Guard empty** — reject empty strings without running the pipeline.
3. **Pass-through** — the symptom string is forwarded verbatim to the
   `CausalityEngine.querySymptom(_:)` entry point. Intent classification
   (fatigue, focus, digestion, sleep, mood) is performed inside the rule engine
   and hypothesis generator by pattern matching against known symptom keywords.

```
Symptom keyword mapping (partial):
  "tired" | "fatigue" | "exhausted"  → DebtType.metabolic (high prior)
  "focus" | "brain fog" | "distracted" → DebtType.digital (high prior)
  "stomach" | "bloat" | "indigestion"  → DebtType.metabolic (gut branch)
  "sleep" | "insomnia" | "waking"      → DebtType.somatic (high prior)
  "anxious" | "stressed" | "heart"     → DebtType.somatic
```

---

## 3. Phase 1: Health Context Window

The analysis window defaults to **6 hours ending now** (covers post-meal
glucose curves and same-day behavioral events).

```swift
let window = Date().addingTimeInterval(-6 * 3_600)...Date()
```

**Data pulled from HealthGraph (SQLite / GRDB):**

| Stream | Type | Purpose |
|--------|------|---------|
| Glucose readings | `[GlucoseReading]` | Detect crash / spike / reactive-low |
| Meal events | `[MealEvent]` | Glycemic load, cooking method, source |
| Behavioral events | `[BehavioralEvent]` | Passive screen time, dopamine debt |
| Environmental | `[EnvironmentalCondition]` | AQI, pollen, temperature |
| HRV (SDNN) | `[PhysiologicalSample]` | Autonomic nervous system state |
| Sleep | `[PhysiologicalSample]` | Sleep debt, fragmentation |

**Make data sources embedded in MealEvent:**

| Source | Data captured |
|--------|--------------|
| Rotimatic NEXT | Flour type, water ratio, oil ratio → GL estimate |
| Instant Pot Pro Plus | Cooking program, pressure, duration → bioavailability modifier |
| Instacart / DoorDash | Item name → USDA FoodData resolution → macros, GI |
| Manual entry | Free-text ingredient list |

Each `MealEvent` carries a `bioavailabilityModifier` that adjusts the base
glycemic index for the cooking method:

```
Pressure Cook: GL × 0.72   (−28% lectin, +35% protein bioavailability)
Slow Cook:     GL × 1.00   (baseline)
Sauté:         GL × 1.05   (+fat-soluble vitamin absorption)
Steam:         GL × 0.90   (−water-soluble vitamin loss)
```

---

## 4. Phase 2: DAG Construction

The **Causal DAG** is an in-memory directed acyclic graph built from persisted
`HealthGraphEdge` rows. It enforces valid causal directions and prevents cycles.

### Node Types

```
physiological  → glucose → symptom
meal           → glucose → symptom
meal           → physiological → symptom
behavioral     → physiological → symptom
environmental  → physiological → symptom
```

### DAG Build Algorithm

```
Algorithm: BuildCausalDAG(edges: [HealthGraphEdge]) → adjacency_map
─────────────────────────────────────────────────────────────────
For each edge e in edges:
  1. Infer sourceType from e.sourceNodeID prefix
       "physio_*"      → .physiological
       "glucose_*"     → .glucose
       "meal_*"        → .meal
       "behavioral_*"  → .behavioral
       "environment_*" → .environmental
       "symptom_*"     → .symptom
  2. Infer targetType from e.targetNodeID (same prefix logic)
  3. Guard: CausalDirection.isValid(from: sourceType, to: targetType)
       Reject invalid directions (e.g., symptom → meal)
  4. Append DAG.Edge(target: targetType, edgeType: e.edgeType,
                      weight: e.causalStrength)
     to adjacency[sourceType]
Return adjacency_map
```

### Path Tracing (DFS)

```
Algorithm: TracePaths(source: NodeType) → [[NodeType]]
─────────────────────────────────────────────────────
currentPath = [source]
allPaths    = []

DFS(current, target=.symptom):
  if current == target AND len(currentPath) > 1:
    allPaths.append(copy of currentPath)
    return
  for each edge in adjacency[current]:
    if edge.target NOT in currentPath:  // cycle guard
      currentPath.append(edge.target)
      DFS(edge.target, target)
      currentPath.removeLast()

return allPaths
```

### Path Strength

Path strength is the **product of edge weights** along the path:

```
PathStrength(path) = Π weight(path[i] → path[i+1])  for i in 0..<(n-1)
```

Weights are learned and updated by `EdgeWeightLearner.batchUpdate()` over a
24-hour window using Pearson correlation of temporally-lagged node values.

---

## 5. Phase 3: ReAct Reasoning Loop

The **ReAct agent** implements a bounded Thought → Act → Observe loop.
Maximum **3 iterations** to stay within on-device latency budget (~800ms).

```
Algorithm: ReAct.reason(symptom) → [CausalExplanation]
───────────────────────────────────────────────────────

1. MATURITY CHECK
   config = EngineMaturityTracker.phaseConfig()
   if NOT config.useReAct:
     return BioRuleEngine.evaluate(symptom)   // Tier A fallback

2. THOUGHT — Generate initial hypotheses
   hypotheses = GenerateHypotheses(symptom, window)

   For each DebtType in {metabolic, digital, somatic}:
     Scan health context for trigger signals:
       Metabolic: glucose crash/spike, high-GL meal (GL > 25)
       Digital:   passive screen time > 30min, zombie-scrolling events
       Somatic:   sleep < 6.5h, AQI > 100, pollen ≥ 8, temp > 33°C

     Build causal chain string array from observed signals
     Set initial confidence:
       Strong signal present:   0.40 – 0.55
       Weak / inferred signal:  0.10 – 0.30

   Sort hypotheses descending by confidence

3. REACT LOOP (bounded to min(3, config.maxTools) iterations)
   for iteration in 0..<maxIterations:
     if hypotheses[0].confidence >= 0.70: break  // resolved

     tool = ToolRegistry.selectTool(for: agentState)
     if no tool available: break

     observation = tool.analyze(hypotheses, healthGraph, window)

     // OBSERVE — Bayesian update (additive, not multiplicative)
     for each hypothesis h:
       if observation.evidence[h.debtType] exists:
         h.confidence = clamp(h.confidence + evidence × obs.confidence, 0, 1)

     Re-sort hypotheses by confidence

4. FALLBACK
   if NOT resolved AND hypotheses[0].confidence < 0.4:
     ruleResults = BioRuleEngine.evaluate(symptom)
     if ruleResults non-empty: return ruleResults

5. BUILD EXPLANATIONS
   rankedDebts = DebtClassifier.classify(hypotheses, observations)
   for top 3 hypotheses with confidence > 0.15:
     narrative = NarrativeGenerator.generate(symptom, hypothesis, observations)
     append CausalExplanation(symptom, causalChain, strength, confidence, narrative)

   return explanations
```

### Tool Registry

Tools are selected based on which debt type has the highest un-covered confidence:

| Tool | Debt Type | What it measures |
|------|-----------|-----------------|
| `GlucoseCrashTool` | Metabolic | Spike onset, peak, nadir, AUC |
| `MealGlycemicTool` | Metabolic | GL per meal, cooking modifier |
| `HRVCorrelationTool` | Somatic | HRV suppression post-meal/stress |
| `SleepDebtTool` | Somatic | Sleep stage fragmentation, deficit |
| `DopamineDebtTool` | Digital | Passive-consumption minutes, switch frequency |
| `EnvironmentTool` | Somatic | AQI, pollen, temperature anomalies |

---

## 6. Phase 4: Hypothesis Ranking

After the ReAct loop, hypotheses are ranked by the `DebtClassifier`:

```
Algorithm: DebtClassifier.classify(hypotheses, observations)
────────────────────────────────────────────────────────────
For each DebtType t:
  base_score      = max(h.confidence for h in hypotheses where h.debtType == t)
  observation_boost = sum(obs.evidence[t] × obs.confidence for obs in observations)
  final_score[t]  = clamp(base_score + observation_boost, 0, 1)

Return ranked list of (DebtType, score) descending by score
```

The final `CausalExplanation.strength` is the `DebtClassifier` score, while
`CausalExplanation.confidence` is the raw hypothesis confidence from the ReAct
loop. Both are surfaced separately in the UI.

---

## 7. Phase 5: Counterfactual Generation

Counterfactuals are generated by the `InterventionCalculator` using SCM-style
do-calculus interventions — "what if you had done X instead?"

```
Algorithm: GenerateCounterfactualsForSymptom(symptom, explanations)
──────────────────────────────────────────────────────────────────
For each explanation in explanations:
  debtType = dominant debt type from causal chain

  Switch debtType:
    case .metabolic:
      Candidate interventions:
        1. Cooking method swap (white flour → whole wheat, GL reduction ~18%)
        2. Meal timing shift (eat 2h earlier, post-meal GL peak avoidance)
        3. Portion reduction (−30% serving, proportional GL drop)
        4. Pressure cooking (lectin reduction, better glycemic response)

    case .digital:
      Candidate interventions:
        1. 20-min screen break before symptomatic period
        2. Replace passive consumption with active task (+focus duration)
        3. Enable Focus Mode (estimated dopamine debt −35%)

    case .somatic:
      Candidate interventions:
        1. Sleep +1h (HRV recovery estimate)
        2. Outdoor activity during low-AQI window
        3. Reduce evening screen brightness (melatonin protection)

  For each candidate:
    impact     = estimated symptom reduction (0.0 – 1.0)
    effort     = {trivial | moderate | significant}
    confidence = correlation strength from historical data

    Append Counterfactual(description, impact, effort, confidence)

Sort all counterfactuals by impact descending
Return top maxCounterfactuals (default: 8)
```

---

## 8. Phase 6: Narrative Generation

The `NarrativeGenerator` produces a three-part human-readable explanation:

```
[WHY]      Root cause summary (1 sentence)
[EVIDENCE] Specific data points that support the causal chain (1-2 sentences)
[FIX]      The highest-impact counterfactual (1 sentence)
```

**Tier A (template-based, always available):**

```
WHY:      "Your {symptom} is likely caused by {debtType} debt: {chain_summary}."
EVIDENCE: "In the past 6 hours: {data_points_joined}."
FIX:      "{top_counterfactual.description}"
```

**Tier C (Local LLM, Week 9+):**
The same three-part structure is produced by a locally-running language model
(MLX on Apple Silicon) that has access to the full health context. No data
leaves the device.

---

## 9. Phase 7: Escalation Check (Tier 4)

After explanations are generated, `HighPainClassifier` evaluates whether an
SMS escalation is warranted:

```
Algorithm: HighPainClassifier.score(explanation, healthGraph)
────────────────────────────────────────────────────────────
Components (weighted sum):
  W1 = 0.4 × (explanation.confidence)
  W2 = 0.3 × (glucoseCrashSeverity if metabolic, else 0)
  W3 = 0.2 × (hrvSuppression normalized to 0-1)
  W4 = 0.1 × (symptom keyword severity: "pain", "chest", "dizzy" → 1.0)

score = W1 + W2 + W3 + W4   (clamped 0.0 – 1.0)

if score >= 0.75:
  EscalationClient.escalate(symptom, narrative, confidence)
```

The escalation threshold (0.75) is conservative: it fires only when multiple
high-confidence signals align simultaneously (e.g., confidence > 0.7 AND severe
glucose crash AND significant HRV suppression).

---

## 10. Phase 8: Clinical PDF Pipeline

The PDF report pipeline runs **after** the user explicitly requests it.
It does not block the causal reasoning pipeline.

```
Pipeline: GenerateAskVITAReport
──────────────────────────────
1. Validate: hasQueried == true AND FoxitConfig.isConfigured
2. Build HealthReportService.AskVITAContext:
     question    = lastSubmittedQuery
     explanations = ranked CausalExplanation[]
     counterfactuals = ranked Counterfactual[]
3. BuildAskVITADocumentValues(appState, context):
     → patientSection (name, date, generated timestamp)
     → questionSection (verbatim user question)
     → causalFindings (causal chain, confidence, strength per explanation)
     → interventions (counterfactual description, impact%, effort, confidence)
     → aiSummary (narrative text + confidence band)
     → glucoseData (6h reading table with trend classification)
     → mealRows (meal source, GL, cooking method, bioavailability modifier)
4. DocxTemplateBuilder.build() → base64 DOCX template
5. FoxitDocumentGenerationService.generate(template, values, config)
     → POST /document-generation/api/GenerateDocumentBase64
     → returns base64 PDF
6. FoxitPDFServicesService.optimize(pdfData, config)
     → POST /pdf-services/api/OptimizePDF
     → returns compressed, linearized PDF
7. Store reportPDFData → offer Share Sheet
```

**Report sections (in order):**

| Section | Contents |
|---------|---------|
| Header | Patient name, date, VITA version, query |
| Causal Analysis | Ranked explanations with confidence scores and chains |
| Evidence Table | Glucose readings, meal events, HRV values from the 6h window |
| Counterfactual Interventions | Ranked recommendations with impact % and effort |
| AI Summary | Narrative text with confidence band visualization |
| Disclaimer | "For informational purposes. Not a medical diagnosis." |

---

## 11. Maturity Tiers

The algorithm degrades gracefully based on data maturity:

| Tier | Weeks | Mode | Capability |
|------|-------|------|-----------|
| A — Passive | 1–2 | Bio-Rule Engine only | Deterministic rules, no causal claims |
| B — Correlation | 3–4 | Pattern detection | Surface correlations, tentative chains |
| C — Causal | 5–8 | Full ReAct + tools | Causal structure learning (PC algorithm) |
| D — Predictive | 9+ | ReAct + Local LLM | Counterfactual simulations, active experiments |

`EngineMaturityTracker` determines the phase by counting persisted edge count
and observation density in the HealthGraph.

---

## 12. Data Sources

### Metabolic (Layer 1: Consumption Bridge)

```
Rotimatic NEXT
  Protocol: Local REST (UDP discovery on port 5353 → device IP)
  Endpoint: /api/v1/session
  Fields:   flour_type, water_ratio, oil_ratio, kneading_duration
  Derived:  glycemic_index, glycemic_load, bioavailability_modifier

Instant Pot Pro Plus
  Protocol: BLE GATT (service UUID 0xFFE0)
  Captured: program, pressure_kpa, duration, temperature_curve
  Derived:  bioavailability_modifier per program (see table below)

Instacart / DoorDash
  Protocol: Authenticated scraping agent (user-authorized)
  Source:   Order history DOM → USDA FoodData Central lookup
  Fields:   item_name, quantity, macronutrients, GI, allergens, additives

HealthKit CGM (Dexcom G7 / Libre 3)
  HKQuantityType: bloodGlucose
  Interval: 5 min
  Derived:  GlucoseEvent {spike, nadir, AUC, energy_state}
```

### Physiological (Layer 2: Physiological Pulse)

```
HKAnchoredObjectQuery (new samples only):
  HRV (SDNN):   every sample (~5 min)
  Resting HR:   hourly aggregate
  Blood Oxygen: every sample
  Sleep Stages: on wake event

HKStatisticsCollectionQuery:
  Active Energy: 15-min buckets
  Step Count:    hourly
```

### Behavioral (Layer 3: Intentionality Tracker)

```
Screen time API → app category classification
  ACTIVE_WORK:          IDE/Editor, Docs, Focus Mode active
  PASSIVE_CONSUMPTION:  Social, Short-form video, rapid app-switch
  STRESS_SIGNAL:        Calendar density, back-to-back meetings

Dopamine Debt Score:
  = (0.4 × passive_min_last_3h/60
   + 0.3 × app_switch_freq_zscore
   + 0.2 × (1 − focus_mode_ratio)
   + 0.1 × late_night_screen_penalty) × 100
```

---

## 13. Complexity Analysis

| Phase | Time Complexity | Notes |
|-------|----------------|-------|
| DAG Build | O(E) | E = number of persisted edges |
| DFS Path Tracing | O(V + E) | V = 6 node types, E bounded by history |
| Hypothesis Generation | O(N) | N = samples in 6h window |
| ReAct Loop | O(3 × T) | T = tool analysis cost, max 3 iterations |
| Counterfactual Gen | O(K × M) | K = interventions per type, M = explanations |
| PDF Build | O(R) | R = report rows, network-bound |

Total on-device latency budget: **≤ 800ms** for Phases 0–6.
PDF generation (Phase 8) is async and user-initiated.

---

*Ask VITA Algorithm — VITA Health Causality Engine*
*Document version: 1.0 | February 2026*
