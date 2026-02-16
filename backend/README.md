# VITA Backend

Python/FastAPI reasoning engine for causal inference.

## Quick Start

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The API is available at `http://localhost:8000`. Health check: `GET /health`.
