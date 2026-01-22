using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.SignalR.Client;
using USBDeviceManager.Models;

namespace USBDeviceManager.Services
{
    public class DashboardClient : IAsyncDisposable
    {
        private readonly HttpClient http;
        private HubConnection? hubConnection;

        // SignalR callbacks consumers can subscribe to
        public event Action<UsbDevice>? DeviceUpdated;
        public event Action<ManagedSoftware>? SoftwareUpdated;
        public event Action<string>? LogLineReceived;
        public event Action<Guid, DateTime>? AgentHeartbeatReceived;
        private readonly List<string> recentLogs = new();

        /// <summary>
        /// List of recent log lines (newest-first). Thread-safe via internal locking.
        /// UI can bind to this list; callers should avoid iterating without locking if adding concurrently.
        /// </summary>
        public List<string> RecentLogs => recentLogs;

        public DashboardClient(HttpClient http)
        {
            this.http = http;
        }

        public Task<Dictionary<string, string>?> GetHealthAsync()
            => http.GetFromJsonAsync<Dictionary<string, string>>("api/health");

        public Task<List<UsbDevice>?> GetDevicesAsync()
            => http.GetFromJsonAsync<List<UsbDevice>>("api/devices");

        public Task ToggleDeviceAsync(int id, bool enabled)
            => http.PostAsJsonAsync($"api/devices/{id}/toggle", enabled);

        public Task<List<ManagedSoftware>?> GetSoftwareAsync()
            => http.GetFromJsonAsync<List<ManagedSoftware>>("api/software");

        public Task StartSoftwareAsync(int id)
            => http.PostAsync($"api/software/{id}/start", null);

        public Task StopSoftwareAsync(int id)
            => http.PostAsync($"api/software/{id}/stop", null);

        // Service / status endpoints
        public Task<USBDeviceManager.Services.ServiceConfig?> GetServiceConfigAsync()
            => http.GetFromJsonAsync<USBDeviceManager.Services.ServiceConfig>("api/services/config");

        public Task<HttpResponseMessage> SaveServiceConfigAsync(USBDeviceManager.Services.ServiceConfig cfg)
            => http.PostAsJsonAsync("api/services/config", cfg);

        public Task<HttpResponseMessage> StartAgentAsync(int? port = null)
            => http.PostAsJsonAsync("api/services/start/agent", new { Port = port });

        public Task<HttpResponseMessage> StartServerAsync(int? port = null)
            => http.PostAsJsonAsync("api/services/start/server", new { Port = port });

        public Task<HttpResponseMessage> StopServiceAsync(string name)
            => http.PostAsync($"api/services/stop/{name}", null);

        public Task<Dictionary<string,int>?> GetRunningProcessesAsync()
            => http.GetFromJsonAsync<Dictionary<string,int>>("api/services/running");

        private HubConnection CreateHubConnection()
        {
            return new HubConnectionBuilder()
                .WithUrl("/hubs/monitoring")
                .WithAutomaticReconnect()
                .Build();
        }

        public HubConnection GetOrCreateHubConnection()
        {
            if (hubConnection == null)
            {
                hubConnection = CreateHubConnection();
            }
            return hubConnection;
        }

        /// <summary>
        /// Start the SignalR hub connection and register default handlers.
        /// Safe to call multiple times; will no-op if already started.
        /// </summary>
        public async Task StartHubAsync()
        {
            var hub = GetOrCreateHubConnection();
            // Register handlers only once
            if (hub?.State == HubConnectionState.Disconnected)
            {
                hub.On<object>("DeviceUpdated", payload =>
                {
                    try
                    {
                        // Attempt to map dynamic payload to UsbDevice
                        var device = System.Text.Json.JsonSerializer.Deserialize<UsbDevice>(payload.ToString() ?? string.Empty);
                        if (device != null) DeviceUpdated?.Invoke(device);
                    }
                    catch
                    {
                        // best-effort: ignore
                    }
                });

                hub.On<object>("SoftwareUpdated", payload =>
                {
                    try
                    {
                        var sw = System.Text.Json.JsonSerializer.Deserialize<ManagedSoftware>(payload.ToString() ?? string.Empty);
                        if (sw != null) SoftwareUpdated?.Invoke(sw);
                    }
                    catch
                    {
                    }
                });

                hub.On<object>("LogLine", payload =>
                {
                    try
                    {
                        var json = payload.ToString() ?? string.Empty;
                        string lineToAdd = json;

                        // If payload looks like JSON object with Line property, extract it
                        if (!string.IsNullOrEmpty(json))
                        {
                            try
                            {
                                var doc = System.Text.Json.JsonDocument.Parse(json);
                                if (doc.RootElement.ValueKind == System.Text.Json.JsonValueKind.Object && doc.RootElement.TryGetProperty("Line", out var lineProp))
                                {
                                    lineToAdd = lineProp.GetString() ?? json;
                                }
                            }
                            catch { }

                            // add to internal recent logs (newest-first)
                            try
                            {
                                lock (recentLogs)
                                {
                                    recentLogs.Insert(0, lineToAdd);
                                    if (recentLogs.Count > 200) recentLogs.RemoveRange(200, recentLogs.Count - 200);
                                }
                            }
                            catch { }

                            LogLineReceived?.Invoke(lineToAdd);
                        }
                    }
                    catch { }
                });

                hub.On<Guid, DateTime>("AgentHeartbeat", (agentId, ts) =>
                {
                    AgentHeartbeatReceived?.Invoke(agentId, ts);
                });

                hub.Reconnecting += error =>
                {
                    Console.WriteLine($"[DIAG] Hub reconnecting: {error?.Message}");
                    return Task.CompletedTask;
                };

                hub.Reconnected += id =>
                {
                    Console.WriteLine($"[DIAG] Hub reconnected: {id}");
                    return Task.CompletedTask;
                };

                hub.Closed += async error =>
                {
                    Console.WriteLine($"[DIAG] Hub closed: {error?.Message}");
                    // try to restart after short delay
                    await Task.Delay(2000);
                    try
                    {
                        await hub.StartAsync();
                        await hub.SendAsync("JoinGroup", "dashboard");
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"[DIAG] Failed to restart hub: {ex.Message}");
                    }
                };

                try
                {
                    await hub.StartAsync();
                    await hub.SendAsync("JoinGroup", "dashboard");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[DIAG] Failed to start hub: {ex.Message}");
                }
            }
        }

        public async Task StopHubAsync()
        {
            if (hubConnection != null && (hubConnection.State == HubConnectionState.Connected || hubConnection.State == HubConnectionState.Connecting))
            {
                try
                {
                    await hubConnection.SendAsync("LeaveGroup", "dashboard");
                }
                catch { }

                try
                {
                    await hubConnection.StopAsync();
                }
                catch { }
            }
        }

        public async ValueTask DisposeAsync()
        {
            await StopHubAsync();
            if (hubConnection != null)
            {
                await hubConnection.DisposeAsync();
                hubConnection = null;
            }
        }

        /// <summary>
        /// Publish a log line into the local recent logs and notify subscribers.
        /// This is useful for in-process simulations or server-side code that wants to
        /// surface a log line to any UI components subscribed to this service.
        /// </summary>
        /// <param name="line">Log line text.</param>
        public void PublishLogLine(string line)
        {
            try
            {
                lock (recentLogs)
                {
                    recentLogs.Insert(0, line);
                    if (recentLogs.Count > 200) recentLogs.RemoveRange(200, recentLogs.Count - 200);
                }

                try { LogLineReceived?.Invoke(line); } catch { }
            }
            catch { }
        }
    }
}
