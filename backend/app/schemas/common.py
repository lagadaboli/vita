"""Shared Pydantic types: timestamps, pagination."""

from pydantic import BaseModel, Field


class MillisecondTimestamp(BaseModel):
    """A Unix timestamp in milliseconds."""

    timestamp_ms: int = Field(..., description="Unix epoch milliseconds")


class Pagination(BaseModel):
    """Standard pagination parameters."""

    offset: int = Field(0, ge=0)
    limit: int = Field(50, ge=1, le=500)


class PaginatedResponse(BaseModel):
    """Wrapper for paginated results."""

    total: int
    offset: int
    limit: int
    items: list
