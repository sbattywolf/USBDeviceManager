using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using FluentAssertions;
using USBDeviceManager.Services.Platform;
using Xunit;

namespace USBDeviceManager.Tests.Unit.Adapters
{
    public class ProcessLauncherTests
    {
        private static (string file, string args, string longFile, string longArgs) ResolveCommands()
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                return ("cmd.exe", "/c echo HelloProc", "ping", "-n 30 127.0.0.1");
            }
            else
            {
                return ("/bin/echo", "HelloProc", "/bin/sleep", "30");
            }
        }

        [Fact]
        public async Task RunAsync_ReturnsExitCodeZero()
        {
            var (file, args, _, _) = ResolveCommands();
            var sut = new ProcessLauncher();

            var code = await sut.RunAsync(file, args);

            code.Should().Be(0);
        }

        [Fact]
        public void Start_ReturnsProcessInstance()
        {
            var (file, args, _, _) = ResolveCommands();
            var sut = new ProcessLauncher();

            var proc = sut.Start(file, args);

            proc.Should().NotBeNull();
            // process for echo/cmd should exit quickly
            proc!.WaitForExit(5000).Should().BeTrue();
        }

        [Fact]
        public void TryStop_KillsLongRunningProcess()
        {
            var (_, _, longFile, longArgs) = ResolveCommands();
            var sut = new ProcessLauncher();

            var proc = sut.Start(longFile, longArgs);
            proc.Should().NotBeNull();

            // give it a moment to start
            Thread.Sleep(500);

            var pid = proc!.Id;

            var stopped = sut.TryStop(pid);

            stopped.Should().BeTrue();
        }
    }
}
