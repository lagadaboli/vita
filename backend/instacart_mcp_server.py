#!/usr/bin/env python3
"""Mock Instacart MCP stdio server for VITA development/testing.

Implements MCP 2024-11-05 JSON-RPC over stdio and returns realistic
grocery orders for end-to-end ingestion testing.

Supports one tool: get_recent_orders(days: int = 7)
"""

import json
import sys
import time

_NOW = int(time.time() * 1000)
_DAY_MS = 86_400_000

MOCK_ORDERS = [
    {
        "id": "ic-order-001",
        "created_at_ms": _NOW - 1 * _DAY_MS,
        "total_cents": 12540,
        "items": [
            {"name": "Basmati Rice", "category": "grain", "glycemic_index": 58.0, "quantity": 907, "unit": "g"},
            {"name": "Whole Wheat Atta", "category": "grain", "glycemic_index": 52.0, "quantity": 2268, "unit": "g"},
            {"name": "Chickpeas", "category": "legume", "glycemic_index": 28.0, "quantity": 2, "unit": "lb"},
            {"name": "Greek Yogurt", "category": "dairy", "glycemic_index": 11.0, "quantity": 32, "unit": "oz"},
        ],
    },
    {
        "id": "ic-order-002",
        "created_at_ms": _NOW - 3 * _DAY_MS,
        "total_cents": 8420,
        "items": [
            {"name": "Bananas", "category": "fruit", "glycemic_index": 51.0, "quantity": 6, "unit": "piece"},
            {"name": "Spinach", "category": "vegetable", "glycemic_index": 15.0, "quantity": 312, "unit": "g"},
            {"name": "Eggs", "category": "protein", "glycemic_index": 0.0, "quantity": 12, "unit": "piece"},
            {"name": "Almond Milk Unsweetened", "category": "beverage", "glycemic_index": 30.0, "quantity": 64, "unit": "oz"},
        ],
    },
    {
        "id": "ic-order-003",
        "created_at_ms": _NOW - 6 * _DAY_MS,
        "total_cents": 9650,
        "items": [
            {"name": "Sourdough Bread", "category": "bread", "glycemic_index": 53.0, "quantity": 1, "unit": "loaf"},
            {"name": "Avocado", "category": "fruit", "glycemic_index": 10.0, "quantity": 4, "unit": "piece"},
            {"name": "Tomatoes", "category": "vegetable", "glycemic_index": 15.0, "quantity": 680, "unit": "g"},
            {"name": "Olive Oil", "category": "fat", "glycemic_index": 0.0, "quantity": 500, "unit": "ml"},
        ],
    },
    {
        "id": "ic-order-004",
        "created_at_ms": _NOW - 10 * _DAY_MS,
        "total_cents": 7150,
        "items": [
            {"name": "Instant Oats", "category": "grain", "glycemic_index": 79.0, "quantity": 510, "unit": "g"},
            {"name": "Blueberries", "category": "fruit", "glycemic_index": 53.0, "quantity": 340, "unit": "g"},
            {"name": "Peanut Butter", "category": "spread", "glycemic_index": 14.0, "quantity": 454, "unit": "g"},
        ],
    },
]


def _frame(msg: dict) -> bytes:
    body = json.dumps(msg).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    return header + body


def _read_message() -> dict:
    headers: dict[str, str] = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            raise EOFError("stdin closed")
        if line in (b"\n", b"\r\n"):
            break
        decoded = line.decode("utf-8", errors="replace").strip()
        if ":" in decoded:
            key, value = decoded.split(":", 1)
            headers[key.strip().lower()] = value.strip()

    length = int(headers.get("content-length", "0"))
    body = sys.stdin.buffer.read(length)
    return json.loads(body.decode("utf-8"))


def _write_message(msg: dict) -> None:
    sys.stdout.buffer.write(_frame(msg))
    sys.stdout.buffer.flush()


def main() -> None:
    while True:
        try:
            msg = _read_message()
        except (EOFError, json.JSONDecodeError):
            break

        method = msg.get("method", "")
        msg_id = msg.get("id")

        if method == "initialize":
            _write_message(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "instacart-mcp-mock", "version": "0.1.0"},
                    },
                }
            )
        elif method == "notifications/initialized":
            pass
        elif method == "tools/call":
            params = msg.get("params", {})
            tool = params.get("name", "")
            args = params.get("arguments", {})

            if tool == "get_recent_orders":
                days = int(args.get("days", 7))
                cutoff_ms = int((time.time() - days * 86_400) * 1000)
                orders = [o for o in MOCK_ORDERS if o["created_at_ms"] >= cutoff_ms]
                _write_message(
                    {
                        "jsonrpc": "2.0",
                        "id": msg_id,
                        "result": {"structuredContent": {"orders": orders}},
                    }
                )
            else:
                _write_message(
                    {
                        "jsonrpc": "2.0",
                        "id": msg_id,
                        "error": {"code": -32601, "message": f"Unknown tool: {tool}"},
                    }
                )
        elif msg_id is not None:
            _write_message(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "error": {"code": -32601, "message": f"Method not found: {method}"},
                }
            )


if __name__ == "__main__":
    main()
