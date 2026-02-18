"""Minimal MCP stdio client utilities.

Implements enough of the JSON-RPC over stdio protocol to:
1) initialize an MCP server process
2) call a tool by name
3) parse structured tool outputs
"""

from __future__ import annotations

import asyncio
import json
import logging
import shlex
from typing import Any

logger = logging.getLogger(__name__)

_MCP_PROTOCOL_VERSION = "2024-11-05"


def _frame_jsonrpc(message: dict[str, Any]) -> bytes:
    body = json.dumps(message).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    return header + body


async def _read_mcp_message(stdout: asyncio.StreamReader) -> dict[str, Any]:
    headers: dict[str, str] = {}

    while True:
        line = await stdout.readline()
        if not line:
            raise RuntimeError("MCP server closed stdout before sending a message")
        if line in (b"\n", b"\r\n"):
            break

        decoded = line.decode("utf-8").strip()
        if ":" not in decoded:
            continue
        key, value = decoded.split(":", 1)
        headers[key.strip().lower()] = value.strip()

    content_length_str = headers.get("content-length")
    if content_length_str is None:
        raise RuntimeError("MCP message missing Content-Length header")

    content_length = int(content_length_str)
    payload = await stdout.readexactly(content_length)
    return json.loads(payload.decode("utf-8"))


def _extract_tool_data(result: dict[str, Any] | None) -> dict[str, Any] | None:
    if not result:
        return None

    structured = result.get("structuredContent")
    if isinstance(structured, dict):
        return structured
    if isinstance(structured, list):
        return {"items": structured}

    content = result.get("content")
    if not isinstance(content, list):
        return result if isinstance(result, dict) else None

    for block in content:
        if not isinstance(block, dict):
            continue

        if block.get("type") == "json" and isinstance(block.get("json"), dict):
            return block["json"]

        if block.get("type") == "text":
            text = block.get("text")
            if not isinstance(text, str):
                continue
            try:
                parsed = json.loads(text)
                if isinstance(parsed, dict):
                    return parsed
                if isinstance(parsed, list):
                    return {"items": parsed}
            except json.JSONDecodeError:
                return {"text": text}

    return result if isinstance(result, dict) else None


async def call_mcp_tool_stdio(
    command: str,
    tool_name: str,
    arguments: dict[str, Any] | None = None,
    timeout_seconds: float = 20.0,
) -> dict[str, Any] | None:
    """Call a single MCP tool via stdio and return normalized structured data."""
    argv = shlex.split(command)
    if not argv:
        raise ValueError("MCP stdio command is empty")

    proc = await asyncio.create_subprocess_exec(
        *argv,
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    if proc.stdin is None or proc.stdout is None:
        raise RuntimeError("Failed to open MCP stdio pipes")

    async def _send(message: dict[str, Any]) -> None:
        proc.stdin.write(_frame_jsonrpc(message))
        await proc.stdin.drain()

    async def _read_until_response(msg_id: int) -> dict[str, Any]:
        while True:
            message = await _read_mcp_message(proc.stdout)
            if message.get("id") == msg_id:
                return message

    try:
        # 1) initialize
        await _send(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": _MCP_PROTOCOL_VERSION,
                    "capabilities": {},
                    "clientInfo": {
                        "name": "vita-backend",
                        "version": "0.1.0",
                    },
                },
            }
        )
        await asyncio.wait_for(_read_until_response(1), timeout=timeout_seconds)

        # 2) initialized notification
        await _send(
            {
                "jsonrpc": "2.0",
                "method": "notifications/initialized",
                "params": {},
            }
        )

        # 3) tools/call
        await _send(
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": tool_name,
                    "arguments": arguments or {},
                },
            }
        )
        response = await asyncio.wait_for(
            _read_until_response(2), timeout=timeout_seconds
        )

        if "error" in response:
            logger.warning(
                "MCP tool call failed: command=%s tool=%s error=%s",
                command,
                tool_name,
                response["error"],
            )
            return None

        return _extract_tool_data(response.get("result"))
    finally:
        try:
            proc.terminate()
            await asyncio.wait_for(proc.wait(), timeout=2.0)
        except Exception:
            proc.kill()
            await proc.wait()
