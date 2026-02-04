using Microsoft.EntityFrameworkCore;
using SafeShip.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Support SQL_CONNECTION_STRING environment variable for Kubernetes/container deployments
// Falls back to appsettings.json ConnectionStrings:DefaultConnection for local development
var connectionString = Environment.GetEnvironmentVariable("SQL_CONNECTION_STRING")
    ?? builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("SQL connection string not configured. Set SQL_CONNECTION_STRING environment variable or configure ConnectionStrings:DefaultConnection.");

builder.Services.AddDbContext<SafeShipDbContext>(options =>
    options.UseSqlServer(connectionString));

builder.Services.AddControllersWithViews();

// Add Application Insights telemetry
builder.Services.AddApplicationInsightsTelemetry();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// Health check endpoint for Container Apps
app.MapGet("/health", () => Results.Ok("Healthy"));

app.Run();
