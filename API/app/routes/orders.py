from fastapi import APIRouter, status

from app.models.order import OrderCreate, OrderOut, OrderUpdate
from app.services.order_service import order_service

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post(
    "",
    response_model=OrderOut,
    status_code=status.HTTP_201_CREATED,
)
def create_order(payload: OrderCreate) -> OrderOut:
    """
    Creates a new order.
    """
    return order_service.create_order(payload)


@router.get(
    "/{order_id}",
    response_model=OrderOut,
)
def get_order(order_id: str) -> OrderOut:
    """
    Returns an order by ID.
    """
    return order_service.get_order(order_id)


@router.put(
    "/{order_id}",
    response_model=OrderOut,
)
def update_order(order_id: str, payload: OrderUpdate) -> OrderOut:
    """
    Updates an existing order (partial update supported).
    """
    return order_service.update_order(order_id, payload)