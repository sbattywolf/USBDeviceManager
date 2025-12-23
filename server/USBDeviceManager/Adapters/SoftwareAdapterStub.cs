using System;
using System.Threading;
using System.Threading.Tasks;

namespace USBDeviceManager.Adapters
{
    public class SoftwareAdapterStub : ISoftwareAdapter
    {
        public Task<bool> StartAsync(string executablePath, string? args = null, CancellationToken cancellationToken = default)
        {
            // Stub: log the intent (real implementation should start a process)
            return Task.FromResult(true);
        }

        public Task<bool> StopAsync(int processId, CancellationToken cancellationToken = default)
        {
            // Stub: pretend stop succeeded
            return Task.FromResult(true);
        }
    }
}
