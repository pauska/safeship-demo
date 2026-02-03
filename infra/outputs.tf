# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

# -----------------------------------------------------------------------------
# Managed Identities
# -----------------------------------------------------------------------------

output "app_identity_client_id" {
  description = "Client ID of the application runtime managed identity"
  value       = azurerm_user_assigned_identity.app.client_id
}

output "app_identity_principal_id" {
  description = "Principal ID of the application runtime managed identity"
  value       = azurerm_user_assigned_identity.app.principal_id
}

output "app_identity_id" {
  description = "Resource ID of the application runtime managed identity"
  value       = azurerm_user_assigned_identity.app.id
}

output "github_identity_client_id" {
  description = "Client ID of the GitHub Actions managed identity"
  value       = var.github_repository != "" ? azurerm_user_assigned_identity.github[0].client_id : null
}

output "github_identity_principal_id" {
  description = "Principal ID of the GitHub Actions managed identity"
  value       = var.github_repository != "" ? azurerm_user_assigned_identity.github[0].principal_id : null
}

output "github_identity_id" {
  description = "Resource ID of the GitHub Actions managed identity"
  value       = var.github_repository != "" ? azurerm_user_assigned_identity.github[0].id : null
}

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

output "acr_login_server" {
  description = "Login server URL for the container registry"
  value       = module.container_registry.resource.login_server
}

output "acr_name" {
  description = "Name of the container registry"
  value       = module.container_registry.name
}

# -----------------------------------------------------------------------------
# Container App
# -----------------------------------------------------------------------------

output "container_app_url" {
  description = "URL of the deployed container app"
  value       = "https://${azurerm_container_app.main.ingress[0].fqdn}"
}

output "container_app_name" {
  description = "Name of the container app"
  value       = azurerm_container_app.main.name
}

# -----------------------------------------------------------------------------
# SQL Database
# -----------------------------------------------------------------------------

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL server"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the SQL database"
  value       = azurerm_mssql_database.main.name
}

output "sql_connection_string" {
  description = "SQL connection string template (uses Managed Identity)"
  value       = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.main.name};Authentication=Active Directory Managed Identity;User Id=${azurerm_user_assigned_identity.app.client_id};Encrypt=True;TrustServerCertificate=False;"
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Monitoring
# -----------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.log_analytics.resource_id
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------------

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.key_vault.uri
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.key_vault.name
}

# -----------------------------------------------------------------------------
# GitHub Actions OIDC Configuration
# -----------------------------------------------------------------------------

output "github_actions_oidc_config" {
  description = "Configuration values for GitHub Actions OIDC authentication"
  value = var.github_repository != "" ? {
    azure_client_id       = azurerm_user_assigned_identity.github[0].client_id
    azure_tenant_id       = data.azurerm_client_config.current.tenant_id
    azure_subscription_id = var.subscription_id
    acr_login_server      = module.container_registry.resource.login_server
    container_app_name    = azurerm_container_app.main.name
    resource_group        = azurerm_resource_group.main.name
  } : null
}

# -----------------------------------------------------------------------------
# Networking (Hub-Spoke)
# -----------------------------------------------------------------------------

output "vnet_id" {
  description = "ID of the spoke VNet"
  value       = azurerm_virtual_network.spoke.id
}

output "vnet_name" {
  description = "Name of the spoke VNet"
  value       = azurerm_virtual_network.spoke.name
}

output "container_apps_subnet_id" {
  description = "ID of the Container Apps subnet"
  value       = azurerm_subnet.container_apps.id
}

output "private_endpoints_subnet_id" {
  description = "ID of the private endpoints subnet"
  value       = azurerm_subnet.private_endpoints.id
}
