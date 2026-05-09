import os
from azure.cosmos import CosmosClient, exceptions

_client = None
_container = None
_connected = False


def init_db():
    global _client, _container, _connected

    endpoint = os.getenv("COSMOS_ENDPOINT")
    key = os.getenv("COSMOS_KEY")

    if not endpoint or not key:
        print("[db] COSMOS_ENDPOINT or COSMOS_KEY not set — running without database")
        return

    try:
        _client = CosmosClient(endpoint, key)
        db = _client.get_database_client(os.getenv("COSMOS_DATABASE", "azureshop-db"))
        _container = db.get_container_client(os.getenv("COSMOS_CONTAINER", "products"))
        db.read()  # test the connection
        _connected = True
        print("[db] Connected to Cosmos DB")
    except Exception as e:
        print(f"[db] Could not connect to Cosmos DB: {e}")
        print("[db] Service will start in degraded mode")


def get_container():
    return _container


def is_connected() -> bool:
    return _connected
