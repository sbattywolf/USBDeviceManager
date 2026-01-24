using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using USBDeviceManager.Data;

// Simple CI helper that ensures the Sqlite database exists and the schema is created.
// Uses the same default connection string as the server when no env var is provided.

var services = new ServiceCollection();

string? conn = Environment.GetEnvironmentVariable("DefaultConnection");
if (string.IsNullOrEmpty(conn))
{
    conn = "Data Source=simracing.db";
}

services.AddDbContext<SimRacingContext>(options => options.UseSqlite(conn));

using var sp = services.BuildServiceProvider();
using var ctx = sp.GetRequiredService<SimRacingContext>();

try
{
    Console.WriteLine($"[CI] Ensuring database at '{conn}' is created...");
    ctx.Database.EnsureCreated();
    Console.WriteLine("[CI] Database ensured (EnsureCreated completed).\n");
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"[CI] Failed to ensure database: {ex}");
    return 1;
}
