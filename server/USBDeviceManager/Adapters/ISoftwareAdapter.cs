namespace USBDeviceManager.Adapters
{
    public interface ISoftwareAdapter
    {
        // Start an executable and return true on success.
        Task<bool> StartAsync(string executablePath, string? args = null, CancellationToken cancellationToken = default);

        // Stop a running software instance by process id.
        Task<bool> StopAsync(int processId, CancellationToken cancellationToken = default);
    }
}
