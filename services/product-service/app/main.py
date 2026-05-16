from contextlib import asynccontextmanager
from datetime import datetime, timezone

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.responses import Response

from app.db import init_db, is_connected
from app.routes.products import router as products_router
from app.telemetry import get_metrics, setup_telemetry

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    setup_telemetry(app)
    yield


app = FastAPI(title="Product Service", version="1.0.0", lifespan=lifespan)


@app.get("/health")
def health():
    return {
        "status": "ok" if is_connected() else "degraded",
        "service": "product-service",
        "db": "connected" if is_connected() else "disconnected",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/metrics")
def metrics():
    data, content_type = get_metrics()
    return Response(content=data, media_type=content_type)


app.include_router(products_router, prefix="/products", tags=["products"])
