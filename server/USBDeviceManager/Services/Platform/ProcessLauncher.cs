using System;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using USBDeviceManager.Services.Abstractions;

namespace USBDeviceManager.Services.Platform
{
    public class ProcessLauncher : IProcessLauncher
    {
        public Process? Start(string fileName, string args, string? workingDirectory = null)
        {
            var psi = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = args,
                WorkingDirectory = string.IsNullOrWhiteSpace(workingDirectory) ? Environment.CurrentDirectory : workingDirectory,
                UseShellExecute = false,
                CreateNoWindow = true,
            };

            var proc = new Process { StartInfo = psi };
            try
            {
                if (proc.Start())
                {
                    return proc;
                }
            }
            catch
            {
                // swallow - caller can inspect return value
            }

            return null;
        }

        public async Task<int> RunAsync(string fileName, string args, string? workingDirectory = null, CancellationToken cancellationToken = default)
        {
            var psi = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = args,
                WorkingDirectory = string.IsNullOrWhiteSpace(workingDirectory) ? Environment.CurrentDirectory : workingDirectory,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            };

            using var proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
            var tcs = new TaskCompletionSource<int>();

            proc.Exited += (_, __) => tcs.TrySetResult(proc.ExitCode);

            proc.Start();

            using (cancellationToken.Register(() =>
            {
                try { if (!proc.HasExited) proc.Kill(true); } catch { }
                tcs.TrySetCanceled();
            }))
            {
                return await tcs.Task.ConfigureAwait(false);
            }
        }

        public bool TryStop(int pid)
        {
            try
            {
                var proc = Process.GetProcessById(pid);
                if (proc != null && !proc.HasExited)
                {
                    proc.Kill(true);
                    return true;
                }
            }
            catch
            {
                // ignore
            }

            return false;
        }
    }
}
