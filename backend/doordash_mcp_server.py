#!/usr/bin/env python3
"""Mock DoorDash MCP stdio server for VITA development/testing.

Implements the MCP 2024-11-05 JSON-RPC over stdio protocol.
Returns realistic mock order data so the full pipeline can be exercised
without a live DoorDash account.

Supports one tool: get_recent_orders(days: int = 7)
"""

import json
import sys
import time

# ---------------------------------------------------------------------------
# Mock orders — realistic Indian + American takeout for metabolic testing
# ---------------------------------------------------------------------------

_NOW = int(time.time() * 1000)
_DAY_MS = 86_400_000

MOCK_ORDERS = [
    {
        "id": "dd-order-001",
        "created_at_ms": _NOW - 1 * _DAY_MS,
        "total_cents": 3250,
        "items": [
            {"name": "Chicken Tikka Masala", "category": "main", "glycemic_index": 35.0, "quantity": 1, "unit": "serving"},
            {"name": "Garlic Naan", "category": "bread", "glycemic_index": 72.0, "quantity": 2, "unit": "piece"},
            {"name": "Mango Lassi", "category": "beverage", "glycemic_index": 60.0, "quantity": 1, "unit": "cup"},
        ],
    },
    {
        "id": "dd-order-002",
        "created_at_ms": _NOW - 3 * _DAY_MS,
        "total_cents": 2890,
        "items": [
            {"name": "Pad Thai", "category": "main", "glycemic_index": 45.0, "quantity": 1, "unit": "serving"},
            {"name": "Spring Rolls", "category": "appetizer", "glycemic_index": 55.0, "quantity": 3, "unit": "piece"},
            {"name": "Thai Iced Tea", "category": "beverage", "glycemic_index": 65.0, "quantity": 1, "unit": "cup"},
        ],
    },
    {
        "id": "dd-order-003",
        "created_at_ms": _NOW - 5 * _DAY_MS,
        "total_cents": 1899,
        "items": [
            {"name": "Caesar Salad", "category": "salad", "glycemic_index": 15.0, "quantity": 1, "unit": "serving"},
            {"name": "Grilled Salmon", "category": "protein", "glycemic_index": 0.0, "quantity": 1, "unit": "serving"},
        ],
    },
    {
        "id": "dd-order-004",
        "created_at_ms": _NOW - 8 * _DAY_MS,
        "total_cents": 2150,
        "items": [
            {"name": "Chole Bhature", "category": "main", "glycemic_index": 78.0, "quantity": 1, "unit": "serving"},
            {"name": "Raita", "category": "side", "glycemic_index": 20.0, "quantity": 1, "unit": "cup"},
        ],
    },
    {
        "id": "dd-order-005",
        "created_at_ms": _NOW - 12 * _DAY_MS,
        "total_cents": 1750,
        "items": [
            {"name": "Quinoa Bowl", "category": "main", "glycemic_index": 53.0, "quantity": 1, "unit": "serving"},
            {"name": "Avocado", "category": "topping", "glycemic_index": 10.0, "quantity": 0.5, "unit": "piece"},
        ],
    },
]


# ---------------------------------------------------------------------------
# MCP stdio framing helpers
# ---------------------------------------------------------------------------

def _frame(msg: dict) -> bytes:
    body = json.dumps(msg).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    return header + body


def _read_message() -> dict:
    headers: dict = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            raise EOFError("stdin closed")
        if line in (b"\n", b"\r\n"):
            break
        decoded = line.decode("utf-8", errors="replace").strip()
        if ":" in decoded:
            k, v = decoded.split(":", 1)
            headers[k.strip().lower()] = v.strip()

    length = int(headers.get("content-length", 0))
    body = sys.stdin.buffer.read(length)
    return json.loads(body.decode("utf-8"))


def _write_message(msg: dict) -> None:
    sys.stdout.buffer.write(_frame(msg))
    sys.stdout.buffer.flush()


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def main() -> None:
    while True:
        try:
            msg = _read_message()
        except (EOFError, json.JSONDecodeError):
            break

        method = msg.get("method", "")
        msg_id = msg.get("id")

        if method == "initialize":
            _write_message({
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "doordash-mcp-mock", "version": "0.1.0"},
                },
            })

        elif method == "notifications/initialized":
            pass  # notification — no response

        elif method == "tools/call":
            params = msg.get("params", {})
            tool = params.get("name", "")
            args = params.get("arguments", {})

            if tool == "get_recent_orders":
                days = int(args.get("days", 7))
                cutoff_ms = int((time.time() - days * 86_400) * 1000)
                orders = [o for o in MOCK_ORDERS if o["created_at_ms"] >= cutoff_ms]
                _write_message({
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "structuredContent": {"orders": orders},
                    },
                })
            else:
                _write_message({
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "error": {"code": -32601, "message": f"Unknown tool: {tool}"},
                })

        elif msg_id is not None:
            # Unknown method with an id — send method-not-found
            _write_message({
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32601, "message": f"Method not found: {method}"},
            })


if __name__ == "__main__":
    main()
