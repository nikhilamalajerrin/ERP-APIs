import logging
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette import status

from app.routes import orders, health
from app.services.order_service import OrderNotFound


# Logging Configuration

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
)

logger = logging.getLogger("order-api")


# FastAPI

app = FastAPI(
    title="Secure B2B Order API",
    description="Order status API exposed via Azure API Management (APIM)",
    version="1.0.0",
)


# CORS Middleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global Exception Handlers
@app.exception_handler(OrderNotFound)
async def order_not_found_handler(request: Request, exc: OrderNotFound):
    logger.warning(f"Order not found: {exc}")
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={
            "error": "ORDER_NOT_FOUND",
            "message": str(exc),
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    logger.warning(f"Validation error: {exc}")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": "VALIDATION_ERROR",
            "details": exc.errors(),
        },
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unexpected error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "INTERNAL_SERVER_ERROR",
            "message": "An unexpected error occurred.",
        },
    )


# Register Routers
app.include_router(orders.router)
app.include_router(health.router)


# Root Endpoint
@app.get("/")
def root():
    logger.info("Root endpoint accessed")
    return {
        "message": "Order API is running",
        "docs": "/docs",
        "health": "/health",
    }