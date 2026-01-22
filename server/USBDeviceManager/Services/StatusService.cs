using System.Net.Sockets;
using System.Diagnostics;

namespace USBDeviceManager.Services
{
    public class StatusService
    {
        private readonly object _lock = new();
        private readonly string _contentRoot;
        private readonly Dictionary<string, Process> _processes = new();
        private readonly Dictionary<string, List<string>> _processLogs = new();
        private readonly int _maxLogLines = 1000;
        private readonly string _configPath;
        private ServiceConfig _config = new();

        // Configurable ports (defaults)
        public int ServerPort { get; private set; } = 5000;
        public int AgentPort { get; private set; } = 5001;

        public StatusService(Microsoft.Extensions.Hosting.IHostEnvironment env)
        {
            _contentRoot = env.ContentRootPath;
            _configPath = Path.Combine(_contentRoot, "config", "service-config.json");
            LoadConfig();
        }

        public void SetPorts(int serverPort, int agentPort)
        {
            lock (_lock)
            {
                ServerPort = serverPort;
                AgentPort = agentPort;
            }
        }

        public IReadOnlyDictionary<string, int> GetRunningProcesses()
        {
            lock (_lock)
            {
                return _processes.ToDictionary(kv => kv.Key, kv => kv.Value.Id);
            }
        }

        public Task<int> StartServerAsync(int port)
        {
            // Start a dotnet run process for the server project on the requested port.
            var psi = new ProcessStartInfo
            {
                FileName = "dotnet",
                Arguments = $"run --project \"{Path.Combine(_contentRoot, "server", "USBDeviceManager")}\" --urls http://localhost:{port}",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
                WorkingDirectory = _contentRoot
            };
            var proc = Process.Start(psi) ?? throw new InvalidOperationException("Failed to start dotnet process");
            // setup log capture
            lock (_lock)
            {
                _processLogs["server"] = new List<string>();
            }
            proc.OutputDataReceived += (s, e) => { if (e.Data != null) AppendLog("server", e.Data); };
            proc.ErrorDataReceived += (s, e) => { if (e.Data != null) AppendLog("server", "ERR: " + e.Data); };
            try { proc.BeginOutputReadLine(); proc.BeginErrorReadLine(); } catch { }
            lock (_lock)
            {
                _processes["server"] = proc;
            }
            // update config server port
            _config.ServerPort = port;
            SaveConfigAsync().GetAwaiter().GetResult();
            return Task.FromResult(proc.Id);
        }

        public Task<int> StartAgentAsync(int port)
        {
            // Prevent starting a second agent process if one is already tracked/running
            lock (_lock)
            {
                if (_processes.TryGetValue("agent", out var existing) && !existing.HasExited)
                {
                    throw new InvalidOperationException("An agent process is already running.");
                }
            }

            // Attempt to start PowerShell agent script if present
            var script = Path.Combine(_contentRoot, "agent", "SimRacingAgent", "SimRacingAgent.ps1");
            string fileName = "pwsh";
            string args = $"-NoProfile -ExecutionPolicy Bypass -File \"{script}\" -Port {port}";
            if (!File.Exists(script))
            {
                // fallback: start pwsh interactive if script missing
                args = "-NoProfile";
            }

            var psi = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = args,
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = _contentRoot
            };
            var proc = Process.Start(psi) ?? throw new InvalidOperationException("Failed to start agent process");
            // setup log capture
            lock (_lock)
            {
                _processLogs["agent"] = new List<string>();
            }
            proc.OutputDataReceived += (s, e) => { if (e.Data != null) AppendLog("agent", e.Data); };
            proc.ErrorDataReceived += (s, e) => { if (e.Data != null) AppendLog("agent", "ERR: " + e.Data); };
            try { proc.BeginOutputReadLine(); proc.BeginErrorReadLine(); } catch { }
            lock (_lock)
            {
                _processes["agent"] = proc;
            }
            _config.AgentPort = port;
            SaveConfigAsync().GetAwaiter().GetResult();
            return Task.FromResult(proc.Id);
        }

        public Task<bool> StopServiceAsync(string name)
        {
            lock (_lock)
            {
                if (_processes.TryGetValue(name, out var p))
                {
                    try
                    {
                        if (!p.HasExited) p.Kill(true);
                    }
                    catch { }
                    _processes.Remove(name);
                    return Task.FromResult(true);
                }
            }
            return Task.FromResult(false);
        }

        private void AppendLog(string name, string line)
        {
            try
            {
                lock (_lock)
                {
                    if (!_processLogs.ContainsKey(name)) _processLogs[name] = new List<string>();
                    var list = _processLogs[name];
                    list.Add($"[{DateTime.UtcNow:o}] {line}");
                    if (list.Count > _maxLogLines) list.RemoveRange(0, list.Count - _maxLogLines);
                }
            }
            catch { }
        }

        public List<string> GetProcessLogs(string name, int maxLines = 500)
        {
            lock (_lock)
            {
                if (!_processLogs.TryGetValue(name, out var list)) return new List<string>();
                if (maxLines <= 0) return new List<string>(list);
                return list.TakeLast(Math.Min(maxLines, list.Count)).ToList();
            }
        }

        public void ClearProcessLogs(string name)
        {
            lock (_lock)
            {
                if (_processLogs.ContainsKey(name)) _processLogs[name].Clear();
            }
        }

        private void LoadConfig()
        {
            try
            {
                var dir = Path.GetDirectoryName(_configPath);
                if (!Directory.Exists(dir)) Directory.CreateDirectory(dir!);
                if (File.Exists(_configPath))
                {
                    var json = File.ReadAllText(_configPath);
                    var cfg = System.Text.Json.JsonSerializer.Deserialize<ServiceConfig>(json);
                    if (cfg != null) _config = cfg;
                }
                // apply loaded ports
                ServerPort = _config.ServerPort;
                AgentPort = _config.AgentPort;
            }
            catch { }
        }

        private async Task SaveConfigAsync()
        {
            try
            {
                var dir = Path.GetDirectoryName(_configPath);
                if (!Directory.Exists(dir)) Directory.CreateDirectory(dir!);
                var json = System.Text.Json.JsonSerializer.Serialize(_config, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
                await File.WriteAllTextAsync(_configPath, json);
            }
            catch { }
        }

        public ServiceConfig GetConfig() => _config;

        public async Task SetConfigAsync(ServiceConfig cfg)
        {
            _config = cfg ?? new ServiceConfig();
            ServerPort = _config.ServerPort;
            AgentPort = _config.AgentPort;
            await SaveConfigAsync();
        }

        public async Task StartAutostartServicesAsync()
        {
            try
            {
                if (_config.AutostartServer)
                {
                    // start server on configured port
                    await StartServerAsync(_config.ServerPort);
                }
                if (_config.AutostartAgent)
                {
                    await StartAgentAsync(_config.AgentPort);
                }
            }
            catch { }
        }

        // Return suggested ports (default 5000..5009) and indicate availability
        public async Task<IEnumerable<(int Port, bool IsAvailable)>> GetSuggestedPortsAsync(int start = 5000, int count = 10)
        {
            var list = new List<(int, bool)>();
            for (int i = 0; i < count; i++)
            {
                int p = start + i;
                bool free = await Task.Run(() => IsPortFree(p));
                list.Add((p, free));
            }
            return list;
        }

        // Lightweight check: try to bind a TcpListener to see if port is free
        private bool IsPortFree(int port)
        {
            try
            {
                var listener = new TcpListener(System.Net.IPAddress.Loopback, port);
                listener.Start();
                listener.Stop();
                return true;
            }
            catch
            {
                return false;
            }
        }

        // Check if a service is listening on the port (connect attempt)
        public async Task<bool> IsServiceListeningAsync(int port, int timeoutMs = 250)
        {
            try
            {
                using var client = new TcpClient();
                var task = client.ConnectAsync("127.0.0.1", port);
                var completed = await Task.WhenAny(task, Task.Delay(timeoutMs));
                return completed == task && client.Connected;
            }
            catch
            {
                return false;
            }
        }
    }
}
