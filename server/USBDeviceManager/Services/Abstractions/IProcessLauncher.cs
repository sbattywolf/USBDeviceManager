using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

namespace USBDeviceManager.Services.Abstractions
{
    public interface IProcessLauncher
    {
        /// <summary>
        /// Start a process and return the Process instance if started successfully.
        /// </summary>
        Process? Start(string fileName, string args, string? workingDirectory = null);

        /// <summary>
        /// Run a process to completion and return the exit code.
        /// </summary>
        Task<int> RunAsync(string fileName, string args, string? workingDirectory = null, CancellationToken cancellationToken = default);

        /// <summary>
        /// Attempt to stop a running process by PID.
        /// </summary>
        bool TryStop(int pid);
    }
}
