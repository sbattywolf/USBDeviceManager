using System;
using System.Diagnostics;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using USBDeviceManager.Services.Abstractions;

namespace USBDeviceManager.Services.Platform
{
    public class ShellRunner : IShellRunner
    {
        public async Task<ShellResult> RunAsync(string command, string args, string? workingDirectory = null, CancellationToken cancellationToken = default)
        {
            var psi = new ProcessStartInfo
            {
                FileName = command,
                Arguments = args,
                WorkingDirectory = string.IsNullOrWhiteSpace(workingDirectory) ? Environment.CurrentDirectory : workingDirectory,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
              
            };

            using var proc = new Process { StartInfo = psi, EnableRaisingEvents = true };

            var stdOutBuilder = new StringBuilder();
            var stdErrBuilder = new StringBuilder();

            proc.OutputDataReceived += (_, e) => { if (e.Data != null) stdOutBuilder.AppendLine(e.Data); };
            proc.ErrorDataReceived += (_, e) => { if (e.Data != null) stdErrBuilder.AppendLine(e.Data); };

            var tcs = new TaskCompletionSource<int>(TaskCreationOptions.RunContinuationsAsynchronously);
            proc.Exited += (_, __) => tcs.TrySetResult(proc.ExitCode);

            proc.Start();
            proc.BeginOutputReadLine();
            proc.BeginErrorReadLine();

            using (cancellationToken.Register(() =>
            {
                try { if (!proc.HasExited) proc.Kill(true); } catch { }
                tcs.TrySetCanceled();
            }))
            {
                var exit = await tcs.Task.ConfigureAwait(false);
                return new ShellResult(exit, stdOutBuilder.ToString(), stdErrBuilder.ToString());
            }
        }
    }
}
