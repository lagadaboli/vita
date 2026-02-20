# Ask VITA — Chat Algorithm & Architecture

> **"Why am I tired?"** → causal analysis → Gemini AI response → persistent conversation → provider-ready PDF

This document describes the complete architecture and algorithm powering Ask VITA:
from a free-text question to a multi-turn, AI-driven conversation grounded in the
user's real health data, with structured causal chain cards and an on-demand
clinical PDF report.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Conversation Model](#2-conversation-model)
3. [Full Turn Algorithm](#3-full-turn-algorithm)
4. [Phase 0: Input Handling](#4-phase-0-input-handling)
5. [Phase 1: Causal Analysis — ReAct Loop](#5-phase-1-causal-analysis--react-loop)
6. [Phase 2: DAG Construction & Path Tracing](#6-phase-2-dag-construction--path-tracing)
7. [Phase 3: Hypothesis Ranking](#7-phase-3-hypothesis-ranking)
8. [Phase 4: Counterfactual Generation (SCM)](#8-phase-4-counterfactual-generation-scm)
9. [Phase 5: Health Context Extraction](#9-phase-5-health-context-extraction)
10. [Phase 6: System Prompt Construction](#10-phase-6-system-prompt-construction)
11. [Phase 7: Gemini Multi-turn Chat](#11-phase-7-gemini-multi-turn-chat)
12. [Phase 8: Narrative Fallback Hierarchy](#12-phase-8-narrative-fallback-hierarchy)
13. [Phase 9: Response Assembly & History Update](#13-phase-9-response-assembly--history-update)
14. [Phase 10: Escalation Check](#14-phase-10-escalation-check)
15. [Phase 11: Clinical PDF Pipeline](#15-phase-11-clinical-pdf-pipeline)
16. [Maturity Tiers](#16-maturity-tiers)
17. [Data Sources](#17-data-sources)
18. [Complexity Analysis](#18-complexity-analysis)
19. [Component Map](#19-component-map)

---

## 1. System Overview

```
┌───────────────────────────────────────────────────────────────────────────┐
│                          Ask VITA — Full Pipeline                         │
│                                                                           │
│  User message (NL)                                                        │
│        │                                                                  │
│        ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                       VITAChatEngine                                │  │
│  │                                                                     │  │
│  │  ┌──────────────────────────────┐  ┌──────────────────────────┐    │  │
│  │  │   Causal Analysis Pipeline   │  │   Health Context Loader  │    │  │
│  │  │                              │  │                          │    │  │
│  │  │  CausalityEngine             │  │  HealthGraph queries:    │    │  │
│  │  │   └─ ReActAgent              │  │   • Glucose (6h)         │    │  │
│  │  │       ├─ BioRuleEngine       │  │   • Meals + GL           │    │  │
│  │  │       ├─ ToolRegistry        │  │   • HRV (SDNN)           │    │  │
│  │  │       └─ CausalDAG           │  │   • Sleep stages         │    │  │
│  │  │  InterventionCalculator      │  │   • Behavior / dopamine  │    │  │
│  │  │   └─ SCM do-calculus         │  │   • Environment (AQI)    │    │  │
│  │  └──────────────┬───────────────┘  └────────────┬─────────────┘    │  │
│  │                 │                               │                   │  │
│  │                 └──────────────┬────────────────┘                   │  │
│  │                                ▼                                    │  │
│  │              System Prompt Builder                                  │  │
│  │               (real data + causal findings embedded)                │  │
│  │                                │                                    │  │
│  │                                ▼                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────┐   │  │
│  │  │                   GeminiService                             │   │  │
│  │  │                                                             │   │  │
│  │  │  POST generateContent                                       │   │  │
│  │  │  • system_instruction: health data + causal analysis        │   │  │
│  │  │  • contents[]: conversation history (last 20 messages)      │   │  │
│  │  │  • contents[-1]: current user message                       │   │  │
│  │  │  • model: gemini-2.0-flash (default)                        │   │  │
│  │  └─────────────────────────────────────────────────────────────┘   │  │
│  │                                │                                    │  │
│  │                                ▼                                    │  │
│  │              TurnResult { response, explanations,                   │  │
│  │                           counterfactuals, glucosePoints,           │  │
│  │                           mealAnnotations, activatedSources }       │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                  │
│        ▼                                                                  │
│  ChatMessage.vita(...)  appended to messages[]                            │
│        │                                                                  │
│        ├──▶  UI: narrative bubble + expandable causal chain cards         │
│        ├──▶  HighPainClassifier → SMS escalation (if score ≥ 0.75)       │
│        └──▶  PDF pipeline (user-initiated, Foxit API)                     │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Conversation Model

The conversation is the primary data structure. Each session maintains an ordered
array of `ChatMessage` values. There is no session reset between questions —
every new message appends to the same thread.

```
ChatMessage
  ├── id:                  UUID
  ├── role:                .user | .vita
  ├── content:             String          ← AI narrative (Gemini or template)
  ├── causalExplanations:  [CausalExplanation]   ← from ReAct engine
  ├── counterfactuals:     [Counterfactual]      ← from SCM engine
  ├── glucoseDataPoints:   [GlucoseDataPoint]    ← for annotated chart
  ├── mealAnnotations:     [MealAnnotationPoint] ← for annotated chart
  └── timestamp:           Date
```

**Key invariants:**

- User messages carry no causal data (`hasAnalysis == false`).
- Every VITA message carries the structured output of the full analysis pipeline
  for that specific question.
- The PDF report always uses the **latest** VITA message's structured data.
- Gemini receives the full thread (trimmed to last 20 messages) as context for
  every new response, giving it complete memory of the conversation.

---

## 3. Full Turn Algorithm

```
Algorithm: VITAChatEngine.processMessage(userMessage, history, appState)
─────────────────────────────────────────────────────────────────────────

Input:
  userMessage: String        — the new user question
  history:     [ChatMessage] — all prior messages in this session
  appState:    AppState      — access to HealthGraph + CausalityEngine

Output:
  TurnResult { response, explanations, counterfactuals,
               glucoseDataPoints, mealAnnotations, activatedSources }

Steps:

  1. window = [now − 6h, now]

  2. // Causal analysis (always runs, regardless of Gemini config)
     explanations   = CausalityEngine.querySymptom(userMessage)
                      │ → ReActAgent.reason(symptom)
                      │     → BioRuleEngine.evaluate() if Tier A
                      │     → ReAct loop (Thought → Act → Observe) × ≤3
                      └─ returns ranked [CausalExplanation], max 5

     counterfactuals = CausalityEngine.generateCounterfactual(
                         forSymptom: userMessage,
                         explanations: explanations
                       )
                       sorted by impact desc, max 8

  3. // Health context (glucose + meals always loaded for charts)
     glucosePoints = HealthGraph.queryGlucose(window)
     mealPoints    = HealthGraph.queryMeals(window)

  4. // Derive which data streams contributed
     activatedSources = inferSources(explanations, glucosePoints, mealPoints)

  5. if NOT GeminiConfig.isConfigured:
       return fallbackResponse(explanations, counterfactuals)   // Phase 12

  6. // Build system prompt with all real data embedded
     systemPrompt = buildSystemPrompt(
       window, glucosePoints, mealPoints,
       HRV, sleep, behavior, environment,    // queried inline
       explanations, counterfactuals
     )

  7. // Map conversation history to Gemini format
     geminiMessages = history.suffix(20).map { role: "user"|"model", parts: [text] }
     geminiMessages.append({ role: "user", parts: [userMessage] })

  8. // Call Gemini
     response = GeminiService.chat(
       systemPrompt: systemPrompt,
       messages:     geminiMessages,
       config:       GeminiConfig.current
     )

  9. return TurnResult(response, explanations, counterfactuals, ...)
```

---

## 4. Phase 0: Input Handling

```
Input:  raw_text = "Why am I so tired after lunch?"
Output: validated, trimmed symptom string
```

1. **Trim** — strip leading/trailing whitespace and newlines.
2. **Guard empty** — reject and return without entering the pipeline.
3. **Guard duplicate send** — `isQuerying` flag prevents concurrent submissions.
4. **Clear input field immediately** — `queryText = ""` before `async` work begins,
   so the input feels responsive even when the engine takes 1–2 seconds.
5. **Append user message** — `messages.append(.user(text))` before `await`, so
   the user bubble appears in the UI instantly.
6. **Start loading phase rotation** — a background `Task` increments `loadingPhase`
   every 1.4 seconds, cycling through contextual labels:
   ```
   "Scanning glucose patterns..."
   "Cross-referencing meal data..."
   "Analyzing HRV & sleep..."
   "Tracing causal chains..."
   "Generating insights..."
   ```

**Symptom keyword prior mapping (BioRuleEngine):**
```
"tired" | "fatigue" | "exhausted"    → DebtType.metabolic (high prior 0.40)
"focus" | "brain fog" | "distracted" → DebtType.digital   (high prior 0.40)
"stomach" | "bloat" | "indigestion"  → DebtType.metabolic (gut branch)
"sleep"  | "insomnia" | "waking"     → DebtType.somatic   (high prior 0.40)
"anxious" | "stressed" | "heart"     → DebtType.somatic
"glucose" | "spike" | "crash"        → DebtType.metabolic (direct signal)
```

---

## 5. Phase 1: Causal Analysis — ReAct Loop

The `ReActAgent` implements a bounded **Thought → Act → Observe** loop.
Maximum **3 iterations** to stay within on-device latency (~500ms).

```
Algorithm: ReActAgent.reason(symptom) → [CausalExplanation]
─────────────────────────────────────────────────────────────

1. MATURITY CHECK
   config = EngineMaturityTracker.phaseConfig()
   if NOT config.useReAct:
     return BioRuleEngine.evaluate(symptom)   // Tier A: rules only

2. THOUGHT — Generate initial hypotheses from health context
   window = [now − 6h, now]
   Load: glucose[], meals[], behaviors[], environment[], hrv[], sleep[]

   For each DebtType in {metabolic, digital, somatic}:

     METABOLIC signals:
       hasCrash    = any glucose.energyState in {.crashing, .reactiveLow}
       hasHighGL   = any meal.computedGlycemicLoad > 25
       chain       = [meal_source, "Glucose crash detected", "HRV: Xms"]
       confidence  = 0.55 if hasCrash, 0.40 if hasHighGL, 0.25 if meals present

     DIGITAL signals:
       passiveEvents = behaviors where category in {.passiveConsumption, .zombieScrolling}
       totalMinutes  = sum(event.duration / 60)
       maxDebt       = max(event.dopamineDebtScore)
       confidence    = min(totalMinutes / 60, 0.50)

     SOMATIC signals:
       hasSleepDeficit = sleep total < 6.5h OR no sleep samples
       hasEnvStress    = AQI > 100 OR pollen ≥ 8 OR temp > 33°C
       confidence      = 0.50 if both, 0.35 if either

   Ensure at least one hypothesis per DebtType (confidence 0.10 if no signals).
   Sort hypotheses descending by confidence.

3. REACT LOOP  (bounded to min(3, config.maxTools) iterations)
   resolutionThreshold = 0.70

   for i in 0 ..< maxIterations:
     if hypotheses[0].confidence ≥ resolutionThreshold: break   // resolved

     tool = ToolRegistry.selectTool(for: agentState)
     if tool == nil: break

     observation = tool.analyze(hypotheses, healthGraph, window)

     // OBSERVE — additive Bayesian update (not multiplicative, for robustness)
     for each hypothesis h:
       if evidence = observation.evidence[h.debtType]:
         h.confidence = clamp(h.confidence + evidence × obs.confidence, 0, 1)
         if evidence > 0: h.supportingEvidence.append(toolName + ": +X%")
         if evidence < 0: h.contradictingEvidence.append(toolName + ": −X%")

     Re-sort hypotheses by confidence.

4. FALLBACK
   if NOT resolved AND hypotheses[0].confidence < 0.40:
     ruleResults = BioRuleEngine.evaluate(symptom)
     if ruleResults non-empty: return ruleResults

5. BUILD EXPLANATIONS
   rankedDebts  = DebtClassifier.classify(hypotheses, observations)
   topHypotheses = hypotheses.filter { confidence > 0.15 }.prefix(3)

   for each hypothesis h in topHypotheses:
     score     = rankedDebts[h.debtType] ?? h.confidence
     narrative = NarrativeGenerator.generate(symptom, h, observations)
                 // Template narrative — Gemini will replace this in Phase 7
     append CausalExplanation(symptom, h.causalChain, score, h.confidence, narrative)

   return explanations   // max 5 passed to VITAChatEngine
```

### Tool Registry

| Tool | Debt Type | Measures |
|------|-----------|---------|
| `GlucoseCrashTool` | Metabolic | Spike onset, peak, nadir, AUC |
| `MealGlycemicTool` | Metabolic | GL per meal, bioavailability modifier |
| `HRVCorrelationTool` | Somatic | HRV suppression post-meal / post-stress |
| `SleepDebtTool` | Somatic | Stage fragmentation, total deficit |
| `DopamineDebtTool` | Digital | Passive-consumption minutes, switch freq |
| `EnvironmentTool` | Somatic | AQI, pollen, temperature anomalies |

---

## 6. Phase 2: DAG Construction & Path Tracing

The **Causal DAG** is an in-memory directed acyclic graph built from persisted
`HealthGraphEdge` rows each time the causal engine is queried.

### Node Types & Valid Directions

```
meal           → glucose      → symptom
meal           → physiological → symptom
physiological  → glucose      → symptom
behavioral     → physiological → symptom
environmental  → physiological → symptom
```

Edges in reverse order (e.g., `symptom → meal`) are rejected by
`CausalDirection.isValid()`.

### Build Algorithm

```
Algorithm: CausalDAG(edges: [HealthGraphEdge])
──────────────────────────────────────────────
for each edge e:
  srcType = nodeType(e.sourceNodeID)   // prefix: "meal_*", "glucose_*", ...
  tgtType = nodeType(e.targetNodeID)
  if srcType == nil OR tgtType == nil: continue
  if NOT CausalDirection.isValid(from: srcType, to: tgtType): continue
  adjacency[srcType].append(
    Edge(target: tgtType, edgeType: e.edgeType, weight: e.causalStrength)
  )
```

### DFS Path Tracing

```
Algorithm: tracePaths(from source: NodeType) → [[NodeType]]
────────────────────────────────────────────────────────────
currentPath = [source]
allPaths    = []

DFS(current, target = .symptom):
  if current == target AND len(currentPath) > 1:
    allPaths.append(snapshot of currentPath)
    return
  for edge in adjacency[current]:
    if edge.target NOT in currentPath:   // cycle guard
      currentPath.append(edge.target)
      DFS(edge.target)
      currentPath.removeLast()

return allPaths
```

### Path Strength

Product of edge weights along the path (learned by `EdgeWeightLearner`
via Pearson correlation over a 24h window):

```
PathStrength(path) = ∏ weight(path[i] → path[i+1])   for i in 0..<(n-1)
```

---

## 7. Phase 3: Hypothesis Ranking

```
Algorithm: DebtClassifier.classify(hypotheses, observations)
─────────────────────────────────────────────────────────────
for each DebtType t:
  base_score        = max(h.confidence  for h in hypotheses  where h.debtType == t)
  observation_boost = Σ (obs.evidence[t] × obs.confidence   for obs in observations)
  final_score[t]    = clamp(base_score + observation_boost, 0, 1)

return ranked [(DebtType, score)] descending by score
```

`CausalExplanation.strength` = DebtClassifier score (debt-level)
`CausalExplanation.confidence` = raw ReAct hypothesis confidence (chain-level)

Both are shown as separate indicators in the UI's `ConfidenceBar`.

---

## 8. Phase 4: Counterfactual Generation (SCM)

The `InterventionCalculator` runs do-calculus interventions through the
Structural Causal Model: "what would have happened if variable X had been
different?"

```
Algorithm: generateCounterfactualsForSymptom(symptom, explanations)
────────────────────────────────────────────────────────────────────
for each explanation:
  debtType = dominant type from causal chain

  METABOLIC interventions:
    • Cooking method: white flour → whole wheat (GL −18%)
    • Meal timing: eat 2h earlier (post-meal peak avoidance)
    • Portion: −30% serving (proportional GL reduction)
    • Pressure-cook: lectin −28%, protein bioavailability +35%

  DIGITAL interventions:
    • 20-min screen break before symptomatic period
    • Replace passive consumption with active task
    • Enable Focus Mode (estimated dopamine debt −35%)

  SOMATIC interventions:
    • Sleep +1h (HRV recovery estimate from historical data)
    • Outdoor activity during measured low-AQI window
    • Reduce evening screen brightness (melatonin protection)

  for each candidate:
    impact     ∈ [0, 1]   — estimated symptom reduction
    effort     ∈ {trivial, moderate, significant}
    confidence ∈ [0, 1]   — correlation strength in historical data
    Append Counterfactual(description, impact, effort, confidence)

sort by impact desc
return top 8
```

---

## 9. Phase 5: Health Context Extraction

`VITAChatEngine` loads real data directly from `HealthGraph` to embed in the
Gemini system prompt. This runs in parallel with (or immediately after) the
causal analysis.

```
window = [now − 6h, now]

glucosePoints = HealthGraph.queryGlucose(window)
                → [GlucoseDataPoint(timestamp, value)]   // suffix(16) → system prompt

mealPoints    = HealthGraph.queryMeals(window)
                → [MealAnnotationPoint(timestamp, label, glycemicLoad)]

hrv           = HealthGraph.querySamples(.hrvSDNN, window)
                → avg, latest

sleep         = HealthGraph.querySamples(.sleepAnalysis, window − 24h)
                → total hours

behavior      = HealthGraph.queryBehaviors(window)
                → passive minutes, max dopamine debt score

environment   = HealthGraph.queryEnvironment(window)
                → latest: AQI, pollen, temperature °C
```

**Source inference** (drives the data-source badges in the UI):
```
activatedSources = {}
if glucosePoints non-empty            → add "Glucose"
if mealPoints non-empty               → add "Meals"
if "hrv" in causalChains              → add "HRV"
if "sleep" in causalChains            → add "Sleep"
if "screen"|"dopamine" in chains      → add "Behavior"
if "aqi"|"pollen" in chains           → add "Environment"
if activatedSources empty             → add "Health Graph"
```

---

## 10. Phase 6: System Prompt Construction

The system prompt is rebuilt on every turn. It embeds the full health context
and the current causal analysis so Gemini always reasons over real data, not
synthetic examples.

```
System Prompt Structure
───────────────────────

[ROLE]
You are VITA, an intelligent personal health causality engine in conversation
with your user.

[INSTRUCTIONS]
• Trace causal chains using exact timestamps and values from the data below.
• Be specific (e.g., "glucose spiked to 156mg/dL at 7:45pm after Rotimatic
  roti with GL 28").
• Explain root causes directly; avoid excessive hedging.
• Suggest 1-2 concrete, evidence-backed interventions.
• In multi-turn conversations, reference and build on prior messages.
• Keep each response to 2-4 paragraphs. Never fabricate data.
• End with a brief follow-up prompt to encourage continued exploration.

[DATA WINDOW]
{windowStart} → {windowEnd}

━━ GLUCOSE ━━
  {timestamp}: {value} mg/dL
  ...  (last 16 readings)

━━ MEALS ━━
  {timestamp}: {label}  GL={glycemicLoad}
  ...

━━ PHYSIOLOGICAL ━━
  HRV (SDNN): avg {avg}ms, latest {latest}ms
  Sleep (last night): {hours}h

━━ BEHAVIOR ━━
  Passive screen time: {minutes}min  |  Dopamine debt: {score}

━━ ENVIRONMENT ━━
  AQI: {value}  |  Pollen: {index}  |  Temp: {°C}

━━ CAUSAL ANALYSIS (ReAct + Bio-Rule Engine) ━━
  [1] {symptom}
      Confidence: {%}%  |  Strength: {0.00}
      Chain: {step} → {step} → {step}
      Engine narrative: {template narrative}
  ...

━━ COUNTERFACTUAL INTERVENTIONS (SCM) ━━
  • {description}  (impact: {%}%, effort: {level}, confidence: {%}%)
  ...
```

The system prompt is **not** part of the `contents[]` array — it is passed as
`system_instruction` in the Gemini request body. This means it applies globally
to the entire conversation without consuming a turn slot.

---

## 11. Phase 7: Gemini Multi-turn Chat

```
Algorithm: GeminiService.chat(systemPrompt, messages, config)
─────────────────────────────────────────────────────────────

Endpoint:  POST https://generativelanguage.googleapis.com/v1beta/
               models/{config.model}:generateContent?key={apiKey}

Request body (JSON, snake_case):
  {
    "system_instruction": {
      "parts": [{ "text": systemPrompt }]
    },
    "contents": [
      { "role": "user",  "parts": [{ "text": "..." }] },
      { "role": "model", "parts": [{ "text": "..." }] },
      ...                                               // history
      { "role": "user",  "parts": [{ "text": userMessage }] }
    ],
    "generation_config": {
      "temperature": 0.7,
      "max_output_tokens": 1024,
      "top_p": 0.9
    }
  }

History mapping:
  ChatMessage.role == .user  → "user"
  ChatMessage.role == .vita  → "model"
  Trim to last 20 messages   → stays within free-tier token budget

Error handling:
  HTTP 4xx/5xx  → throw GeminiError.httpError(code, body)
  Empty text    → throw GeminiError.emptyResponse
  No key        → throw GeminiError.notConfigured → fallback (Phase 12)

Response parsing:
  candidates[0].content.parts[0].text  → trimmed response string
```

### Model Options (free tier)

| Model ID | Notes |
|----------|-------|
| `gemini-2.0-flash` | **Default.** Fastest free model, 1M context |
| `gemini-2.0-flash-lite` | Even faster, slightly lower quality |
| `gemini-1.5-flash` | Stable older model, same free tier limits |

**Free tier limits (all models):** 15 RPM · 1,500 RPD · 1,000,000 TPM

---

## 12. Phase 8: Narrative Fallback Hierarchy

When Gemini is unavailable (no key, API error, network timeout), VITA falls
back through this chain:

```
Priority 1 — Gemini response (cloud, multi-turn, context-aware)
    ↓  if not configured OR API error
Priority 2 — NarrativeGenerator template  (on-device, deterministic)
    Format: WHY / EVIDENCE / FIX  (3-part structure)
    WHY:      "Your {symptom} is likely caused by {debtType} debt: {chain_summary}."
    EVIDENCE: "In the past 6 hours: {data_points}."
    FIX:      "{top_counterfactual.description}"
    ↓  if no causal explanations found
Priority 3 — Static data-insufficient response
    "I've run the causal analysis but don't have enough data yet.
     More health data over the coming days will improve specificity."
    ↓  (always appends)
Note appended: "(Add a Gemini API key in Settings → Ask VITA AI for richer responses.)"
```

The template (Priority 2) is always generated by the `NarrativeGenerator` during
Phase 1 (build explanations step). Gemini replaces it — the template is embedded
in the system prompt to give Gemini a starting point, but Gemini's output is
what gets stored in `ChatMessage.content` and displayed to the user.

---

## 13. Phase 9: Response Assembly & History Update

```
Algorithm: AskVITAViewModel.sendMessage()
─────────────────────────────────────────
1. text = queryText.trimmed
   guard !text.isEmpty && !isQuerying

2. queryText = ""           // clear input immediately (UX)
   messages.append(.user(text))
   isQuerying = true
   start loadingPhaseRotation task

3. history = messages.dropLast()  // exclude the user msg just appended

4. result = try await VITAChatEngine.processMessage(
               userMessage: text,
               history: history,
               appState: appState
             )

5. vitaMsg = ChatMessage.vita(
               content:           result.response,        // Gemini text
               explanations:      result.explanations,    // ReAct output
               counterfactuals:   result.counterfactuals, // SCM output
               glucoseDataPoints: result.glucoseDataPoints,
               mealAnnotations:   result.mealAnnotations
             )
   messages.append(vitaMsg)

6. UI automatically re-renders the full thread.
   ScrollView scrolls to vitaMsg.id (bottom of thread).

7. PDF section becomes active (canGenerateReport = true).
   Always uses messages.last(where: { $0.role == .vita })
   — i.e., the latest VITA response's structured data.

On error:
   messages.append(.vitaError("Sorry, I ran into an error: {msg}"))
```

---

## 14. Phase 10: Escalation Check

Runs after every VITA message is appended. Evaluates the top causal explanation
for urgency. Does not block the UI.

```
Algorithm: HighPainClassifier.score(explanation, healthGraph)
──────────────────────────────────────────────────────────────
W1 = 0.4 × explanation.confidence
W2 = 0.3 × glucoseCrashSeverity    (0 if not metabolic)
W3 = 0.2 × hrvSuppressionNormalized (0 if no HRV data)
W4 = 0.1 × symptomSeverityKeyword  ("pain"|"chest"|"dizzy" → 1.0, else 0)

score = clamp(W1 + W2 + W3 + W4, 0, 1)

if score ≥ 0.75:
  EscalationClient.escalate(
    symptom:    explanation.symptom,
    reason:     explanation.narrative,
    confidence: score
  )
  // POST /notifications/escalate
  // Payload: symptom, reason, confidence, SHA-256(vendorID), timestamp
  // Twilio credentials are server-side only — no PII leaves the device
```

The 0.75 threshold is deliberately conservative. It requires multiple simultaneous
high-confidence signals (e.g., confidence > 0.70 AND severe glucose crash AND
significant HRV suppression) before firing.

---

## 15. Phase 11: Clinical PDF Pipeline

Runs **after** the user explicitly taps "Generate Report." Uses the latest VITA
message's structured data. Does not block the conversation.

```
Pipeline: AskVITAViewModel.generateReport()
────────────────────────────────────────────
1. Guard: messages non-empty AND FoxitConfig.isConfigured

2. question     = messages.last(where: role == .user).content
   explanations = latestVITAMessage.causalExplanations
   counterfactuals = latestVITAMessage.counterfactuals

3. HealthReportService.buildAskVITADocumentValues(appState, context)
     → patientSection:   name, date, VITA version
     → questionSection:  verbatim user question
     → causalFindings:   chain, confidence, strength per explanation
     → interventions:    description, impact%, effort, confidence
     → aiSummary:        Gemini narrative + confidence band
     → glucoseTable:     6h readings with trend classification
     → mealRows:         source, GL, cooking method, bioavailability modifier

4. templateBase64 = DocxTemplateBuilder.build().base64EncodedString()

5. rawPDF = FoxitDocumentGenerationService.generate(template, values, config)
     POST /document-generation/api/GenerateDocumentBase64
     Auth: client_id + client_secret headers
     → returns base64 PDF

6. optimizedPDF = FoxitPDFServicesService.optimize(rawPDF, config)
     POST /pdf-services/api/OptimizePDF
     → compressed, linearized PDF

7. reportPDFData = optimizedPDF
   reportState   = .complete
   UI: share sheet available
```

**Report sections:**

| Section | Contents |
|---------|---------|
| Header | Patient name, date, VITA version, query text |
| Causal Analysis | Ranked explanations, confidence, strength, causal chains |
| Evidence Table | Glucose readings, meals, HRV from the 6h window |
| Counterfactual Interventions | Ranked recommendations, impact %, effort level |
| AI Summary | Gemini narrative (or template fallback) + confidence band |
| Disclaimer | "For informational purposes. Not a medical diagnosis." |

---

## 16. Maturity Tiers

The causal engine degrades gracefully based on data accumulation:

| Tier | Weeks | Mode | Narrative Source | Capability |
|------|-------|------|-----------------|-----------|
| A — Passive | 1–2 | Bio-Rule Engine only | Template (Priority 2) | Deterministic rules, pattern matching |
| B — Correlation | 3–4 | Pattern detection | Template + Gemini | Surface correlations, tentative chains |
| C — Causal | 5–8 | Full ReAct + tools | Gemini (Priority 1) | Causal structure via PC algorithm |
| D — Predictive | 9+ | ReAct + full context | Gemini (Priority 1) | Counterfactual simulations, active experiments |

`EngineMaturityTracker` determines the active tier by counting persisted edge
density and observation count in the HealthGraph.

**Gemini is orthogonal to maturity tiers.** It operates at the language layer,
always generating a response. The quality of that response improves as the
underlying causal analysis (Tiers A–D) produces higher-confidence structured
data to embed in the system prompt.

---

## 17. Data Sources

### Metabolic — Layer 1: Consumption Bridge

```
Rotimatic NEXT
  Protocol:  Local REST (UDP discovery port 5353 → device IP)
  Endpoint:  /api/v1/session
  Fields:    flour_type, water_ratio, oil_ratio, kneading_duration
  Derived:   glycemic_index, glycemic_load, bioavailability_modifier

Instant Pot Pro Plus
  Protocol:  BLE GATT  (service UUID 0xFFE0)
  Captured:  program, pressure_kpa, duration, temperature_curve
  Bioavailability modifiers:
    Pressure Cook → GL × 0.72   (−28% lectin, +35% protein)
    Slow Cook     → GL × 1.00   (baseline)
    Sauté         → GL × 1.05   (+fat-soluble vitamin absorption)
    Steam         → GL × 0.90   (−water-soluble vitamin)

Instacart / DoorDash
  Protocol:  Authenticated scraping agent (user-authorized, CFAA safe harbor)
  Source:    Order history DOM → USDA FoodData Central
  Fields:    item_name, quantity, macros, GI, allergens, additives

CGM — Dexcom G7 / Libre 3
  HKQuantityType: bloodGlucose
  Interval:  5 min
  Derived:   GlucoseEvent { spike, nadir, AUC, energy_state }
  Energy states: STABLE | RISING | CRASHING | REACTIVE_LOW
```

### Physiological — Layer 2: Physiological Pulse

```
HKAnchoredObjectQuery (incremental, new samples only):
  HRV (SDNN):    every sample (~5 min)
  Resting HR:    hourly aggregate
  Blood Oxygen:  every sample
  Sleep Stages:  on wake event

HKStatisticsCollectionQuery (aggregated):
  Active Energy: 15-min buckets
  Step Count:    hourly
```

### Behavioral — Layer 3: Intentionality Tracker

```
Screen Time API → category classification:
  ACTIVE_WORK:         IDE/Editor >10min, Docs, Focus Mode ON
  PASSIVE_CONSUMPTION: Social, short-form video, rapid app-switch (>5/min)
  STRESS_SIGNAL:       Calendar density >6 meetings/day, evening email

Dopamine Debt Score (0–100):
  = ( 0.4 × passive_minutes_last_3h / 60
    + 0.3 × app_switch_frequency_z_score
    + 0.2 × (1 − time_in_focus_mode_ratio)
    + 0.1 × late_night_screen_penalty ) × 100
```

---

## 18. Complexity Analysis

| Phase | Complexity | Notes |
|-------|-----------|-------|
| Input handling | O(1) | String ops + array append |
| DAG Build | O(E) | E = persisted edges |
| DFS Path Tracing | O(V + E) | V = 6 node types; E bounded by history |
| Hypothesis Generation | O(N) | N = samples in 6h window |
| ReAct Loop | O(3 × T) | T = tool cost; max 3 iterations |
| Counterfactual Gen | O(K × M) | K = interventions per type, M = explanations |
| Health Context Load | O(N) | Parallel DB reads |
| System Prompt Build | O(N) | String formatting |
| History Trim | O(min(H, 20)) | H = total history length |
| Gemini API Call | O(1) network | Latency: 400–1200ms typical |
| Response Append | O(1) | Array insert |
| Escalation Check | O(1) | Weighted sum |
| PDF Build | O(R) network | R = report rows; user-initiated only |

**On-device latency budget (Phases 1–6, pre-Gemini):** ≤ 500ms
**Gemini round-trip:** 400ms–1.2s (free tier, gemini-2.0-flash)
**Total time-to-first-character:** ~1–2s typical

---

## 19. Component Map

```
VITA App
├── AskVITAView.swift               — conversation UI, PDF section
│   ├── conversationThread          — ForEach messages[]
│   │   ├── userBubble()            — right-aligned teal, .user messages
│   │   └── vitaResponseBubble()    — left-aligned, .vita messages
│   │       └── AnalysisDisclosureGroup
│   │           ├── CausalExplanationCard (per explanation)
│   │           └── CounterfactualCard   (per counterfactual)
│   ├── thinkingBubble              — ThinkingDots + loadingPhase label
│   └── reportSection               — PDF generation + share
│
├── QueryInputView.swift            — pill input + circular send button
│
├── AskVITAViewModel.swift          — @Observable, messages[], PDF state
│
├── Models/
│   └── ChatMessage.swift           — conversation data model
│
└── Services/
    ├── VITAChatEngine.swift         — pipeline orchestrator
    ├── GeminiService.swift          — REST client (generateContent API)
    └── GeminiConfig.swift           — UserDefaults-backed API key + model

CausalityEngine (Swift Package)
├── CausalityEngine.swift           — querySymptom(), generateCounterfactual()
├── Agent/
│   └── ReActAgent.swift            — Thought → Act → Observe loop
├── SCM/
│   ├── CausalDAG.swift             — adjacency graph + DFS path tracing
│   ├── CausalDirection.swift       — valid edge direction rules
│   ├── EdgeWeightLearner.swift     — Pearson correlation weight updates
│   └── InterventionCalculator.swift — SCM counterfactual generation
├── Rules/
│   └── BioRuleEngine.swift         — deterministic fallback rules
├── Scoring/
│   ├── DebtClassifier.swift        — hypothesis ranking
│   ├── MetabolicDebtScorer.swift
│   ├── DigitalDebtScorer.swift
│   ├── SomaticStressScorer.swift
│   └── HighPainClassifier.swift    — escalation scoring
├── LLM/
│   └── NarrativeGenerator.swift    — template narrative (Gemini fallback)
└── Tools/
    └── ToolRegistry.swift          — tool selection for ReAct loop

VITACore (Swift Package)
├── HealthGraph/
│   ├── HealthGraph.swift           — central query interface
│   └── HealthGraphEdge.swift       — persisted causal edges
└── Models/
    ├── GlucoseReading.swift
    ├── MealEvent.swift             — includes bioavailabilityModifier
    ├── BehavioralEvent.swift       — dopamineDebtScore
    ├── PhysiologicalSample.swift   — HRV, sleep, HR, SpO2
    └── EnvironmentalCondition.swift

PDF Pipeline
├── FoxitDocumentGenerationService.swift — POST GenerateDocumentBase64
├── FoxitPDFServicesService.swift        — POST OptimizePDF
├── HealthReportService.swift            — buildAskVITADocumentValues()
├── DocxTemplateBuilder.swift            — DOCX template base64
└── FoxitConfig.swift                    — UserDefaults credentials
```

---

*Ask VITA Algorithm & Architecture — VITA Health Causality Engine*
*Document version: 2.0 | February 2026*
