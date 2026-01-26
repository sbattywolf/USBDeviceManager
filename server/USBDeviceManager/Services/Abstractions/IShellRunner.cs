using System.Threading;
using System.Threading.Tasks;

namespace USBDeviceManager.Services.Abstractions
{
    public record ShellResult(int ExitCode, string StdOut, string StdErr);

    public interface IShellRunner
    {
        /// <summary>
        /// Execute a shell command and capture stdout/stderr and exit code.
        /// </summary>
        Task<ShellResult> RunAsync(string command, string args, string? workingDirectory = null, CancellationToken cancellationToken = default);
    }
}
