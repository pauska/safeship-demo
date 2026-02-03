# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "sql_admin_login" {
  description = "Azure AD login name for SQL admin (e.g., admin@contoso.com or group name)"
  type        = string
}

variable "sql_admin_object_id" {
  description = "Azure AD object ID of the SQL admin user or group"
  type        = string
}

# -----------------------------------------------------------------------------
# Optional Variables with Defaults
# -----------------------------------------------------------------------------

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = "safeship"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "norwayeast"
}

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo' for OIDC federation (leave empty to skip)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# SQL Database Configuration
# -----------------------------------------------------------------------------

variable "sql_sku" {
  description = "Azure SQL Database SKU name"
  type        = string
  default     = "S0"
}

variable "sql_max_size_gb" {
  description = "Maximum size of the SQL database in GB"
  type        = number
  default     = 10
}

# -----------------------------------------------------------------------------
# Networking (Hub-Spoke)
# -----------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the spoke VNet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "container_apps_subnet_prefix" {
  description = "Address prefix for Container Apps subnet (requires /23 or larger)"
  type        = string
  default     = "10.1.0.0/23"
}

variable "private_endpoints_subnet_prefix" {
  description = "Address prefix for private endpoints subnet"
  type        = string
  default     = "10.1.2.0/24"
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
