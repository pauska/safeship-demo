# SafeShip - AI Coding Agent Instructions

## Project Overview

SafeShip is an ASP.NET Core 9 MVC application with Entity Framework Core 9 for data access. Deploys to **Azure Container Apps** with **Azure SQL Hyperscale**.

## Architecture

The project must follow the Microsoft Cloud Adptation Framework, as well as the Azure Well-Architected Framework.
Security, scalability, high availability, and operational excellence are top priorities.
The workload will be running in a spoke, in a Hub-Spoke network topology.


```
src/SafeShip/
├── Controllers/          # MVC controllers (inherit Controller)
├── Data/                 # EF Core DbContext (SafeShipDbContext)
├── Models/               # Entity models with DataAnnotations
├── Views/                # Razor views by controller + Shared/
├── Program.cs            # App config and middleware pipeline
├── Dockerfile            # Multi-stage container build
└── appsettings.json      # Configuration (connection strings)
infra/                    # Terraform infrastructure (when created)
.github/workflows/        # CI/CD pipelines (when created)
```

## Key requirements

- Always run in a highly available configuration such as zone redundancy.
- Use managed identity wherever possible
- No secrets in code or config files - use Azure Key Vault if needed
- No stateful storage in the compute environment - containers should be treated as ephemeral
- Use Azure Monitor for observability - Application Insights for app monitoring and Log Analytics for infrastructure monitoring
- Use a clear naming convention for all resources: `<resource-type(short)>-safeship-<environment>-<location>`. Example: `sqldb-safeship-customerdata-prod-norwayeast`
- Enforce protection of production data - use features like Azure SQL TDE, soft delete, and purge protection. Ensure backups are retained according to best practices.
- Disable all public network access to resources unless absolutely necessary. Use private endpoints wherever possible. Use NSG's and UDR's to control inbound and outbound traffic.


## Code Conventions

### Entity Framework
- **Target**: .NET 9, EF Core 9, namespace `SafeShip.*`
- **DbContext**: Primary constructor syntax
  ```csharp
  public class SafeShipDbContext(DbContextOptions<SafeShipDbContext> options) : DbContext(options)
  ```
- **DbSet**: Expression-bodied members
  ```csharp
  public DbSet<Product> Products => Set<Product>();
  ```
- **Connection**: `Configuration.GetConnectionString("DefaultConnection")` with `UseSqlServer()`

### Controllers
- Constructor injection for `SafeShipDbContext`
- CRUD action names: `Index`, `Create`, `Edit`, `Delete`, `DeleteConfirmed`
- POST actions: `[HttpPost]`, `[ValidateAntiForgeryToken]`
- Validate: `if (ModelState.IsValid)` before DB writes
- Redirect: `return RedirectToAction(nameof(Index));`
- Not found: `if (entity == null) return NotFound();`

### Models
- Namespace: `SafeShip.Models`
- Validation: `[Required]`, `[Range]`, `[StringLength]` from `System.ComponentModel.DataAnnotations`
- Initialize strings: `public string Name { get; set; } = string.Empty;`

## Azure & Infrastructure

### Identity & Authentication
- **Managed Identity everywhere** - no passwords in connection strings
- SQL connection (production): `Server=tcp:<server>.database.windows.net;Database=SafeShip;Authentication=Active Directory Managed Identity;`
- Container Apps use User-Assigned Managed Identity for ACR, SQL, Key Vault

### Terraform (when using infra/)
- Use **Azure Verified Modules (AVM)** from `br/public:avm/res/` registry
- Example modules:
  - `Azure/avm-res-containerregistry-registry/azurerm`
  - `Azure/avm-res-keyvault-vault/azurerm`
  - `Azure/avm-res-operationalinsights-workspace/azurerm`
  - `Azure/avm-res-storage-storage-account/azurerm`

### CI/CD (GitHub Actions)
- Use OIDC with `azure/login@v2` - no stored secrets
- Environment variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ACR_LOGIN_SERVER`

## Developer Workflow

```bash
# Run locally
cd src/SafeShip && dotnet run

# EF migrations
dotnet ef migrations add <Name>
dotnet ef database update

# Container build
docker build -t safeship:local .
docker run -p 8080:8080 safeship:local
```

## Important Notes

- Health endpoint: `/health` (required for Container Apps probes)
- Logging: Use `ILogger<T>` injection → flows to Application Insights
- App Insights: Added via `builder.Services.AddApplicationInsightsTelemetry();`
- **Async preferred**: Use `async/await` with `ToListAsync()`, `SaveChangesAsync()` for new code
