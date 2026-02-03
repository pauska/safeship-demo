using Microsoft.EntityFrameworkCore;
using SafeShip.Models;

namespace SafeShip.Data
{
    public class SafeShipDbContext(DbContextOptions<SafeShipDbContext> options) : DbContext(options)
    {
        public DbSet<Product> Products => Set<Product>();
    }
}
