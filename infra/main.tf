# SafeShip Infrastructure - Azure Container Apps with SQL
# Uses Azure Verified Modules (AVM) where available

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  subscription_id = var.subscription_id
}

provider "azapi" {}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.app_name}-${var.environment}-${var.location}"
  location = var.location
  tags     = local.tags
}

# -----------------------------------------------------------------------------
# User-Assigned Managed Identity - Application Runtime
# Used by Container Apps to access SQL, Key Vault, and other Azure services
# -----------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.app_name}-app-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

# -----------------------------------------------------------------------------
# User-Assigned Managed Identity - GitHub Actions (CI/CD)
# Used by GitHub Actions to deploy to Azure via OIDC federation
# -----------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "github" {
  count               = var.github_repository != "" ? 1 : 0
  name                = "id-${var.app_name}-github-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

# Federated credential for GitHub Actions OIDC authentication
resource "azurerm_federated_identity_credential" "github" {
  count               = var.github_repository != "" ? 1 : 0
  name                = "github-actions-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.github[0].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_repository}:environment:${var.environment}"
}

# Grant GitHub identity Contributor role on resource group for deployments
resource "azurerm_role_assignment" "github_contributor" {
  count                = var.github_repository != "" ? 1 : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github[0].principal_id
}

# Grant GitHub identity AcrPush role for container image pushes
resource "azurerm_role_assignment" "github_acr_push" {
  count                = var.github_repository != "" ? 1 : 0
  scope                = module.container_registry.resource_id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github[0].principal_id
}

# -----------------------------------------------------------------------------
# Virtual Network (Hub-Spoke: This is the Spoke VNet)
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.app_name}-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.vnet_address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "container_apps" {
  name                 = "snet-container-apps"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.container_apps_subnet_prefix]

  delegation {
    name = "container-apps-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.private_endpoints_subnet_prefix]
}

# NSG for Container Apps subnet
resource "azurerm_network_security_group" "container_apps" {
  name                = "nsg-container-apps-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "container_apps" {
  subnet_id                 = azurerm_subnet.container_apps.id
  network_security_group_id = azurerm_network_security_group.container_apps.id
}

# NSG for Private Endpoints subnet
resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-private-endpoints-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

# Private DNS Zones for Private Endpoints
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone" "storage_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

# Link Private DNS Zones to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "link-keyvault"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "link-sql"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "link-acr"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  name                  = "link-storage-blob"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = local.tags
}

# -----------------------------------------------------------------------------
# Log Analytics Workspace
# -----------------------------------------------------------------------------

module "log_analytics" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "~> 0.4"

  name                = "log-${var.app_name}-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_retention_in_days = 30
}

# -----------------------------------------------------------------------------
# Application Insights
# -----------------------------------------------------------------------------

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.app_name}-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = module.log_analytics.resource_id
  application_type    = "web"
  tags                = local.tags
}

# -----------------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------------

module "key_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "~> 0.9"

  name                = "kv-${var.app_name}-${var.environment}-${var.location}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.tags

  # Security settings - disable public access
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false

  # Grant access to app managed identity
  role_assignments = {
    secrets_user = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = azurerm_user_assigned_identity.app.principal_id
    }
  }

  # Private endpoint
  private_endpoints = {
    primary = {
      name                          = "pe-kv-${var.app_name}-${var.environment}"
      subnet_resource_id            = azurerm_subnet.private_endpoints.id
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.keyvault.id]
    }
  }

  # Store Application Insights connection string
  secrets = {
    appinsights_connection_string = {
      name = "appinsights-connection-string"
    }
  }

  secrets_value = {
    appinsights_connection_string = azurerm_application_insights.main.connection_string
  }
}

# -----------------------------------------------------------------------------
# Container Registry (Premium required for Private Endpoints)
# -----------------------------------------------------------------------------

module "container_registry" {
  source  = "Azure/avm-res-containerregistry-registry/azurerm"
  version = "~> 0.4"

  name                = "cr${replace(var.app_name, "-", "")}${var.environment}${replace(var.location, "-", "")}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  sku                           = "Premium" # Required for private endpoints
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = false

  # Grant AcrPull to app managed identity
  role_assignments = {
    acr_pull = {
      role_definition_id_or_name = "AcrPull"
      principal_id               = azurerm_user_assigned_identity.app.principal_id
    }
  }

  # Private endpoint
  private_endpoints = {
    primary = {
      name                          = "pe-acr-${var.app_name}-${var.environment}"
      subnet_resource_id            = azurerm_subnet.private_endpoints.id
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.acr.id]
    }
  }
}

# -----------------------------------------------------------------------------
# Storage Account (for SQL audit logs)
# -----------------------------------------------------------------------------

module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.4"

  name                = "st${replace(var.app_name, "-", "")}${var.environment}${replace(var.location, "-", "")}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  account_tier             = "Standard"
  account_replication_type = var.environment == "prod" ? "GRS" : "LRS"
  account_kind             = "StorageV2"

  # Security settings - disable key access, use Entra ID
  shared_access_key_enabled       = false
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  # Blob container for SQL audit logs
  containers = {
    sqlaudit = {
      name                  = "sqlaudit"
      container_access_type = "private"
    }
  }

  role_assignments = {
    blob_contributor = {
      role_definition_id_or_name = "Storage Blob Data Contributor"
      principal_id               = azurerm_user_assigned_identity.app.principal_id
    }
  }

  # Private endpoint
  private_endpoints = {
    blob = {
      name                          = "pe-st-blob-${var.app_name}-${var.environment}"
      subnet_resource_id            = azurerm_subnet.private_endpoints.id
      subresource_name              = "blob"
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.storage_blob.id]
    }
  }
}

# -----------------------------------------------------------------------------
# Azure SQL Server and Database
# -----------------------------------------------------------------------------

resource "azurerm_mssql_server" "main" {
  name                          = "sql-${var.app_name}-${var.environment}-${var.location}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = local.tags

  # Azure AD-only authentication (no SQL auth)
  azuread_administrator {
    login_username              = var.sql_admin_login
    object_id                   = var.sql_admin_object_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_database" "main" {
  name                                = "sqldb-${var.app_name}-${var.environment}-${var.location}"
  server_id                           = azurerm_mssql_server.main.id
  sku_name                            = var.sql_sku
  max_size_gb                         = var.sql_max_size_gb
  zone_redundant                      = var.environment == "prod"
  storage_account_type                = var.environment == "prod" ? "Geo" : "Local"
  transparent_data_encryption_enabled = true
  tags                                = local.tags

  # Short-term backup retention (7-35 days)
  short_term_retention_policy {
    retention_days           = var.environment == "prod" ? 35 : 7
    backup_interval_in_hours = var.environment == "prod" ? 12 : 24
  }

  # Long-term backup retention for production
  dynamic "long_term_retention_policy" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      weekly_retention  = "P4W"  # 4 weeks
      monthly_retention = "P12M" # 12 months
      yearly_retention  = "P5Y"  # 5 years
      week_of_year      = 1
    }
  }
}

# Private endpoint for SQL Server
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${var.app_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-sql-${var.app_name}"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}

# -----------------------------------------------------------------------------
# Container Apps Environment (Zone Redundant, VNet Integrated)
# -----------------------------------------------------------------------------

resource "azurerm_container_app_environment" "main" {
  name                           = "cae-${var.app_name}-${var.environment}-${var.location}"
  resource_group_name            = azurerm_resource_group.main.name
  location                       = azurerm_resource_group.main.location
  log_analytics_workspace_id     = module.log_analytics.resource_id
  infrastructure_subnet_id       = azurerm_subnet.container_apps.id
  internal_load_balancer_enabled = false # Set to true for fully private
  zone_redundancy_enabled        = var.environment == "prod"
  tags                           = local.tags
}

# -----------------------------------------------------------------------------
# Container App
# -----------------------------------------------------------------------------

resource "azurerm_container_app" "main" {
  name                         = "ca-${var.app_name}-${var.environment}-${var.location}"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = module.container_registry.resource.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = var.environment == "prod" ? 2 : 0
    max_replicas = var.environment == "prod" ? 10 : 2

    container {
      name   = var.app_name
      image  = "${module.container_registry.resource.login_server}/${var.app_name}:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = var.environment == "prod" ? "Production" : "Development"
      }

      env {
        name  = "ConnectionStrings__DefaultConnection"
        value = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.main.name};Authentication=Active Directory Managed Identity;User Id=${azurerm_user_assigned_identity.app.client_id};Encrypt=True;TrustServerCertificate=False;"
      }

      env {
        name  = "ApplicationInsights__ConnectionString"
        value = azurerm_application_insights.main.connection_string
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.app.client_id
      }

      liveness_probe {
        path             = "/health"
        port             = 8080
        transport        = "HTTP"
        initial_delay    = 10
        interval_seconds = 30
      }

      readiness_probe {
        path             = "/health"
        port             = 8080
        transport        = "HTTP"
        initial_delay    = 5
        interval_seconds = 10
      }
    }
  }
}
