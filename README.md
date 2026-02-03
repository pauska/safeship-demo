# SafeShip

ASP.NET Core 9 MVC application with Entity Framework Core 9, deployed to Azure Container Apps with Azure SQL Hyperscale.

## Prerequisites

- [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (for deployment)
- [Terraform](https://www.terraform.io/downloads) >= 1.9.0 (for infrastructure)

## Local Development

### Quick Start with Docker Compose

The easiest way to run the app locally with a full SQL Server database:

```bash
# Start SQL Server and the app
docker compose up -d

# View application logs
docker compose logs -f app

# Stop everything (preserves data)
docker compose down

# Stop and remove all data
docker compose down -v
```

Once running, access the app at: **http://localhost:8080**

### Run with .NET CLI

For development without Docker:

```bash
cd src/SafeShip

# Restore dependencies
dotnet restore

# Run the application
dotnet run
```

> **Note:** Running without Docker Compose requires a SQL Server instance. Update the connection string in `appsettings.Development.json`.

### Build Docker Image

```bash
cd src/SafeShip

# Build the image
docker build -t safeship:local .

# Run standalone (requires external SQL Server)
docker run -p 8080:8080 safeship:local
```

## Project Structure

```
├── src/SafeShip/           # ASP.NET Core MVC application
│   ├── Controllers/        # MVC controllers
│   ├── Data/               # EF Core DbContext
│   ├── Models/             # Entity models
│   ├── Views/              # Razor views
│   ├── Program.cs          # App configuration
│   └── Dockerfile          # Container build
├── infra/                  # Terraform infrastructure (Azure)
├── scripts/                # Utility scripts
│   └── init-db.sh          # Database initialization
├── .github/
│   ├── workflows/          # CI/CD pipelines
│   └── copilot-instructions.md
└── docker-compose.yml      # Local development stack
```

## Infrastructure

The `infra/` directory contains Terraform configuration for Azure deployment:

- **Azure Container Apps** - Application hosting with zone redundancy
- **Azure SQL Hyperscale** - Database with zone-redundant HA
- **Azure Container Registry** - Private container images
- **Azure Key Vault** - Secrets management
- **Log Analytics & Application Insights** - Observability
- **Virtual Network** - Hub-spoke topology with private endpoints

### Deploy Infrastructure

```bash
cd infra

# Initialize Terraform
terraform init

# Plan changes
terraform plan -var="environment=dev" -var="location=norwayeast"

# Apply changes
terraform apply -var="environment=dev" -var="location=norwayeast"
```

## CI/CD

GitHub Actions workflows in `.github/workflows/`:

- **ci-cd.yml** - Build, test, and deploy on push to `main`
- **infrastructure.yml** - Terraform plan/apply for infrastructure changes

Authentication uses OIDC with Azure - no secrets stored in GitHub.

## Architecture Principles

- **Managed Identity** - No passwords in connection strings (production)
- **Private Networking** - All Azure resources use private endpoints
- **Zone Redundancy** - High availability for production workloads
- **Infrastructure as Code** - Terraform with Azure Verified Modules (AVM)

## License

MIT
