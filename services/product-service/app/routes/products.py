import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from app.db import get_container, is_connected

router = APIRouter()


# ── Request / Response models ────────────────────────────────────────────────
class CreateProductRequest(BaseModel):
    name: str
    description: str
    price: float
    categoryId: str          # partition key — required for Cosmos DB writes
    stock: int
    imageUrl: str = ""


class ProductResponse(BaseModel):
    id: str
    name: str
    description: str
    price: float
    categoryId: str
    stock: int
    imageUrl: str


# ── Routes ───────────────────────────────────────────────────────────────────

# GET /products?category=Electronics
@router.get("/", response_model=list[ProductResponse])
async def list_products(category: Optional[str] = Query(None)):
    if not is_connected():
        raise HTTPException(status_code=503, detail="Database not available")

    container = get_container()
    try:
        if category:
            # Partition key query — efficient, stays within one partition
            items = list(container.query_items(
                query="SELECT * FROM c WHERE c.categoryId = @category",
                parameters=[{"name": "@category", "value": category}],
                partition_key=category,
            ))
        else:
            # Cross-partition query — scans all partitions, fine for dev
            items = list(container.query_items(
                query="SELECT * FROM c",
                enable_cross_partition_query=True,
            ))
        return items
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# GET /products/{id}?categoryId=Electronics
@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(product_id: str, categoryId: Optional[str] = Query(None)):
    if not is_connected():
        raise HTTPException(status_code=503, detail="Database not available")

    container = get_container()
    try:
        if categoryId:
            # Point read — fastest Cosmos operation (uses both id + partition key)
            item = container.read_item(item=product_id, partition_key=categoryId)
        else:
            # Cross-partition query when categoryId not provided
            results = list(container.query_items(
                query="SELECT * FROM c WHERE c.id = @id",
                parameters=[{"name": "@id", "value": product_id}],
                enable_cross_partition_query=True,
            ))
            if not results:
                raise HTTPException(status_code=404, detail="Product not found")
            item = results[0]
        return item
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# POST /products
@router.post("/", response_model=ProductResponse, status_code=201)
async def create_product(body: CreateProductRequest):
    if not is_connected():
        raise HTTPException(status_code=503, detail="Database not available")

    container = get_container()
    try:
        item = {
            "id": str(uuid.uuid4()),
            **body.model_dump(),
            "createdAt": datetime.now(timezone.utc).isoformat(),
        }
        container.create_item(item)
        return item
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
