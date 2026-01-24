using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using FluentAssertions;
using USBDeviceManager.Services.Platform;
using Xunit;

namespace USBDeviceManager.Tests.Unit.Adapters
{
    public class LongRunnerShellRunnerTests
    {
        private static string GetPublishedLongRunnerPath()
        {
            var baseDir = AppContext.BaseDirectory; // test assembly folder
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                return null!; // not applicable on non-Windows in this repo
            }

            // Expected CI/test publish path used by repro tooling
            var candidate = Path.Combine(baseDir, "artifacts", "longrunner", "win-x64", "LongRunner.exe");
            if (File.Exists(candidate)) return candidate;

            // fallback: try sibling scripts path (repo root/run location)
            candidate = Path.GetFullPath(Path.Combine(baseDir, "..", "..", "..", "..", "scripts", "ReproWin32", "server", "USBDeviceManager.Tests", "bin", "Debug", "net8.0", "artifacts", "longrunner", "win-x64", "LongRunner.exe"));
            return File.Exists(candidate) ? candidate : null!;
        }

        [Fact]
        public async Task RunAsync_WithPublishedLongRunner_CanBeCancelled()
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) return;

            var longRunner = GetPublishedLongRunnerPath();
            if (string.IsNullOrEmpty(longRunner)) return;

            var sut = new ShellRunner();

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(2));

            await Assert.ThrowsAsync<TaskCanceledException>(async () =>
            {
                // LongRunner accepts `-s <seconds>` or `--sleep <seconds>`; give a long sleep and cancel
                await sut.RunAsync(longRunner, "-s 60", workingDirectory: Path.GetDirectoryName(longRunner), cancellationToken: cts.Token);
            });
        }

        [Fact]
        public async Task RunAsync_WithPublishedLongRunner_ExitsNormally()
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) return;

            var longRunner = GetPublishedLongRunnerPath();
            if (string.IsNullOrEmpty(longRunner)) return;

            var sut = new ShellRunner();

            // Run with a short sleep and allow it to complete
            var res = await sut.RunAsync(longRunner, "-s 1", workingDirectory: Path.GetDirectoryName(longRunner));

            res.ExitCode.Should().Be(0);
        }
    }
}
