from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from threading import Lock
from typing import Dict, Optional

from app.models.order import OrderCreate, OrderOut, OrderStatus, OrderUpdate, new_order_id


class OrderNotFound(Exception):
    pass


@dataclass
class _OrderRecord:
    """Internal storage record as of now
    migration to Postgres without changing contracts.
    """
    order_id: str
    status: OrderStatus
    customer_id: str
    product_sku: str
    quantity: int
    created_at: datetime
    updated_at: datetime


class OrderService:
    """Service layer for orders.
    - Owns business logic.
    - Owns persistence (in-memory for now).
    - Routes call this, but do not implement business rules themselves.
    """

    def __init__(self) -> None:
        self._lock = Lock()
        self._orders: Dict[str, _OrderRecord] = {}

    def create_order(self, data: OrderCreate) -> OrderOut:
        now = datetime.now(timezone.utc)
        order_id = new_order_id()

        record = _OrderRecord(
            order_id=order_id,
            status=OrderStatus.created,
            customer_id=data.customer_id,
            product_sku=data.product_sku,
            quantity=data.quantity,
            created_at=now,
            updated_at=now,
        )

        with self._lock:
            self._orders[order_id] = record

        return self._to_out(record)

    def get_order(self, order_id: str) -> OrderOut:
        with self._lock:
            record = self._orders.get(order_id)

        if not record:
            raise OrderNotFound(f"Order '{order_id}' not found")

        return self._to_out(record)

    def update_order(self, order_id: str, data: OrderUpdate) -> OrderOut:
        with self._lock:
            record = self._orders.get(order_id)
            if not record:
                raise OrderNotFound(f"Order '{order_id}' not found")

            # Partial update 
            if data.status is not None:
                record.status = data.status
            if data.quantity is not None:
                record.quantity = data.quantity

            record.updated_at = datetime.now(timezone.utc)
            self._orders[order_id] = record

        return self._to_out(record)

    @staticmethod
    def _to_out(record: _OrderRecord) -> OrderOut:
        return OrderOut(
            order_id=record.order_id,
            status=record.status,
            customer_id=record.customer_id,
            product_sku=record.product_sku,
            quantity=record.quantity,
            created_at=record.created_at,
            updated_at=record.updated_at,
        )


# Simple singleton instance for this assignment.
# In production, you'd use dependency injection / app state.
order_service = OrderService()