# Production Environment Configuration
# Copy this file and fill in your values

subscription_id     = "" # Your Azure subscription ID
sql_admin_login     = "" # Azure AD user/group for SQL admin
sql_admin_object_id = "" # Azure AD object ID of the SQL admin

# Optional overrides
app_name          = "safeship"
environment       = "prod"
location          = "norwayeast"
github_repository = "" # e.g., "myorg/safeship" for GitHub Actions OIDC

# SQL configuration (larger for prod - consider Hyperscale for production workloads)
sql_sku         = "S2"
sql_max_size_gb = 50

tags = {
  CostCenter  = "Production"
  Criticality = "High"
}
