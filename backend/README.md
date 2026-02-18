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

## MCP Grocery Integrations (Instacart + DoorDash)

The backend can fetch grocery/delivery orders from real accounts using session cookies,
or from MCP stdio servers when configured.

### Mock mode (default)

Run backend normally; local mock MCP servers are used automatically.

```bash
cd backend
uvicorn app.main:app --reload
```

### Real account mode (when ready)

Set cookie values before starting the backend:

```bash
cd backend
export VITA_INSTACART_SESSION_COOKIE="session=..."
export VITA_DOORDASH_SESSION_COOKIE="dd_session_id=..."
uvicorn app.main:app --reload
```

Both values may be full Cookie header fragments copied from your browser session.

### Optional MCP override mode (custom connector)

```bash
export VITA_INSTACART_MCP_STDIO_COMMAND="python instacart_mcp_server.py"
export VITA_DOORDASH_MCP_STDIO_COMMAND="python doordash_mcp_server.py"
```

If a session cookie is set for a provider, cookie-based fetching is used first.
If cookie-based fetching is not configured, MCP stdio command is used.

### Trigger a fetch cycle

```bash
curl -X POST http://localhost:8000/api/v1/grocery/fetch
```

This stores receipts and creates `meal_events`:
- Instacart → `source=instacart`, `event_type=grocery_purchase`
- DoorDash → `source=doordash`, `event_type=meal_delivery`

Mobile can then ingest these through:

```bash
curl "http://localhost:8000/api/v1/sync/pull?since_ms=0"
```
