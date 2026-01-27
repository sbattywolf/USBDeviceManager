using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using FluentAssertions;
using USBDeviceManager.Services.Platform;
using Xunit;

namespace USBDeviceManager.Tests.Unit.Adapters
{
    public class ShellRunnerTests
    {
        private static (string file, string args, string longFile, string longArgs) ResolveCommands()
        {
            // Allow CI to override the long-running command via environment variable
            // Format: SHELLRUNNER_LONG_CMD = "file|args"
            var overrideCmd = Environment.GetEnvironmentVariable("SHELLRUNNER_LONG_CMD");
            if (!string.IsNullOrWhiteSpace(overrideCmd))
            {
                var parts = overrideCmd.Split(new[] { '|' }, 2);
                if (parts.Length == 2)
                {
                    var longFile = parts[0];
                    var longArgs = parts[1];
                    if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                    {
                        return ("cmd.exe", "/c echo HelloShell", longFile, longArgs);
                    }
                    else
                    {
                        return ("/bin/echo", "HelloShell", longFile, longArgs);
                    }
                }
            }

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                // Default for Windows: PowerShell Start-Sleep
                return ("cmd.exe", "/c echo HelloShell", "powershell", "-Command Start-Sleep -Seconds 30");
            }
            else
            {
                // Default for Unix: bash sleep
                return ("/bin/echo", "HelloShell", "/bin/bash", "-c \"sleep 30\"");
            }
        }

        [Fact]
        public async Task RunAsync_ReturnsOutputAndZeroExit()
        {
            var (file, args, _, _) = ResolveCommands();
            var sut = new ShellRunner();

            var res = await sut.RunAsync(file, args);

            res.ExitCode.Should().Be(0);
            res.StdOut.Should().Contain("HelloShell");
        }

        [Fact]
        public async Task RunAsync_Cancellation_TriggersTaskCanceled()
        {
            var (_, _, longFile, longArgs) = ResolveCommands();
            var sut = new ShellRunner();

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(2));

            await Assert.ThrowsAsync<TaskCanceledException>(async () =>
            {
                await sut.RunAsync(longFile, longArgs, cancellationToken: cts.Token);
            });
        }
    }
}
