# ─────────────────────────────────────────────
# Local names — keeps the AppGW resource block readable
# AppGW uses string names (not IDs) to cross-reference internal components
# ─────────────────────────────────────────────
locals {
  frontend_ip_name        = "appgw-frontend-ip"
  frontend_port_http_name = "port-80"
  frontend_port_https_name = "port-443"
  backend_pool_name       = "aks-backend-pool"
  backend_settings_name   = "aks-backend-settings"
  http_listener_name      = "http-listener"
  https_listener_name     = "https-listener"
  redirect_rule_name      = "http-to-https-redirect"
  https_routing_rule_name = "https-routing-rule"
  redirect_config_name    = "http-to-https-redirect-config"
  ssl_cert_name           = "appgw-ssl-cert"
}

# ─────────────────────────────────────────────
# Public IP — static, standard SKU required for WAF v2
# ─────────────────────────────────────────────
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"    # Must be Static for Application Gateway
  sku                 = "Standard"  # Must be Standard to match WAF_v2 SKU
  tags                = var.tags
}

# ─────────────────────────────────────────────
# WAF Policy — OWASP 3.2, Prevention mode
# Modern approach: define WAF as a separate resource and attach to AppGW
# ─────────────────────────────────────────────
resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-policy-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Core rule sets — standard protection rules maintained by OWASP
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"   # Latest stable OWASP Core Rule Set
      # Covers: SQL injection, XSS, command injection, path traversal, etc.
    }

    # Microsoft Bot Manager — blocks known malicious bots
    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.0"
    }
  }

  policy_settings {
    enabled                     = true
    mode                        = var.waf_mode  # Prevention = block; Detection = log only
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }
}

# ─────────────────────────────────────────────
# Application Gateway — WAF v2 SKU
# ─────────────────────────────────────────────
resource "azurerm_application_gateway" "main" {
  name                = "appgw-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Attach the WAF policy defined above
  firewall_policy_id = azurerm_web_application_firewall_policy.main.id

  # ── SKU ─────────────────────────────────────
  sku {
    name = "WAF_v2"     # WAF_v2 = includes WAF + autoscaling + zone redundancy
    tier = "WAF_v2"
  }

  # Autoscaling — WAF_v2 supports autoscaling instead of fixed capacity
  autoscale_configuration {
    min_capacity = var.capacity      # 1 for dev, 2 for prod
    max_capacity = 5
  }

  # ── Network ──────────────────────────────────
  # Which subnet the AppGW lives in
  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.appgw_subnet_id
  }

  # ── Frontend ─────────────────────────────────
  # The public IP the AppGW listens on
  frontend_ip_configuration {
    name                 = local.frontend_ip_name
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # Port 80 — HTTP (redirected to HTTPS)
  frontend_port {
    name = local.frontend_port_http_name
    port = 80
  }

  # Port 443 — HTTPS (SSL termination happens here)
  frontend_port {
    name = local.frontend_port_https_name
    port = 443
  }

  # ── Backend Pool ─────────────────────────────
  # Points to AKS ingress controller — populated after Phase 6
  backend_address_pool {
    name         = local.backend_pool_name
    ip_addresses = var.aks_ingress_ip != "" ? [var.aks_ingress_ip] : []
  }

  # How AppGW communicates with the backend (AKS ingress)
  backend_http_settings {
    name                  = local.backend_settings_name
    cookie_based_affinity = "Disabled"  # No sticky sessions — let AKS handle load balancing
    port                  = 80          # AppGW → AKS uses HTTP internally (SSL terminates at AppGW)
    protocol              = "Http"
    request_timeout       = 30          # Seconds before AppGW gives up waiting for backend response
    pick_host_name_from_backend_address = false
  }

  # ── SSL Certificate ───────────────────────────
  # For dev: use a self-signed certificate stored in Key Vault
  # For prod: replace with an Azure-managed certificate from Key Vault
  #
  # To add a real cert, uncomment and fill:
  # ssl_certificate {
  #   name                = local.ssl_cert_name
  #   key_vault_secret_id = "<key-vault-cert-secret-id>"
  # }

  # ── Listeners ────────────────────────────────
  # HTTP listener — receives traffic on port 80
  http_listener {
    name                           = local.http_listener_name
    frontend_ip_configuration_name = local.frontend_ip_name
    frontend_port_name             = local.frontend_port_http_name
    protocol                       = "Http"
  }

  # HTTPS listener — receives traffic on port 443 after SSL termination
  # Uncomment when a real SSL cert is added:
  # http_listener {
  #   name                           = local.https_listener_name
  #   frontend_ip_configuration_name = local.frontend_ip_name
  #   frontend_port_name             = local.frontend_port_https_name
  #   protocol                       = "Https"
  #   ssl_certificate_name           = local.ssl_cert_name
  # }

  # ── Routing Rules ────────────────────────────

  # Route HTTP traffic directly to AKS backend
  # HTTP→HTTPS redirect requires a separate HTTPS listener with a valid SSL cert
  # SSL cert will be added in Phase 6 when AKS ingress IP is available
  request_routing_rule {
    name                       = local.https_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.http_listener_name
    backend_address_pool_name  = local.backend_pool_name
    backend_http_settings_name = local.backend_settings_name
    priority                   = 100
  }

  # ── Zones ────────────────────────────────────
  # Deploy across availability zones for high availability
  zones = ["1", "2", "3"]
}
