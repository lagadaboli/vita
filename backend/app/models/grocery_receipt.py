"""Grocery receipt and line item models."""

from sqlalchemy import Column, Float, ForeignKey, Index, Integer, Text, UniqueConstraint

from app.models.base import Base, PKMixin, TimestampMixin


class GroceryReceipt(Base, PKMixin, TimestampMixin):
    __tablename__ = "grocery_receipts"

    source = Column(Text, nullable=False)  # instacart / doordash
    order_id = Column(Text, nullable=False, unique=True)
    order_timestamp_ms = Column(Integer, nullable=True)
    total_price_cents = Column(Integer, nullable=True)
    raw_html = Column(Text, nullable=True)
    fetched_at = Column(Text, nullable=True)

    __table_args__ = (
        UniqueConstraint("order_id", name="uq_grocery_receipts_order_id"),
        Index("idx_grocery_receipts_source_ts", "source", "order_timestamp_ms"),
    )


class GroceryItem(Base, PKMixin):
    __tablename__ = "grocery_items"

    receipt_id = Column(Integer, ForeignKey("grocery_receipts.id"), nullable=False)
    item_name = Column(Text, nullable=False)
    quantity = Column(Float, nullable=True)
    unit = Column(Text, nullable=True)
    price_cents = Column(Integer, nullable=True)
    glycemic_index = Column(Float, nullable=True)
    category = Column(Text, nullable=True)
    resolved = Column(Integer, default=0)  # boolean as int
