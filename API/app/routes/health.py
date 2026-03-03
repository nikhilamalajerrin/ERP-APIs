from fastapi import APIRouter
from datetime import datetime, timezone

router = APIRouter(tags=["health"])


@router.get("/health")
def health_check():
    """
    Basic health check endpoint.
    Used by:
    - Monitoring systems
    - Load balancers
    - CI/CD smoke tests
    """
    return {
        "status": "ok",
        "timestamp": datetime.now(timezone.utc),
    }