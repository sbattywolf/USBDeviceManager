// <copyright file="Program.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.OpenApi.Models;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using USBDeviceManager.Adapters;
using USBDeviceManager.Components;
using USBDeviceManager.Data;
using USBDeviceManager.Hubs;
using USBDeviceManager.Services;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

// Increase host/Microsoft logging verbosity for diagnostics
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.SetMinimumLevel(LogLevel.Debug);
builder.Logging.AddFilter("Microsoft", LogLevel.Debug);

// Add services to the container
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// Add database context
builder.Services.AddDbContext<SimRacingContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection") ?? "Data Source=simracing.db"));

// Add HTTP client for API calls
builder.Services.AddScoped<HttpClient>(sp =>
{
    var httpClient = new HttpClient
    {
        BaseAddress = new Uri("https://localhost:7001"), // Adjust port as needed
    };
    return httpClient;
});

// Add SignalR
builder.Services.AddSignalR();

// Dashboard client for UI pages (wraps HttpClient + SignalR)
builder.Services.AddScoped<USBDeviceManager.Services.DashboardClient>();

// Add API controllers with a simple validation filter for consistent errors
builder.Services.AddControllers(options =>
{
    options.Filters.Add<USBDeviceManager.Filters.ValidationFilter>();
});

// Add clock service for testable current time
builder.Services.AddSingleton<IDateTime, SystemDateTime>();

// Add Status service for server/agent port configuration and health checks
builder.Services.AddSingleton<USBDeviceManager.Services.StatusService>();

// Register adapters (stub implementations for development & tests)
builder.Services.AddSingleton<IDeviceAdapter, DeviceAdapterStub>();
builder.Services.AddSingleton<ISoftwareAdapter, SoftwareAdapterStub>();

// Register platform/test adapters for OS interactions and USB device simulation
builder.Services.AddSingleton<USBDeviceManager.Services.Abstractions.IProcessLauncher, USBDeviceManager.Services.Platform.ProcessLauncher>();
builder.Services.AddSingleton<USBDeviceManager.Services.Abstractions.IShellRunner, USBDeviceManager.Services.Platform.ShellRunner>();
builder.Services.AddSingleton<USBDeviceManager.Services.Abstractions.IUsbDeviceProvider, USBDeviceManager.Services.Usb.InMemoryUsbDeviceProvider>();

// Add Swagger/OpenAPI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "USB Device Manager API",
        Version = "v1",
        Description = "API for USB Device Manager - USB Device Monitoring, Software Management, and Automation",
    });

    // Include XML comments if available
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }
});

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});


// Explicitly set WebRootPath to ensure static files are found
builder.Environment.WebRootPath = Path.Combine(builder.Environment.ContentRootPath, "wwwroot");
WebApplication app = builder.Build();

// Configure the HTTP request pipeline
// Enable Swagger UI for local debugging regardless of environment
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "USB Device Manager API v1");
    c.RoutePrefix = "swagger";
});

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseCors("AllowAll");
app.UseRouting();

app.UseAntiforgery();

// Map controllers for API
app.MapControllers();

// Map Blazor components
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

// Map SignalR hubs
app.MapHub<MonitoringHub>("/hubs/monitoring");

// Serve a tiny embedded favicon to avoid 404s from browsers
app.MapGet("/favicon.png", () =>
{
    // 1x1 transparent PNG
    var png = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=");
    return Results.File(png, "image/png");
});

// Initialize database
using (IServiceScope scope = app.Services.CreateScope())
{
    SimRacingContext context = scope.ServiceProvider.GetRequiredService<SimRacingContext>();
    // Retry EnsureCreated a few times to tolerate transient Sqlite races (concurrent DDL, locks)
    const int maxEnsureAttempts = 3;
    int attempt = 0;
    while (true)
    {
        attempt++;
        try
        {
            context.Database.EnsureCreated();
            break;
        }
        catch (Microsoft.Data.Sqlite.SqliteException ex)
        {
            // Treat "already exists" as benign; on other transient errors (locked) retry a few times.
            var msg = ex.Message ?? string.Empty;
            if (msg.IndexOf("already exists", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                Console.WriteLine("[DIAG] Database ensure-created encountered existing table; continuing.");
                break;
            }

            if (attempt >= maxEnsureAttempts)
            {
                Console.WriteLine($"[DIAG] EnsureCreated failed after {attempt} attempts: {ex.Message}");
                throw;
            }

            // Log and back off before retrying
            Console.WriteLine($"[DIAG] EnsureCreated attempt {attempt} failed with SqliteException: {ex.Message}. Retrying...");
            System.Threading.Thread.Sleep(100 * attempt);
        }
    }
}

// Load status service and perform autostart if configured
using (IServiceScope scope = app.Services.CreateScope())
{
    var status = scope.ServiceProvider.GetRequiredService<StatusService>();
    // run autostart synchronously at startup
    try
    {
        status.StartAutostartServicesAsync().GetAwaiter().GetResult();
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[DIAG] Autostart failed: {ex.Message}");
    }
}


// Diagnostic logging for static files issue: write to diagnostics file
Console.WriteLine($"[DIAG] ContentRootPath: {app.Environment.ContentRootPath}");
Console.WriteLine($"[DIAG] WebRootPath: {app.Environment.WebRootPath}");
// Use TEST_PORT environment variable when available for printed endpoints
var printedPortEnv = Environment.GetEnvironmentVariable("TEST_PORT");
int printedPort = 5000;
if (!string.IsNullOrEmpty(printedPortEnv) && int.TryParse(printedPortEnv, out var p)) { printedPort = p; }
Console.WriteLine("USB Device Manager Server starting...");
Console.WriteLine($"Dashboard: http://localhost:{printedPort}");
Console.WriteLine($"API Documentation: http://localhost:{printedPort}/swagger");
Console.WriteLine("Press Ctrl+C to shut down.");

// Register lifetime events to capture shutdown diagnostics
var lifetime = app.Lifetime;
lifetime.ApplicationStarted.Register(() =>
{
    Console.WriteLine($"[DIAG] ApplicationStarted: {DateTime.UtcNow:o}");
});

lifetime.ApplicationStopping.Register(() =>
{
    Console.WriteLine($"[DIAG] ApplicationStopping: {DateTime.UtcNow:o}");
    try
    {
        Console.WriteLine($"[DIAG] Environment.ExitCode = {Environment.ExitCode}");
        Console.WriteLine($"[DIAG] Managed thread id: {System.Threading.Thread.CurrentThread.ManagedThreadId}");
        Console.WriteLine("[DIAG] StackTrace:\n" + Environment.StackTrace);
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[DIAG] Error capturing stopping diagnostics: {ex}");
    }
});

lifetime.ApplicationStopped.Register(() =>
{
    Console.WriteLine($"[DIAG] ApplicationStopped: {DateTime.UtcNow:o}");
});

// Prevent accidental Ctrl+C from terminating the server during interactive debugging
Console.CancelKeyPress += (sender, e) =>
{
    Console.WriteLine($"[DIAG] CancelKeyPress received at {DateTime.UtcNow:o}. Ignoring during debug session.");
    e.Cancel = true; // prevent process termination
};

AppDomain.CurrentDomain.ProcessExit += (sender, e) =>
{
    Console.WriteLine($"[DIAG] ProcessExit event fired at {DateTime.UtcNow:o}. ExitCode={Environment.ExitCode}");
};


try
{
    app.Run();
    Console.WriteLine("[DIAG] app.Run() exited normally.");
}
catch (Exception ex)
{
    Console.WriteLine($"[DIAG] Unhandled exception in app.Run(): {ex}");
    throw;
}

// Expose Program class to WebApplicationFactory in tests

/// <summary>
/// Program entrypoint exposed as a partial class for test hosts (WebApplicationFactory).
/// </summary>
public partial class Program
{
}
