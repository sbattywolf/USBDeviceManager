using System.Data.Common;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Collections.Generic;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using USBDeviceManager.Data;

namespace USBDeviceManager.Tests.Fixtures;

/// <summary>
/// Test application factory for integration and functional tests
/// Provides isolated test environment with in-memory database
/// </summary>
public class SimRacingTestFactory : WebApplicationFactory<Program>
{
    private TextWriter? _originalOut;
    private TextWriter? _originalErr;
    private StreamWriter? _consoleWriter;
    private readonly string _testDatabaseName;
    private readonly string _dbFilePath;
    private readonly string _connectionString;
    
    // Helper: return both the runtime artifact directory (current dir/TestResults/artifacts)
    // and, when possible, the repository test project artifact directory
    private IEnumerable<string> GetArtifactDirectories()
    {
        var dirs = new List<string>();
        try
        {
            var current = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
            dirs.Add(current);

            var repoRoot = FindRepoRoot();
            if (!string.IsNullOrEmpty(repoRoot))
            {
                var repoArtifacts = Path.Combine(repoRoot, "server", "USBDeviceManager.Tests", "TestResults", "artifacts");
                dirs.Add(repoArtifacts);
            }
        }
        catch { }

        return dirs.Distinct();
    }

    private string? FindRepoRoot()
    {
        try
        {
            var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
            while (dir != null)
            {
                var sln = Path.Combine(dir.FullName, "USBDeviceManager.sln");
                if (File.Exists(sln)) return dir.FullName;
                dir = dir.Parent;
            }
        }
        catch { }
        return null;
    }
    // no shared connection by default; use connection string to allow EF to manage connections

    public SimRacingTestFactory()
    {
        // Deterministic per-run test DB name (timestamp + PID). This makes the
        // DB filename discoverable and helps with cleanup across runs.
        _testDatabaseName = $"SimRacingTest_{DateTime.UtcNow:yyyyMMddHHmmss}_{Process.GetCurrentProcess().Id}";

        // Allow forcing the DB file path for debugging via environment variable
        // SIMRACING_DEBUG_DBPATH. When present, use the provided path. When the
        // repro gate is enabled (RUN_DB_REPRO=1) prefer a deterministic repo-
        // local path under server/.../TestResults/artifacts so CI/local runs
        // preserve the DB for triage.
        var envDebugPath = Environment.GetEnvironmentVariable("SIMRACING_DEBUG_DBPATH");
        // Defensive: if a Windows-style path (drive letter + colon or backslashes)
        // is provided on a non-Windows OS, ignore it to avoid trying to open
        // a non-native path (which can result in 'file is not a database').
        if (!string.IsNullOrEmpty(envDebugPath) &&
            !System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows))
        {
            // Heuristic: Windows absolute path contains a drive letter and ':' or backslashes
            if (envDebugPath.Length >= 2 && envDebugPath[1] == ':' || envDebugPath.Contains("\\"))
            {
                try
                {
                    Console.Error.WriteLine($"SimRacingTestFactory: ignoring SIMRACING_DEBUG_DBPATH='{envDebugPath}' on non-Windows OS");
                    envDebugPath = null;
                }
                catch { envDebugPath = null; }
            }
        }
        var runRepro = Environment.GetEnvironmentVariable("RUN_DB_REPRO") == "1";
        if (!string.IsNullOrEmpty(envDebugPath))
        {
            _dbFilePath = envDebugPath;
            try
            {
                // derive a test database name from the forced path if possible
                var name = Path.GetFileNameWithoutExtension(_dbFilePath);
                if (!string.IsNullOrEmpty(name)) _testDatabaseName = name;
            }
            catch { }
            // When forcing the DB path via environment, ensure the file exists
            // and write a workspace-local sentinel so test runs can be verified
            try
            {
                var dir = Path.GetDirectoryName(_dbFilePath);
                if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
                // If a previous forced file exists (possibly containing non-SQLite
                // data), delete it so SQLite can create a clean database file.
                try
                {
                    if (File.Exists(_dbFilePath))
                    {
                        File.Delete(_dbFilePath);
                    }
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"SimRacingTestFactory: failed to remove existing forced DB file '{_dbFilePath}': {ex}");
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"SimRacingTestFactory: failed to prepare directory for forced DB path '{_dbFilePath}': {ex}");
            }

            try
            {
                foreach (var artifactsDir in GetArtifactDirectories())
                {
                    try
                    {
                        Directory.CreateDirectory(artifactsDir);
                        var sentinel = Path.Combine(artifactsDir, _testDatabaseName + "-debug-sentinel.txt");
                        File.WriteAllText(sentinel, $"SIMRACING_DEBUG_DBPATH='{envDebugPath}'\nCreatedAt:{DateTime.UtcNow:O}\n");
                    }
                    catch (Exception ex)
                    {
                        Console.Error.WriteLine($"SimRacingTestFactory: failed to write debug sentinel to '{artifactsDir}': {ex}");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"SimRacingTestFactory: failed to enumerate artifact dirs for debug sentinel: {ex}");
            }
        }
        else
        {
            // Prefer a repo-local artifacts DB when running the repro gate so
            // the file is preserved for triage. Otherwise use a temp file.
            if (runRepro)
            {
                var repoRoot = FindRepoRoot();
                if (!string.IsNullOrEmpty(repoRoot))
                {
                    var repoArtifacts = Path.Combine(repoRoot, "server", "USBDeviceManager.Tests", "TestResults", "artifacts");
                    try { Directory.CreateDirectory(repoArtifacts); } catch { }
                    _dbFilePath = Path.Combine(repoArtifacts, _testDatabaseName + ".db");
                }
                else
                {
                    _dbFilePath = Path.Combine(Path.GetTempPath(), _testDatabaseName + ".db");
                }
            }
            else
            {
                // Use a temporary file-based SQLite DB to allow multiple connections
                _dbFilePath = Path.Combine(Path.GetTempPath(), _testDatabaseName + ".db");
            }
        }

        _connectionString = $"Data Source={_dbFilePath};Cache=Shared";

        // Log the computed DB path to Console (appears in server logs)
        try
        {
            Console.WriteLine($"SimRacingTestFactory: computed DB path = '{_dbFilePath}'");
        }
        catch { }

        // Ensure the DB directory exists and avoid creating a zero-length file.
        try
        {
            var dir = Path.GetDirectoryName(_dbFilePath);
            if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);

            // If a zero-length file exists (from previous runs), remove it so
            // SQLite can create a valid database file when opening the
            // connection below.
            try
            {
                if (File.Exists(_dbFilePath))
                {
                    var fi = new FileInfo(_dbFilePath);
                    if (fi.Length == 0)
                    {
                        try { File.Delete(_dbFilePath); } catch { }
                    }
                }
            }
            catch { }

            // Avoid pre-creating schema marker tables here. Rely on EF's
            // EnsureCreated() later to create the full schema. Pre-creating a
            // minimal table can mask or produce invalid DB files on some
            // environments and interferes with diagnostics when the DB is
            // malformed; removing the precreate reduces corruption risk.
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: failed to prepare DB file '{_dbFilePath}': {ex}");
        }

        // Defensive startup cleanup: remove old leftover SimRacingTest_*.db files.
        // Expiration window can be configured via SIMRACING_TEST_DB_EXPIRATION_HOURS (hours).
        try
        {
            var tempDir = Path.GetTempPath();
            IEnumerable<string> files = Directory.EnumerateFiles(tempDir, "SimRacingTest_*.db");

            var expirationHours = 6;
            var env = Environment.GetEnvironmentVariable("SIMRACING_TEST_DB_EXPIRATION_HOURS");
            if (!string.IsNullOrEmpty(env) && int.TryParse(env, out var parsed) && parsed >= 0)
            {
                expirationHours = parsed;
            }

            var expiration = TimeSpan.FromHours(expirationHours);

            foreach (var f in files)
            {
                try
                {
                    var fi = new FileInfo(f);
                    if (DateTime.UtcNow - fi.LastWriteTimeUtc > expiration)
                    {
                        File.Delete(f);
                    }
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"SimRacingTestFactory: failed to delete temp DB '{f}': {ex}");
                }
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: startup cleanup failed: {ex}");
        }

        // Create the database file and apply PRAGMAs to improve concurrency
        try
        {
            using var tmpConn = new SqliteConnection(_connectionString);
            tmpConn.Open();
            using (SqliteCommand cmd = tmpConn.CreateCommand())
            {
                cmd.CommandText = "PRAGMA journal_mode=WAL;";
                cmd.ExecuteNonQuery();
            }
            using (SqliteCommand cmd = tmpConn.CreateCommand())
            {
                cmd.CommandText = "PRAGMA busy_timeout=10000;";
                cmd.ExecuteNonQuery();
            }
            tmpConn.Close();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: failed to set PRAGMAs on '{_dbFilePath}': {ex}");
        }
        // Eagerly initialize EF/SQLite model and database while single-threaded so
        // that any SQLite user-function registration happens before concurrent tests.
        try
        {
            using SimRacingContext initContext = GetDbContext();
            initContext.Database.EnsureCreated();
            // force model creation
            _ = initContext.Model;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: EF model initialization failed: {ex}");
        }

        // Write an early diagnostic artifact with the computed DB path and copy
        // a small sample of the DB file if it exists to make it visible to CI/artifact
        // collection and local repro runs.
        try
        {
            foreach (var artifactsDir in GetArtifactDirectories())
            {
                try
                {
                    Directory.CreateDirectory(artifactsDir);
                    var pathFile = Path.Combine(artifactsDir, _testDatabaseName + "-dbpath.txt");
                    File.WriteAllText(pathFile, _dbFilePath);
                    if (File.Exists(_dbFilePath))
                    {
                        try
                        {
                            var samplePath = Path.Combine(artifactsDir, _testDatabaseName + "-db-sample.bin");
                            using var inFs = new FileStream(_dbFilePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                            using var outFs = new FileStream(samplePath, FileMode.Create, FileAccess.Write, FileShare.Read);
                            var buf = new byte[4096];
                            int read = inFs.Read(buf, 0, buf.Length);
                            if (read > 0)
                            {
                                outFs.Write(buf, 0, read);
                            }
                        }
                        catch (Exception copyEx)
                        {
                            Console.Error.WriteLine($"SimRacingTestFactory: failed to copy DB sample to '{artifactsDir}': {copyEx}");
                        }
                    }
                }
                catch (Exception tex)
                {
                    Console.Error.WriteLine($"SimRacingTestFactory: failed to write dbpath artifact to '{artifactsDir}': {tex}");
                }
            }

            // Also write a copy of the DB path into the system temp folder so
            // local repro runs and external tooling can find it reliably.
            try
            {
                var tempPathFile = Path.Combine(Path.GetTempPath(), _testDatabaseName + "-dbpath.txt");
                File.WriteAllText(tempPathFile, _dbFilePath);
            }
            catch (Exception tex)
            {
                Console.Error.WriteLine($"SimRacingTestFactory: failed to write temp dbpath file: {tex}");
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: failed to write DB path artifact: {ex}");
        }
    }

    /// <summary>
    /// Configure test services and database
    /// </summary>
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
            // Redirect Console output/errors to a test artifact file so CI uploads host logs
            try
            {
                var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                Directory.CreateDirectory(artifactsDir);
                var consoleLogPath = Path.Combine(artifactsDir, _testDatabaseName + "-server-console.log");

                _originalOut = Console.Out;
                _originalErr = Console.Error;
                _consoleWriter = new StreamWriter(new FileStream(consoleLogPath, FileMode.Append, FileAccess.Write, FileShare.Read)) { AutoFlush = true };
                Console.SetOut(_consoleWriter);
                Console.SetError(_consoleWriter);

                // Emit a ConfigureWebHost sentinel: log the effective SIMRACING_DEBUG_DBPATH
                try
                {
                    var debugEnv = Environment.GetEnvironmentVariable("SIMRACING_DEBUG_DBPATH") ?? string.Empty;
                    Console.WriteLine($"SimRacingTestFactory: ConfigureWebHost sees SIMRACING_DEBUG_DBPATH='{debugEnv}'");
                    foreach (var cwArtifactsDir in GetArtifactDirectories())
                    {
                        try
                        {
                            Directory.CreateDirectory(cwArtifactsDir);
                            var cwSentinel = Path.Combine(cwArtifactsDir, _testDatabaseName + "-configurewebhost-sentinel.txt");
                            File.WriteAllText(cwSentinel, $"SIMRACING_DEBUG_DBPATH='{debugEnv}'\nTimestamp:{DateTime.UtcNow:O}\n");
                        }
                        catch (Exception ex)
                        {
                            try { Console.Error.WriteLine($"SimRacingTestFactory: failed to write ConfigureWebHost sentinel to '{cwArtifactsDir}': {ex}"); } catch { }
                        }
                    }
                }
                catch (Exception ex)
                {
                    try { Console.Error.WriteLine($"SimRacingTestFactory: failed to write ConfigureWebHost sentinel: {ex}"); } catch { }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"SimRacingTestFactory: failed to redirect console output: {ex}");
            }

        builder.ConfigureServices(services =>
        {
            // Remove existing database context registration
            ServiceDescriptor? descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<SimRacingContext>));

            if (descriptor != null)
            {
                services.Remove(descriptor);
            }

            // Use a file-based SQLite database so multiple concurrent connections work
            services.AddDbContext<SimRacingContext>(options =>
            {
                options.UseSqlite(_connectionString);
                options.EnableSensitiveDataLogging();
                options.EnableDetailedErrors();
            });

            // Reduce logging noise in tests but capture host logs to a file
            services.AddLogging(builder =>
            {
                builder.ClearProviders();

                // Ensure test artifacts folder exists and compute deterministic log path
                try
                {
                    var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                    Directory.CreateDirectory(artifactsDir);
                    var logPath = Path.Combine(artifactsDir, _testDatabaseName + "-server.log");

                    builder.AddProvider(new FileLoggerProvider(logPath));
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"SimRacingTestFactory: failed to configure file logger: {ex}");
                }

                builder.AddDebug();
                builder.SetMinimumLevel(LogLevel.Debug);
            });

            // Build a temporary provider and initialize the database via DI to ensure
            // EF/SQLite registers any required functions while single-threaded.
            try
            {
                ServiceProvider sp = services.BuildServiceProvider();
                using IServiceScope scope = sp.CreateScope();
                SimRacingContext ctx = scope.ServiceProvider.GetRequiredService<SimRacingContext>();
                ctx.Database.EnsureCreated();
            }
            catch
            {
                // ignore init errors here; tests will report them
            }
        });

        builder.UseEnvironment("Testing");
        builder.UseConfiguration(new ConfigurationBuilder()
            .AddJsonFile("appsettings.Testing.json")
            .Build());
    }

    // Simple file logger provider used only in test builds to capture WebHost logs
    private class FileLoggerProvider : ILoggerProvider
    {
        private readonly StreamWriter _writer;
        private readonly object _lock = new object();

        public FileLoggerProvider(string path)
        {
            // Open file in append mode and keep it for the test lifetime
            _writer = new StreamWriter(new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.Read))
            {
                AutoFlush = true
            };
        }

        public ILogger CreateLogger(string categoryName)
        {
            return new FileLogger(_writer, _lock, categoryName);
        }

        public void Dispose()
        {
            try
            {
                _writer?.Dispose();
            }
            catch
            {
                // swallow
            }
        }
    }

    private class FileLogger : ILogger
    {
        private readonly StreamWriter _writer;
        private readonly object _lock;
        private readonly string _category;

        public FileLogger(StreamWriter writer, object lck, string category)
        {
            _writer = writer;
            _lock = lck;
            _category = category;
        }

        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
        {
            try
            {
                var message = formatter(state, exception);
                lock (_lock)
                {
                    _writer.WriteLine($"[{DateTime.UtcNow:O}] [{logLevel}] {_category}: {message}");
                    if (exception != null)
                    {
                        _writer.WriteLine(exception.ToString());
                    }
                }
            }
            catch
            {
                // Swallow to avoid affecting tests
            }
        }
    }

    /// <summary>
    /// Get database context for test data setup
    /// </summary>
    /// <summary>
    /// Create a standalone <see cref="SimRacingContext"/> instance backed by the
    /// shared in-memory SQLite connection. Callers must dispose the returned context.
    /// </summary>
    public SimRacingContext GetDbContext()
    {
        DbContextOptions<SimRacingContext> options = new DbContextOptionsBuilder<SimRacingContext>()
            .UseSqlite(_connectionString)
            .EnableSensitiveDataLogging()
            .EnableDetailedErrors()
            .Options;

        return new SimRacingContext(options);
    }

    /// <summary>
    /// Expose the database file path for debugging and repro tests.
    /// </summary>
    public string DbFilePath => _dbFilePath;

    /// <summary>
    /// Seed test data for functional tests
    /// </summary>
    public async Task SeedTestDataAsync()
    {
        using SimRacingContext context = GetDbContext();

        // Ensure database is created
        await context.Database.EnsureCreatedAsync();

        // Clear existing data
        context.UsbDevices.RemoveRange(context.UsbDevices);
        context.ManagedSoftware.RemoveRange(context.ManagedSoftware);
        context.AutomationRules.RemoveRange(context.AutomationRules);
        await context.SaveChangesAsync();

        // Add test devices and software, save them first so EF assigns IDs
        List<UsbDevice> testDevices = TestDataGenerator.GenerateTestDevices(3);
        context.UsbDevices.AddRange(testDevices);

        List<ManagedSoftware> testSoftware = TestDataGenerator.GenerateTestSoftware(2);
        context.ManagedSoftware.AddRange(testSoftware);

        await context.SaveChangesAsync();

        // Now generate and add automation rules using persisted IDs. Build rules
        // here to ensure they reference the just-saved entities (avoid using
        // generators that may rely on pre-save IDs).
        var rng = new Random();
        var rules = new List<Models.AutomationRule>();
        var ruleNames = new[]
        {
            "Auto-start software on device connect",
            "Notify on device connect"
        };

        for (var i = 0; i < 2; i++)
        {
            UsbDevice device = testDevices[rng.Next(testDevices.Count)];
            ManagedSoftware? sw = null;
            if (testSoftware.Any())
            {
                sw = testSoftware[rng.Next(testSoftware.Count)];
            }

            var r = new Models.AutomationRule
            {
                Name = ruleNames[i % ruleNames.Length],
                Trigger = Models.AutomationTrigger.DeviceConnected,
                Action = sw != null ? Models.AutomationAction.StartSoftware : Models.AutomationAction.SendNotification,
                TriggerDeviceId = device.Id,
                TargetSoftwareId = sw?.Id,
                IsEnabled = true,
                CreatedAt = DateTime.UtcNow
            };

            rules.Add(r);
        }

        context.AutomationRules.AddRange(rules);

        await context.SaveChangesAsync();
    }

    /// <summary>
    /// Reset database for clean test state
    /// </summary>
    public async Task ResetDatabaseAsync()
    {
        using SimRacingContext context = GetDbContext();

        // Ensure database schema exists (create if missing) before attempting
        // to remove rows. Some test runs run against a fresh DB file and
        // calling EnsureCreated avoids "no such table" SQLite errors.
        await context.Database.EnsureCreatedAsync();

        // Diagnostic: dump DB schema and recent rows to artifacts so we can
        // triage cases where tables are missing. This is best-effort and
        // should not prevent the reset from proceeding.
        try
        {
            foreach (var artifactsDir in GetArtifactDirectories())
            {
                try
                {
                    Directory.CreateDirectory(artifactsDir);
                    var dumpPath = Path.Combine(artifactsDir, _testDatabaseName + "-pre-reset-db-dump.json");
                    DumpDatabaseSnapshot(dumpPath);
                }
                catch (Exception ex)
                {
                    try { Console.Error.WriteLine($"SimRacingTestFactory: failed to write pre-reset DB dump to '{artifactsDir}': {ex}"); } catch { }
                }
            }
        }
        catch { }

        // Clear all data
        context.RuleExecutions.RemoveRange(context.RuleExecutions);
        context.AutomationRules.RemoveRange(context.AutomationRules);
        context.SoftwareStatuses.RemoveRange(context.SoftwareStatuses);
        context.ManagedSoftware.RemoveRange(context.ManagedSoftware);
        context.DeviceStatuses.RemoveRange(context.DeviceStatuses);
        context.UsbDevices.RemoveRange(context.UsbDevices);
        context.HealthMetrics.RemoveRange(context.HealthMetrics);
        context.SystemStatuses.RemoveRange(context.SystemStatuses);

        await context.SaveChangesAsync();
    }

    /// <summary>
    /// Dump a lightweight snapshot of the SQLite database (schema + recent rows)
    /// to the given output file path as JSON. Best-effort: failures are logged
    /// to Console.Error but do not throw to avoid masking test results.
    /// </summary>
    public void DumpDatabaseSnapshot(string outFilePath)
    {
        try
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            var tables = new List<string>();
            using (var cmd = conn.CreateCommand())
            {
                cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';";
                using var r = cmd.ExecuteReader();
                while (r.Read())
                {
                    tables.Add(r.GetString(0));
                }
            }

            var tablesData = new Dictionary<string, object>();

            foreach (var t in tables)
            {
                var tableObj = new Dictionary<string, object>();

                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = "SELECT sql FROM sqlite_master WHERE type='table' AND name=@name;";
                    cmd.Parameters.AddWithValue("@name", t);
                    var createSql = cmd.ExecuteScalar()?.ToString() ?? string.Empty;
                    tableObj["create"] = createSql;
                }

                // Capture up to 200 recent rows
                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = $"SELECT * FROM \"{t}\" ORDER BY rowid DESC LIMIT 200;";
                    using var rdr = cmd.ExecuteReader();
                    var rows = new List<Dictionary<string, object>>();
                    while (rdr.Read())
                    {
                        var row = new Dictionary<string, object>();
                        for (int i = 0; i < rdr.FieldCount; i++)
                        {
                            var name = rdr.GetName(i);
                            var val = rdr.IsDBNull(i) ? null : rdr.GetValue(i);
                            row[name] = val;
                        }
                        rows.Add(row);
                    }

                    tableObj["rows"] = rows;
                }

                tablesData[t] = tableObj;
            }

            var outObj = new { dumpedAt = DateTime.UtcNow, tables = tablesData };
            var json = JsonSerializer.Serialize(outObj, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(outFilePath, json);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: DumpDatabaseSnapshot failed: {ex}");
        }
    }

    /// <summary>
    /// Create authenticated HTTP client for API testing
    /// </summary>
    public HttpClient CreateAuthenticatedClient()
    {
        HttpClient client = CreateClient();

        // Add any authentication headers if needed
        // client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        return client;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            // Clear SQLite pools first to reduce chance of lingering handles
            try
            {
                SqliteConnection.ClearAllPools();
            }
            catch (Exception ex)
            {
                try { Console.Error.WriteLine($"SimRacingTestFactory: ClearAllPools() failed: {ex}"); } catch { }
            }

            // Restore redirected console output and dispose writer
            try
            {
                if (_consoleWriter != null)
                {
                    try { _consoleWriter.Flush(); } catch { }
                    try { Console.SetOut(_originalOut ?? TextWriter.Null); Console.SetError(_originalErr ?? TextWriter.Null); } catch { }
                    try { _consoleWriter.Dispose(); } catch { }
                }
            }
            catch (Exception ex)
            {
                try { Console.Error.WriteLine($"SimRacingTestFactory: error restoring console output: {ex}"); } catch { }
            }
        }

        // Ensure base disposal runs to stop the host and background services
        try
        {
            base.Dispose(disposing);
        }
        catch (Exception ex)
        {
            try { Console.Error.WriteLine($"SimRacingTestFactory: base.Dispose threw: {ex}"); } catch { }
        }

        // After the host is stopped, attempt to delete the DB file with retries.
        try
        {
            // Skip deleting the DB file when running the repro gate so the
            // repository artifacts preserve the DB for triage.
            var runRepro = Environment.GetEnvironmentVariable("RUN_DB_REPRO") == "1";
            if (runRepro)
            {
                try { Console.WriteLine($"SimRacingTestFactory: RUN_DB_REPRO=1; skipping deletion of '{_dbFilePath}'"); } catch { }
            }
            else if (!string.IsNullOrEmpty(_dbFilePath) && File.Exists(_dbFilePath))
            {
                GC.Collect();
                GC.WaitForPendingFinalizers();
                Thread.Sleep(100);

                const int maxAttempts = 8;
                int delayMs = 500;
                for (int attempt = 1; attempt <= maxAttempts; attempt++)
                {
                    try
                    {
                        File.Delete(_dbFilePath);
                        break; // success
                    }
                    catch (IOException ioEx) when (attempt < maxAttempts)
                    {
                        try { Console.Error.WriteLine($"SimRacingTestFactory: delete attempt {attempt} failed: {ioEx.Message}. Retrying in {delayMs}ms."); } catch { }
                        Thread.Sleep(delayMs);
                        delayMs = Math.Min(2000, delayMs * 2);
                    }
                    catch (Exception ex)
                    {
                        try { Console.Error.WriteLine($"SimRacingTestFactory: failed to delete temp DB on dispose '{_dbFilePath}': {ex}"); } catch { }
                        try
                        {
                            foreach (var artifactsDir in GetArtifactDirectories())
                            {
                                try
                                {
                                    Directory.CreateDirectory(artifactsDir);
                                    var diagPath = Path.Combine(artifactsDir, _testDatabaseName + "-delete-diagnostics.txt");
                                    using var sw = new StreamWriter(new FileStream(diagPath, FileMode.Create, FileAccess.Write, FileShare.Read));
                                    sw.WriteLine($"Timestamp: {DateTime.UtcNow:O}");
                                    sw.WriteLine("Exception:");
                                    sw.WriteLine(ex.ToString());
                                    try
                                    {
                                        sw.WriteLine("\nFile info:");
                                        sw.WriteLine($"Exists: {File.Exists(_dbFilePath)}");
                                        var fi = new FileInfo(_dbFilePath);
                                        sw.WriteLine($"FullName: {fi.FullName}");
                                        sw.WriteLine($"Length: {fi.Length}");
                                        sw.WriteLine($"LastWriteUtc: {fi.LastWriteTimeUtc:O}");
                                        sw.WriteLine($"Attributes: {fi.Attributes}");
                                    }
                                    catch (Exception fex)
                                    {
                                        sw.WriteLine($"Failed to probe file info: {fex}");
                                    }
                                    try
                                    {
                                        sw.WriteLine("\nProcess list (Id - Name):");
                                        foreach (var p in System.Diagnostics.Process.GetProcesses().OrderBy(p => p.Id))
                                        {
                                            try { sw.WriteLine($"{p.Id} - {p.ProcessName}"); } catch { }
                                        }
                                    }
                                    catch (Exception pex)
                                    {
                                        sw.WriteLine($"Failed to enumerate processes: {pex}");
                                    }
                                    try
                                    {
                                        sw.WriteLine("\nAttempting to open DB file for read (shared):");
                                        using var fs = new FileStream(_dbFilePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                                        var buf = new byte[4096];
                                        int read = fs.Read(buf, 0, buf.Length);
                                        sw.WriteLine($"Read {read} bytes from file (first 1KB hex):");
                                        sw.WriteLine(BitConverter.ToString(buf, 0, Math.Min(read, 1024)));
                                        var samplePath = Path.Combine(artifactsDir, _testDatabaseName + "-db-sample.bin");
                                        using var outFs = new FileStream(samplePath, FileMode.Create, FileAccess.Write, FileShare.Read);
                                        outFs.Write(buf, 0, read);
                                        sw.WriteLine($"Wrote sample to {samplePath}");
                                    }
                                    catch (Exception openEx)
                                    {
                                        sw.WriteLine($"Failed to open/read DB file: {openEx}");
                                    }
                                    sw.Flush();
                                }
                                catch (Exception diagEx)
                                {
                                    try { Console.Error.WriteLine($"SimRacingTestFactory: failed to write delete diagnostics to '{artifactsDir}': {diagEx}"); } catch { }
                                }
                            }
                        }
                        catch (Exception diagExOuter)
                        {
                            try { Console.Error.WriteLine($"SimRacingTestFactory: failed to write delete diagnostics: {diagExOuter}"); } catch { }
                        }
                        break;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            try { Console.Error.WriteLine($"SimRacingTestFactory: unexpected error during final dispose cleanup: {ex}"); } catch { }
        }

    }
}
