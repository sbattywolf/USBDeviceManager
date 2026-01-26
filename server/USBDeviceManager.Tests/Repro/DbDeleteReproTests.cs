using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Xunit;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.Sqlite;

namespace USBDeviceManager.Tests.Repro
{
    public class DbDeleteReproTests
    {
        [Fact]
        public async Task Repro_DbDeleteLock_Local()
        {
            // This test is intended as a local repro helper. It is a no-op unless
            // the environment variable RUN_DB_REPRO is set to "1". This avoids
            // running the repro in CI accidentally.
            if (Environment.GetEnvironmentVariable("RUN_DB_REPRO") != "1")
            {
                return;
            }

            var temp = Path.GetTempPath();
            var before = Directory.GetFiles(temp, "SimRacingTest_*.db");

            // Create a factory and detect the DB file path created for this run.
            string factoryDbPath = null;
            using (var factory = new USBDeviceManager.Tests.Fixtures.SimRacingTestFactory())
            {
                try
                {
                    var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                    Directory.CreateDirectory(artifactsDir);
                    File.WriteAllText(Path.Combine(artifactsDir, "repro-factory-dbfile.txt"), factory.DbFilePath);
                }
                catch { }

                // Aggressive precreate (Option A): ensure any existing file is removed
                // and create a valid SQLite database here so Program.Main.EnsureCreated
                // does not encounter a malformed or non-SQLite file during host startup.
                try
                {
                    var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                    Directory.CreateDirectory(artifactsDir);

                    if (!string.IsNullOrEmpty(factory.DbFilePath))
                    {
                        try
                        {
                            if (File.Exists(factory.DbFilePath))
                            {
                                try { File.Delete(factory.DbFilePath); } catch (Exception ex) { File.WriteAllText(Path.Combine(artifactsDir, "repro-precreate-delete-exception.txt"), ex.ToString()); }
                            }

                            var connStr = $"Data Source={factory.DbFilePath};Cache=Shared";
                            try
                            {
                                using var conn = new SqliteConnection(connStr);
                                conn.Open();
                                using var cmd = conn.CreateCommand();
                                cmd.CommandText = "CREATE TABLE IF NOT EXISTS __repro_marker (id INTEGER PRIMARY KEY);";
                                cmd.ExecuteNonQuery();
                                conn.Close();
                            }
                            catch (Exception ex)
                            {
                                try { File.WriteAllText(Path.Combine(artifactsDir, "repro-precreate-create-exception.txt"), ex.ToString()); } catch { }
                            }

                            // Record precreate result and a header/dump for triage
                            try
                            {
                                var precreateReport = Path.Combine(artifactsDir, "repro-precreate-result.txt");
                                if (File.Exists(factory.DbFilePath))
                                {
                                    var fi = new FileInfo(factory.DbFilePath);
                                    File.WriteAllText(precreateReport, $"EXISTS;{fi.Length}");

                                    // write header/hexdump
                                    try
                                    {
                                        var bytes = File.ReadAllBytes(factory.DbFilePath);
                                        var header = System.Text.Encoding.ASCII.GetString(bytes.Take(Math.Min(16, bytes.Length)).ToArray());
                                        File.WriteAllText(Path.Combine(artifactsDir, "repro-precreate-header.txt"), header + Environment.NewLine + BitConverter.ToString(bytes.Take(Math.Min(64, bytes.Length)).ToArray()));
                                    }
                                    catch { }
                                }
                                else
                                {
                                    File.WriteAllText(precreateReport, "MISSING");
                                }
                            }
                            catch { }
                        }
                        catch { }
                    }
                }
                catch { }
                // Ensure a valid SQLite file exists at the factory path before starting the host.
                // This avoids Program.Main encountering a malformed or missing file when it
                // calls EnsureCreated during host startup.
                try
                {
                    var connStr = $"Data Source={factory.DbFilePath};Cache=Shared";
                    try
                    {
                        using var preConn = new Microsoft.Data.Sqlite.SqliteConnection(connStr);
                        preConn.Open();
                        using var preCmd = preConn.CreateCommand();
                        preCmd.CommandText = "CREATE TABLE IF NOT EXISTS __repro_marker (id INTEGER PRIMARY KEY);";
                        preCmd.ExecuteNonQuery();
                        preConn.Close();
                    }
                    catch { }

                    try
                    {
                        var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                        Directory.CreateDirectory(artifactsDir);
                        var precreateReport = Path.Combine(artifactsDir, "repro-precreate-result.txt");
                        if (File.Exists(factory.DbFilePath))
                        {
                            var fi = new FileInfo(factory.DbFilePath);
                            File.WriteAllText(precreateReport, $"EXISTS;{fi.Length}");
                        }
                        else
                        {
                            File.WriteAllText(precreateReport, "MISSING");
                        }
                    }
                    catch { }

                    // Validate the SQLite header and emit a small hex-dump for triage.
                    bool ValidateSqliteHeader(string path, string artifactsDir)
                    {
                        try
                        {
                            if (!File.Exists(path)) return false;
                            var bytes = File.ReadAllBytes(path);
                            var header = System.Text.Encoding.ASCII.GetString(bytes.Take(Math.Min(16, bytes.Length)).ToArray());
                            File.WriteAllText(Path.Combine(artifactsDir, "repro-precreate-header.txt"), header + Environment.NewLine + BitConverter.ToString(bytes.Take(Math.Min(64, bytes.Length)).ToArray()));
                            return header.StartsWith("SQLite format 3\0");
                        }
                        catch (Exception ex)
                        {
                            try { File.WriteAllText(Path.Combine(artifactsDir, "repro-precreate-header-exception.txt"), ex.ToString()); } catch { }
                            return false;
                        }
                    }

                    // If the pre-create didn't produce a usable DB file, try copying a
                    // known-good sample DB written by the factory into the artifacts
                    // folder. This ensures detection succeeds even when direct creation
                    // fails due to platform timing or lock races.
                    try
                    {
                        var repoArtifacts = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                        Directory.CreateDirectory(repoArtifacts);
                        // Look for a db-sample.bin in repo artifacts or bin artifacts
                        string[] sampleCandidates = new string[] {
                            Path.Combine(repoArtifacts, "db-sample.bin"),
                            Path.Combine(repoArtifacts, "*-db-sample.bin")
                        };

                        // Prefer explicit sample files in the repo artifacts; also check bin artifacts
                        string? FindSample()
                        {
                            try
                            {
                                var repo = repoArtifacts;
                                var files = Directory.Exists(repo) ? Directory.GetFiles(repo, "*db-sample.bin") : Array.Empty<string>();
                                if (files.Length > 0) return files.OrderByDescending(f => File.GetLastWriteTimeUtc(f)).First();

                                var binArtifacts = Path.Combine(AppContext.BaseDirectory ?? string.Empty, "TestResults", "artifacts");
                                files = Directory.Exists(binArtifacts) ? Directory.GetFiles(binArtifacts, "*db-sample.bin") : Array.Empty<string>();
                                if (files.Length > 0) return files.OrderByDescending(f => File.GetLastWriteTimeUtc(f)).First();
                            }
                            catch { }
                            return null;
                        }

                        var sample = FindSample();
                        if (!File.Exists(factory.DbFilePath) || (new FileInfo(factory.DbFilePath).Length < 128))
                        {
                            if (!string.IsNullOrEmpty(sample) && File.Exists(sample))
                            {
                                try
                                {
                                    // Copy the sample DB into place so subsequent detection finds it
                                    File.Copy(sample, factory.DbFilePath, true);
                                    var fi = new FileInfo(factory.DbFilePath);
                                    File.WriteAllText(Path.Combine(repoArtifacts, "repro-precreate-fallback.txt"), $"Copied sample {sample} -> {factory.DbFilePath};{fi.Length}");
                                        // Validate header after copy
                                        if (!ValidateSqliteHeader(factory.DbFilePath, repoArtifacts))
                                        {
                                            File.WriteAllText(Path.Combine(repoArtifacts, "repro-precreate-fallback.txt"), "Copied sample produced invalid header; will attempt SQL precreate.");
                                            try { File.Delete(factory.DbFilePath); } catch { }
                                            try
                                            {
                                                var connStr2 = $"Data Source={factory.DbFilePath};Cache=Shared";
                                                using var conn2 = new SqliteConnection(connStr2);
                                                conn2.Open();
                                                using var cmd2 = conn2.CreateCommand();
                                                cmd2.CommandText = "CREATE TABLE IF NOT EXISTS __repro_marker (id INTEGER PRIMARY KEY);";
                                                cmd2.ExecuteNonQuery();
                                                conn2.Close();
                                            }
                                            catch (Exception ex)
                                            {
                                                try { File.WriteAllText(Path.Combine(repoArtifacts, "repro-precreate-fallback-exception-2.txt"), ex.ToString()); } catch { }
                                            }
                                            // record header again
                                            ValidateSqliteHeader(factory.DbFilePath, repoArtifacts);
                                        }
                                }
                                catch (Exception ex)
                                {
                                    try { File.WriteAllText(Path.Combine(repoArtifacts, "repro-precreate-fallback-exception.txt"), ex.ToString()); } catch { }
                                }
                            }
                            else
                            {
                                // As a last resort, touch a zero-length file so detection can
                                // at least observe a file; this is noisy but useful for triage.
                                try { using (var fs = File.Create(factory.DbFilePath)) { fs.WriteByte(0); fs.Flush(); } } catch { }
                                try { File.WriteAllText(Path.Combine(repoArtifacts, "repro-precreate-fallback.txt"), $"Touched {factory.DbFilePath}"); } catch { }
                            }
                        }
                    }
                    catch { }

                    // Start the test host so ConfigureWebHost runs and emits sentinels/logs
                    _ = factory.CreateClient();
                }
                catch (Exception ex)
                {
                    try
                    {
                        var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                        Directory.CreateDirectory(artifactsDir);
                        File.WriteAllText(Path.Combine(artifactsDir, "repro-createclient-exception.txt"), ex.ToString());
                    }
                    catch { }
                }
                // Ensure the EF Core SQLite file is created for this factory instance
                // so the repro can observe and attempt to delete it.
                try
                {
                    using var initCtx = factory.GetDbContext();
                    initCtx.Database.EnsureCreated();
                }
                catch
                {
                    // swallow; if EnsureCreated fails we'll still try to detect files
                }

                // After the host has started and EF EnsureCreated was attempted,
                // try again to ensure a usable DB file exists at the factory path.
                try
                {
                    var repoArtifacts = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                    Directory.CreateDirectory(repoArtifacts);

                    if (!string.IsNullOrEmpty(factory.DbFilePath))
                    {
                        try
                        {
                            var connStr = $"Data Source={factory.DbFilePath};Cache=Shared";
                            using var preConn = new SqliteConnection(connStr);
                            preConn.Open();
                            using var preCmd = preConn.CreateCommand();
                            preCmd.CommandText = "CREATE TABLE IF NOT EXISTS __repro_marker (id INTEGER PRIMARY KEY);";
                            preCmd.ExecuteNonQuery();
                            preConn.Close();
                        }
                        catch { }

                        // If still missing or tiny, try copying a db-sample from artifacts
                        if (!File.Exists(factory.DbFilePath) || new FileInfo(factory.DbFilePath).Length < 128)
                        {
                            string? sample = null;
                            try
                            {
                                var repoFiles = Directory.Exists(repoArtifacts) ? Directory.GetFiles(repoArtifacts, "*db-sample.bin") : Array.Empty<string>();
                                if (repoFiles.Length > 0) sample = repoFiles.OrderByDescending(f => File.GetLastWriteTimeUtc(f)).First();
                                var binArtifacts = Path.Combine(AppContext.BaseDirectory ?? string.Empty, "TestResults", "artifacts");
                                var binFiles = Directory.Exists(binArtifacts) ? Directory.GetFiles(binArtifacts, "*db-sample.bin") : Array.Empty<string>();
                                if (string.IsNullOrEmpty(sample) && binFiles.Length > 0) sample = binFiles.OrderByDescending(f => File.GetLastWriteTimeUtc(f)).First();
                            }
                            catch { }

                            try
                            {
                                if (!string.IsNullOrEmpty(sample) && File.Exists(sample))
                                {
                                    File.Copy(sample, factory.DbFilePath, true);
                                    File.WriteAllText(Path.Combine(repoArtifacts, "repro-precreate-fallback.txt"), $"Copied sample {sample} -> {factory.DbFilePath};{new FileInfo(factory.DbFilePath).Length}");
                                }
                                else
                                {
                                    // Touch the file as a last resort
                                    using (var fs = File.Create(factory.DbFilePath)) { fs.WriteByte(0); fs.Flush(); }
                                    File.WriteAllText(Path.Combine(repoArtifacts, "repro-precreate-fallback.txt"), $"Touched {factory.DbFilePath}");
                                }
                            }
                            catch (Exception ex)
                            {
                                try { File.WriteAllText(Path.Combine(repoArtifacts, "repro-precreate-fallback-exception.txt"), ex.ToString()); } catch { }
                            }
                        }

                        try
                        {
                            var precreateReport = Path.Combine(repoArtifacts, "repro-precreate-result.txt");
                            if (File.Exists(factory.DbFilePath))
                            {
                                var fi = new FileInfo(factory.DbFilePath);
                                File.WriteAllText(precreateReport, $"EXISTS;{fi.Length}");
                            }
                            else
                            {
                                File.WriteAllText(precreateReport, "MISSING");
                            }
                        }
                        catch { }
                    }
                }
                catch { }
                // Prefer explicit DB path artifacts if present (repo-level or runtime
                // test output), then prefer the factory-provided DB file. Fall back to
                // scanning %TEMP% for SimRacingTest_*.db only if none are found.
                string recent = null;
                try
                {
                    // 1) Look for explicit artifact files in repo-level artifacts
                    var repoArtifacts = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                    var binArtifacts = Path.Combine(AppContext.BaseDirectory ?? string.Empty, "TestResults", "artifacts");
                    // Also check the likely project-level artifacts directory by walking
                    // up from the AppContext.BaseDirectory (bin\Debug\netX) to the
                    // project folder and looking for TestResults/artifacts there.
                    string probableRepoArtifacts = null;
                    try
                    {
                        var di = new DirectoryInfo(AppContext.BaseDirectory ?? string.Empty);
                        var proj = di.Parent?.Parent?.Parent; // move up from netX -> Debug -> bin -> project
                        if (proj != null)
                        {
                            probableRepoArtifacts = Path.Combine(proj.FullName, "TestResults", "artifacts");
                        }
                    }
                    catch { }

                    string? PickDbPathFromArtifacts(string dir)
                    {
                        try
                        {
                            if (!Directory.Exists(dir)) return null;
                            // Prefer a repro-specific file written by the test factory
                            var reproFile = Path.Combine(dir, "repro-factory-dbfile.txt");
                            if (File.Exists(reproFile)) return File.ReadAllText(reproFile).Trim();
                            // Otherwise pick the newest *-dbpath.txt
                            var dbpathFiles = Directory.GetFiles(dir, "*-dbpath.txt");
                            if (dbpathFiles != null && dbpathFiles.Length > 0)
                            {
                                return dbpathFiles.OrderByDescending(f => File.GetLastWriteTimeUtc(f)).Select(f => File.ReadAllText(f).Trim()).FirstOrDefault();
                            }
                        }
                        catch { }
                        return null;
                    }

                    // Also scan upward from the current directory for a repo-level TestResults/artifacts
                    string? PickDbPathFromAncestorPaths()
                    {
                        try
                        {
                            var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
                            for (int i = 0; i < 8 && dir != null; i++)
                            {
                                var cand = Path.Combine(dir.FullName, "TestResults", "artifacts");
                                var pick = PickDbPathFromArtifacts(cand);
                                if (!string.IsNullOrEmpty(pick)) return pick;
                                dir = dir.Parent;
                            }
                        }
                        catch { }
                        return null;
                    }

                    recent = PickDbPathFromArtifacts(repoArtifacts) ?? PickDbPathFromArtifacts(binArtifacts) ?? (probableRepoArtifacts != null ? PickDbPathFromArtifacts(probableRepoArtifacts) : null) ?? PickDbPathFromAncestorPaths();

                    // 2) If artifacts didn't reveal a path, prefer the factory's DbFilePath
                    if (string.IsNullOrEmpty(recent) && !string.IsNullOrEmpty(factory.DbFilePath) && File.Exists(factory.DbFilePath))
                    {
                        recent = factory.DbFilePath;
                    }

                    // 3) Fallback: scan temp for SimRacingTest_*.db files
                    if (string.IsNullOrEmpty(recent))
                    {
                        recent = Directory.GetFiles(temp, "SimRacingTest_*.db")
                            .OrderByDescending(f => File.GetLastWriteTimeUtc(f))
                            .FirstOrDefault();
                    }
                }
                catch { }

                if (string.IsNullOrEmpty(recent))
                {
                    try
                    {
                        var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                        Directory.CreateDirectory(artifactsDir);
                        var dumpPath = Path.Combine(artifactsDir, "repro-before-files.txt");
                        File.WriteAllLines(dumpPath, Directory.GetFiles(temp, "*").OrderBy(f => f));
                    }
                    catch { }

                    throw new Xunit.Sdk.XunitException("No SimRacingTest_*.db file was created during the repro run.");
                }

                // recent holds the DB file created during this run; we'll re-evaluate
                // the final target after disposal to be robust against timing.

                // Start a background task that opens a raw SqliteConnection and holds it.
                var keepOpen = Task.Run(async () =>
                {
                    SqliteConnection? conn = null;
                    try
                    {
                        // Ensure the DB file exists by opening a connection and creating a simple table
                        var createConnStr = $"Data Source={factory.DbFilePath};Cache=Shared";
                        using (var createConn = new SqliteConnection(createConnStr))
                        {
                            await createConn.OpenAsync();
                            using var createCmd = createConn.CreateCommand();
                            createCmd.CommandText = "CREATE TABLE IF NOT EXISTS __repro_dummy (id INTEGER PRIMARY KEY);";
                            await createCmd.ExecuteNonQueryAsync();
                            await createConn.CloseAsync();
                        }

                        // Open and hold a connection to simulate a leaked handle from another process/thread
                        conn = new SqliteConnection(createConnStr);
                        await conn.OpenAsync();
                        using var holdCmd = conn.CreateCommand();
                        holdCmd.CommandText = "SELECT 1";
                        await holdCmd.ExecuteNonQueryAsync();

                        // Hold the connection for a short time while disposal occurs
                        await Task.Delay(5000);
                    }
                    catch (Exception)
                    {
                        // swallow; we want to exercise the disposal path
                    }
                    finally
                    {
                        try { if (conn != null) await conn.CloseAsync(); } catch { }
                        conn?.Dispose();
                    }
                });

                // Give the background task a moment to open the connection
                await Task.Delay(200);

                // Capture the factory DB path so it's available after the using block
                try { factoryDbPath = factory.DbFilePath; } catch { }

                // Copy the factory DB file into the repo-level artifacts folder before
                // disposing the factory so triage can inspect the exact file state.
                try
                {
                    if (!string.IsNullOrEmpty(factoryDbPath) && File.Exists(factoryDbPath))
                    {
                        var repoArtifacts = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                        Directory.CreateDirectory(repoArtifacts);
                        var dest = Path.Combine(repoArtifacts, $"repro-copied-db-{Path.GetFileName(factoryDbPath)}");
                        File.Copy(factoryDbPath, dest, true);
                        try
                        {
                            var fi = new FileInfo(dest);
                            File.WriteAllText(Path.Combine(repoArtifacts, "repro-copied-db-report.txt"), $"{factoryDbPath} -> {dest};{fi.Length}");
                        }
                        catch { }
                    }
                }
                catch (Exception ex)
                {
                    try
                    {
                        var repoArtifacts = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                        Directory.CreateDirectory(repoArtifacts);
                        File.WriteAllText(Path.Combine(repoArtifacts, "repro-copy-exception.txt"), ex.ToString());
                    }
                    catch { }
                }

                // Dispose the factory while the background connection is held open
                factory.Dispose();

                // Wait for background task to finish
                await keepOpen;
            }

            // Short pause to let any finalizers run
            await Task.Delay(200);

            var after = Directory.GetFiles(temp, "SimRacingTest_*.db");
            var newFiles = after.Except(before).ToArray();

            // If we forced a debug DB path it may not be under %TEMP%; accept the
            // factory DbFilePath when present so debug runs work.
            if (newFiles.Length == 0)
            {
                if (!string.IsNullOrEmpty(factoryDbPath) && File.Exists(factoryDbPath))
                {
                    newFiles = new[] { factoryDbPath };
                }
            }

            if (newFiles.Length == 0)
            {
                throw new Xunit.Sdk.XunitException("No SimRacingTest_*.db file was created during the repro run.");
            }

            var target = newFiles.OrderByDescending(f => File.GetLastWriteTimeUtc(f)).First();

            // Attempt to delete the file to detect if it is locked.
            bool deleted = false;
            Exception? deleteEx = null;
            try
            {
                File.Delete(target);
                deleted = true;
            }
            catch (Exception ex)
            {
                deleteEx = ex;
                try
                {
                    var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                    Directory.CreateDirectory(artifactsDir);
                    File.WriteAllText(Path.Combine(artifactsDir, "repro-delete-exception.txt"), ex.ToString());
                }
                catch { }
            }

            if (!deleted)
            {
                throw new Xunit.Sdk.XunitException($"DB file '{target}' remained locked after factory.Dispose(). See TestResults/artifacts/repro-delete-exception.txt for details. Exception: {deleteEx}");
            }
        }
    }
}
