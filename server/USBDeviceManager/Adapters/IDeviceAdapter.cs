namespace USBDeviceManager.Adapters
{
    public interface IDeviceAdapter
    {
        // Probe attached devices and return a simple list of identifiers.
        Task<IEnumerable<string>> ProbeAttachedDevicesAsync(CancellationToken cancellationToken = default);
    }
}
