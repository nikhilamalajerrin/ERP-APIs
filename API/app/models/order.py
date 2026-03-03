#let us import the needed things 
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import uuid4 #for UID generator

from pydantic import BaseModel, Field

#str, enum as parents and class as child
class OrderStatus(str, Enum):
    created = "created"
    processing = "processing"
    shipped = "shipped"
    delivered = "delivered"
    cancelled = "cancelled" # we cant use D in CRUD for B2B


class OrderCreate(BaseModel): # C
    customer_id: str = Field(..., min_length=1, description="customer reference")
    product_sku: str = Field(..., min_length=1, description="SKU product")
    quantity: int = Field(..., ge=1, le=1_000, description="Quantity (1-100)")


class OrderUpdate(BaseModel): # U
    # Partial update
    status: Optional[OrderStatus] = Field(None, description="Updated order status")
    quantity: Optional[int] = Field(None, ge=1, le=1_000, description="Updated quantity (1..1000)")


class OrderOut(BaseModel): # R
    order_id: str
    status: OrderStatus
    customer_id: str
    product_sku: str
    quantity: int
    created_at: datetime
    updated_at: datetime


def new_order_id() -> str:
    # UUIDs are safe, non-guessable identifiers for external exposure.
    return str(uuid4())