// <copyright file="SimRacingContext.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

// </copyright>
namespace USBDeviceManager.Data;

using Microsoft.EntityFrameworkCore;
using USBDeviceManager.Models;

/// <summary>
/// EF Core <see cref="DbContext"/> used by the USB Device Manager server.
/// </summary>
public class SimRacingContext : DbContext
{
    /// <summary>
    /// Initializes a new instance of the <see cref="SimRacingContext"/> class.
    /// </summary>
    /// <param name="options">The options to configure the context.</param>
    public SimRacingContext(DbContextOptions<SimRacingContext> options)
        : base(options)
    {
    }

    // Device Management
    public DbSet<UsbDevice> UsbDevices { get; set; } = null!;

    public DbSet<DeviceStatus> DeviceStatuses { get; set; } = null!;

    // Software Management
    public DbSet<ManagedSoftware> ManagedSoftware { get; set; } = null!;

    public DbSet<SoftwareStatus> SoftwareStatuses { get; set; } = null!;

    // Automation
    public DbSet<AutomationRule> AutomationRules { get; set; } = null!;

    public DbSet<RuleExecution> RuleExecutions { get; set; } = null!;

    // Monitoring
    public DbSet<SystemStatus> SystemStatuses { get; set; } = null!;

    public DbSet<HealthMetric> HealthMetrics { get; set; } = null!;

    /// <inheritdoc/>
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // USB Device Configuration
        modelBuilder.Entity<UsbDevice>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.DeviceId).IsRequired().HasMaxLength(255);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(255);
            entity.Property(e => e.VendorId).HasMaxLength(10);
            entity.Property(e => e.ProductId).HasMaxLength(10);
            entity.HasIndex(e => e.DeviceId).IsUnique();
        });

        modelBuilder.Entity<DeviceStatus>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasOne(e => e.Device)
                  .WithMany()
                  .HasForeignKey(e => e.DeviceId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // Software Management Configuration
        modelBuilder.Entity<ManagedSoftware>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(255);
            entity.Property(e => e.ExecutablePath).IsRequired().HasMaxLength(500);
            entity.Property(e => e.StartupArguments).HasMaxLength(1000);
            entity.Property(e => e.WorkingDirectory).HasMaxLength(500);
        });

        modelBuilder.Entity<SoftwareStatus>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasOne(e => e.Software)
                  .WithMany()
                  .HasForeignKey(e => e.SoftwareId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // Automation Rules Configuration
        modelBuilder.Entity<AutomationRule>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(255);
            entity.Property(e => e.Description).HasMaxLength(500);
            entity.HasOne(e => e.TriggerDevice)
                  .WithMany()
                  .HasForeignKey(e => e.TriggerDeviceId)
                  .OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(e => e.TargetSoftware)
                  .WithMany()
                  .HasForeignKey(e => e.TargetSoftwareId)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<RuleExecution>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasOne(e => e.Rule)
                  .WithMany()
                  .HasForeignKey(e => e.RuleId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // System Monitoring Configuration
        modelBuilder.Entity<SystemStatus>(entity =>
        {
            entity.HasKey(e => e.Id);
        });

        modelBuilder.Entity<HealthMetric>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.MetricName).IsRequired().HasMaxLength(255);
            entity.Property(e => e.Source).HasMaxLength(255);
        });

        base.OnModelCreating(modelBuilder);
    }
}
