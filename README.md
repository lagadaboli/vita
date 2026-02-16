# VITA — Personal Health Causality Engine

> **V**ital **I**nsights **T**hrough **A**nalysis

VITA discovers causal relationships between your meals, behavior, and physiological health using real-time data and machine learning.

## Repository Structure

| Directory | Description |
|-----------|-------------|
| [`mobile-swift/`](mobile-swift/) | iOS/macOS app and Swift Package libraries (HealthKit, Causality Engine, etc.) |
| [`backend/`](backend/) | Python/FastAPI reasoning engine for causal inference |
| [`shared/`](shared/) | Cross-platform API contracts and JSON schemas |
| [`infrastructure/`](infrastructure/) | Docker, deployment scripts, and CI/CD configuration |

## Quick Start

### Mobile App (Swift)

```bash
cd mobile-swift
swift build
swift test        # 42 tests
```

### Backend (Python)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

See each subdirectory's README for detailed instructions.
