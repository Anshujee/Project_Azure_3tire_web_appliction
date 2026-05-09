# ═══════════════════════════════════════════════
# AZURE SQL
# ═══════════════════════════════════════════════

# ── SQL Server ─────────────────────────────────
# The server is the parent resource — databases live inside it
# Name must be globally unique — used as DNS: sql-azureshop-dev.database.windows.net
resource "azurerm_mssql_server" "main" {
  name                         = "sql-${var.project}-${var.environment}"
  location                     = var.sql_location
  resource_group_name          = var.resource_group_name
  version                      = "12.0"   # SQL Server 2019 engine
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  tags                         = var.tags

  # Minimum TLS version — reject connections below 1.2
  minimum_tls_version = "1.2"

  # Azure AD authentication alongside SQL auth
  azuread_administrator {
    login_username              = "AzureAD Admin"
    object_id                   = data.azurerm_client_config.current.object_id
    azuread_authentication_only = false   # Allow both SQL and Azure AD auth
  }
}

# Read the current Azure client config — used to set the AD admin above
data "azurerm_client_config" "current" {}

# ── SQL Databases ──────────────────────────────
# Users Database — stores user accounts and authentication data
resource "azurerm_mssql_database" "users" {
  name         = "db-users"
  server_id    = azurerm_mssql_server.main.id
  sku_name     = var.sql_sku
  tags         = var.tags

  # Transparent Data Encryption (TDE) — encrypts data at rest
  # Enabled by default in Azure SQL — no extra config needed
  # Azure manages the encryption key automatically

  # Point-in-time restore retention
  threat_detection_policy {
    state = "Enabled"   # Azure Defender for SQL — detects suspicious queries
  }
}

# Orders Database — stores order history and transaction data
resource "azurerm_mssql_database" "orders" {
  name      = "db-orders"
  server_id = azurerm_mssql_server.main.id
  sku_name  = var.sql_sku
  tags      = var.tags

  threat_detection_policy {
    state = "Enabled"
  }
}

# ── SQL Firewall Rules ─────────────────────────
# Block all internet access — only allow specific sources

# Allow traffic from AKS subnet (10.1.0.0/16)
# AKS nodes have IPs in this range — microservices connect from here
resource "azurerm_mssql_firewall_rule" "allow_aks" {
  name             = "allow-aks-subnet"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "10.1.0.0"
  end_ip_address   = "10.1.255.255"
}

# Special rule: 0.0.0.0 to 0.0.0.0 = allow Azure internal services
# Required for Azure DevOps pipelines and Azure Monitor to connect
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ── SQL Security Alert Policy (Defender for SQL) ─
resource "azurerm_mssql_server_security_alert_policy" "main" {
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mssql_server.main.name
  state               = "Enabled"

  # Alert on: SQL injection, brute force, anomalous access patterns
  disabled_alerts = []

  # Email alerts to the subscription admin
  email_account_admins = true
}


# ═══════════════════════════════════════════════
# AZURE COSMOS DB
# ═══════════════════════════════════════════════

# ── Cosmos DB Account ──────────────────────────
# Account is the top-level resource — databases and containers live inside
# Name must be globally unique — used as DNS: cosmos-azureshop-dev.documents.azure.com
resource "azurerm_cosmosdb_account" "main" {
  name                = "cosmos-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"    # Only option available
  kind                = "GlobalDocumentDB"  # SQL API (document/JSON storage)
  tags                = var.tags

  # Automatic failover: if primary region goes down, Azure promotes a replica
  automatic_failover_enabled = true

  # Free tier: first 1000 RU/s and 25GB storage free per account
  # Only 1 free tier account per subscription allowed
  free_tier_enabled = false

  # Consistency level — controls read/write behaviour across regions
  # Session: reads always see your own writes (default, best for most apps)
  # Strong: all reads see latest write (slow, expensive)
  # Eventual: fastest but reads may be stale
  consistency_policy {
    consistency_level = var.cosmos_consistency_level
  }

  # At least one geo_location required — defines where data is stored
  geo_location {
    location          = var.location
    failover_priority = 0   # 0 = primary write region
  }

  # Allow only AKS subnet to access Cosmos DB
  virtual_network_rule {
    id = var.aks_subnet_id
  }

  # Disable public network access — only VNet traffic allowed
  is_virtual_network_filter_enabled = true
  public_network_access_enabled     = false
}

# ── Cosmos DB Database ─────────────────────────
resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "azureshop-db"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name

  # Throughput shared across all containers in this database
  # 400 RU/s = minimum, sufficient for dev
  throughput = 400
}

# ── Cosmos DB Container: products ─────────────
resource "azurerm_cosmosdb_sql_container" "products" {
  name                = "products"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name

  # Partition key — Cosmos DB distributes data across partitions using this field
  # /categoryId means products are partitioned by category (good for product queries)
  partition_key_path    = "/categoryId"
  partition_key_version = 1

  indexing_policy {
    indexing_mode = "consistent"   # Index updated synchronously on every write

    # Index all fields by default
    included_path {
      path = "/*"
    }
  }
}

# ── Cosmos DB Container: cart ──────────────────
resource "azurerm_cosmosdb_sql_container" "cart" {
  name                = "cart"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name

  # /userId means each user's cart is in its own partition
  # Cart queries are always by userId so this is the ideal partition key
  partition_key_path    = "/userId"
  partition_key_version = 1

  # Cart items expire automatically after 7 days (TTL = Time To Live)
  # -1 = use per-document TTL; set ttl on document to override
  default_ttl = 604800   # 7 days in seconds

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }
}


# ═══════════════════════════════════════════════
# AZURE REDIS CACHE
# ═══════════════════════════════════════════════

resource "azurerm_redis_cache" "main" {
  name                = "redis-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.redis_capacity
  family              = "C"          # C = Basic/Standard family. P = Premium
  sku_name            = var.redis_sku_name
  tags                = var.tags

  # Disable non-SSL port 6379 — force all connections over TLS port 6380
  enable_non_ssl_port = false

  # Minimum TLS version
  minimum_tls_version = "1.2"

  # Redis configuration
  redis_configuration {
    # Enable RDB persistence — saves snapshot every 60 seconds if 1000 keys changed
    # Protects against data loss on restart
    rdb_backup_enabled            = false   # Requires Premium SKU for actual file backup
    maxmemory_reserved            = 50      # MB reserved for non-cache use (prevents OOM)
    maxmemory_delta               = 50
    maxmemory_policy              = "volatile-lru"
    # volatile-lru = evict keys with TTL set, using LRU algorithm
    # Good for a cache where only some keys have expiration (session keys)
  }

  # Patch window — Redis restarts for patches during this window
  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 2   # 2 AM UTC = off-peak for most regions
  }
}
