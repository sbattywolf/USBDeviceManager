// <copyright file="MonitoringHub.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Hubs;

using Microsoft.AspNetCore.SignalR;
using USBDeviceManager.Data;
using USBDeviceManager.Models;

/// <summary>
/// Hub used for real-time monitoring notifications.
/// </summary>
public class MonitoringHub : Hub
{
    private readonly ILogger<MonitoringHub> logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="MonitoringHub"/> class.
    /// </summary>
    /// <param name="logger">Logger instance.</param>
    public MonitoringHub(ILogger<MonitoringHub> logger)
    {
        this.logger = logger;
    }

    /// <summary>
    /// Add the caller to a named group.
    /// </summary>
    /// <param name="groupName">Group name to join.</param>
    public async Task JoinGroup(string groupName)
    {
        await this.Groups.AddToGroupAsync(this.Context.ConnectionId, groupName);
        this.logger.LogInformation("Client {ConnectionId} joined group {GroupName}", this.Context.ConnectionId, groupName);
    }

    /// <summary>
    /// Remove the caller from a named group.
    /// </summary>
    /// <param name="groupName">Group name to leave.</param>
    public async Task LeaveGroup(string groupName)
    {
        await this.Groups.RemoveFromGroupAsync(this.Context.ConnectionId, groupName);
        this.logger.LogInformation("Client {ConnectionId} left group {GroupName}", this.Context.ConnectionId, groupName);
    }

    /// <inheritdoc/>
    public override async Task OnConnectedAsync()
    {
        this.logger.LogInformation("Client connected: {ConnectionId}", this.Context.ConnectionId);
        await base.OnConnectedAsync();
    }

    /// <inheritdoc/>
    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        this.logger.LogInformation("Client disconnected: {ConnectionId}", this.Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }
}
