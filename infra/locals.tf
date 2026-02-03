# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  # Common tags applied to all resources
  tags = merge(
    {
      Application = var.app_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}
