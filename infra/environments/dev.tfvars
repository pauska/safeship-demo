# Development Environment Configuration
# Copy this file and fill in your values

subscription_id     = "" # Your Azure subscription ID
sql_admin_login     = "" # Azure AD user/group for SQL admin (e.g., "admin@contoso.com")
sql_admin_object_id = "" # Azure AD object ID of the SQL admin

# Optional overrides
app_name          = "safeship"
environment       = "dev"
location          = "norwayeast"
github_repository = "" # e.g., "myorg/safeship" for GitHub Actions OIDC

# SQL configuration (smaller for dev)
sql_sku         = "S0"
sql_max_size_gb = 10

tags = {
  CostCenter = "Development"
}
