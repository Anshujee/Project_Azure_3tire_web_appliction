from contextlib import asynccontextmanager
from datetime import datetime, timezone

from dotenv import load_dotenv
from fastapi import FastAPI

from app.db import init_db, is_connected
from app.routes.products import router as products_router

load_dotenv()


# lifespan replaces the deprecated @app.on_event("startup")
# runs init_db() once when the server starts, then yields to serve requests
@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
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


app.include_router(products_router, prefix="/products", tags=["products"])
