"""SQLAlchemy declarative base and timestamp mixin."""

from sqlalchemy import Column, Integer, Text, func
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass


class TimestampMixin:
    """Mixin that adds created_at (auto-set) to models."""

    created_at = Column(Text, server_default=func.datetime("now"))


class PKMixin:
    """Mixin that adds an auto-incrementing integer primary key."""

    id = Column(Integer, primary_key=True, autoincrement=True)
