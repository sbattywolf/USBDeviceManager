// <copyright file="MonitoringHub.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

using Microsoft.AspNetCore.SignalR;
using SimRacingDashboard.Data;
using SimRacingDashboard.Models;

namespace SimRacingDashboard.Hubs;

public class MonitoringHub : Hub
{
    private readonly ILogger<MonitoringHub> logger;

    public MonitoringHub(ILogger<MonitoringHub> logger)
    {
        this.logger = logger;
    }

    public async Task JoinGroup(string groupName)
    {
        await this.Groups.AddToGroupAsync(this.Context.ConnectionId, groupName);
        this.logger.LogInformation("Client {ConnectionId} joined group {GroupName}", this.Context.ConnectionId, groupName);
    }

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
