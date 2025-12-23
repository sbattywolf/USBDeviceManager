// <copyright file="Program.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;
using USBDeviceManager.Components;
using USBDeviceManager.Data;
using USBDeviceManager.Hubs;
using USBDeviceManager.Services;
using USBDeviceManager.Adapters;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

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

// Add API controllers with a simple validation filter for consistent errors
builder.Services.AddControllers(options =>
{
    options.Filters.Add<USBDeviceManager.Filters.ValidationFilter>();
});

// Add clock service for testable current time
builder.Services.AddSingleton<IDateTime, SystemDateTime>();

// Register adapters (stub implementations for development & tests)
builder.Services.AddSingleton<IDeviceAdapter, DeviceAdapterStub>();
builder.Services.AddSingleton<ISoftwareAdapter, SoftwareAdapterStub>();

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

WebApplication app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "USB Device Manager API v1");
        c.RoutePrefix = "swagger";
    });
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

// Initialize database
using (IServiceScope scope = app.Services.CreateScope())
{
    SimRacingContext context = scope.ServiceProvider.GetRequiredService<SimRacingContext>();
    context.Database.EnsureCreated();
}

Console.WriteLine("USB Device Manager Server starting...");
Console.WriteLine("Dashboard: http://localhost:5000");
Console.WriteLine("API Documentation: http://localhost:5000/swagger");
Console.WriteLine("Press Ctrl+C to shut down.");

app.Run();

// Expose Program class to WebApplicationFactory in tests
public partial class Program
{
}
