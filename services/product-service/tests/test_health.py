from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_returns_200():
    response = client.get("/health")
    assert response.status_code == 200


def test_health_contains_service_name():
    response = client.get("/health")
    data = response.json()
    assert data["service"] == "product-service"
    assert data["status"] in ["ok", "degraded"]
