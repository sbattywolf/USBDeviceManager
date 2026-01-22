using System;

namespace USBDeviceManager.Services
{
    /// <summary>
    /// Abstraction for current time to allow testing.
    /// </summary>
    public interface IDateTime
    {
        DateTime UtcNow { get; }
        DateTime Now { get; }
    }
}
