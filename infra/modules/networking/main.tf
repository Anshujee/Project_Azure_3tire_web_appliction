# ─────────────────────────────────────────────
# Virtual Network
# ─────────────────────────────────────────────
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

# ─────────────────────────────────────────────
# Subnets
# ─────────────────────────────────────────────
resource "azurerm_subnet" "aks" {
  name                 = "subnet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_cidr]

  # Service endpoints allow Azure services to identify traffic coming from this subnet
  # Required for Cosmos DB and SQL VNet rules — without this, the VNet rule is rejected
  service_endpoints = [
    "Microsoft.AzureCosmosDB",
    "Microsoft.Sql"
  ]
}

resource "azurerm_subnet" "db" {
  name                 = "subnet-db"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.db_subnet_cidr]
}

resource "azurerm_subnet" "appgw" {
  name                 = "subnet-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.appgw_subnet_cidr]
}

# Azure Bastion requires the subnet to be named exactly "AzureBastionSubnet"
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.bastion_subnet_cidr]
}

# ─────────────────────────────────────────────
# Network Security Groups
# ─────────────────────────────────────────────

# NSG — AKS Subnet
resource "azurerm_network_security_group" "aks" {
  name                = "nsg-aks-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Allow HTTPS inbound — for AKS API server communication
  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow all traffic within the VNet (pod-to-pod, node-to-node)
  security_rule {
    name                       = "Allow-VNet-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow Azure Load Balancer health probes
  security_rule {
    name                       = "Allow-LoadBalancer-Inbound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG — Database Subnet
resource "azurerm_network_security_group" "db" {
  name                = "nsg-db-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Allow SQL Server traffic only from AKS subnet
  security_rule {
    name                       = "Allow-SQL-From-AKS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = var.aks_subnet_cidr
    destination_address_prefix = "*"
  }

  # Allow Redis traffic only from AKS subnet
  security_rule {
    name                       = "Allow-Redis-From-AKS"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6380"
    source_address_prefix      = var.aks_subnet_cidr
    destination_address_prefix = "*"
  }

  # Allow Cosmos DB / HTTPS traffic only from AKS subnet
  security_rule {
    name                       = "Allow-HTTPS-From-AKS"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.aks_subnet_cidr
    destination_address_prefix = "*"
  }

  # Deny all other inbound — databases not reachable from internet
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG — Application Gateway Subnet
resource "azurerm_network_security_group" "appgw" {
  name                = "nsg-appgw-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Allow HTTP from internet
  security_rule {
    name                       = "Allow-HTTP-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow HTTPS from internet
  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Required by Azure for Application Gateway health probes and management
  security_rule {
    name                       = "Allow-AppGW-Management"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  # Allow Azure Load Balancer
  security_rule {
    name                       = "Allow-LoadBalancer-Inbound"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

# NSG — Bastion Subnet
resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-bastion-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Allow HTTPS from internet — users connect to Bastion via browser on 443
  security_rule {
    name                       = "Allow-HTTPS-From-Internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow Azure Bastion control plane traffic
  security_rule {
    name                       = "Allow-GatewayManager"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  # Allow Bastion to connect to VMs via SSH (port 22)
  security_rule {
    name                       = "Allow-SSH-To-VNet"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow Bastion to connect to VMs via RDP (port 3389)
  security_rule {
    name                       = "Allow-RDP-To-VNet"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow Bastion to reach Azure cloud services
  security_rule {
    name                       = "Allow-HTTPS-To-AzureCloud"
    priority                   = 300
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
}

# ─────────────────────────────────────────────
# Associate NSGs with Subnets
# ─────────────────────────────────────────────
resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

# ─────────────────────────────────────────────
# Azure Bastion
# ─────────────────────────────────────────────

# Bastion requires a Public IP with Standard SKU and Static allocation
resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  name                = "bastion-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
