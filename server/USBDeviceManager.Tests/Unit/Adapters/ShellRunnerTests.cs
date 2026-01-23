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
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                return ("cmd.exe", "/c echo HelloShell", "ping", "-n 30 127.0.0.1");
            }
            else
            {
                return ("/bin/echo", "HelloShell", "/bin/sleep", "30");
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
