import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from app.db import get_container, is_connected

router = APIRouter()

MOCK_PRODUCTS = [
    {"id": "1", "name": "Laptop Pro 15", "description": "High performance laptop", "price": 1299.99, "categoryId": "Electronics", "stock": 10, "imageUrl": ""},
    {"id": "2", "name": "Wireless Mouse", "description": "Ergonomic wireless mouse", "price": 29.99, "categoryId": "Electronics", "stock": 50, "imageUrl": ""},
    {"id": "3", "name": "Mechanical Keyboard", "description": "RGB mechanical keyboard", "price": 89.99, "categoryId": "Electronics", "stock": 30, "imageUrl": ""},
    {"id": "4", "name": "USB-C Hub", "description": "7-in-1 USB-C hub", "price": 49.99, "categoryId": "Electronics", "stock": 25, "imageUrl": ""},
    {"id": "5", "name": "Monitor 27\"", "description": "4K IPS display", "price": 399.99, "categoryId": "Electronics", "stock": 15, "imageUrl": ""},
]

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
        return [p for p in MOCK_PRODUCTS if not category or p["categoryId"] == category]

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
        match = next((p for p in MOCK_PRODUCTS if p["id"] == product_id), None)
        if not match:
            raise HTTPException(status_code=404, detail="Product not found")
        return match

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
