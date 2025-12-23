using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace USBDeviceManager.Adapters
{
    public class DeviceAdapterStub : IDeviceAdapter
    {
        public Task<IEnumerable<string>> ProbeAttachedDevicesAsync(CancellationToken cancellationToken = default)
        {
            // Lightweight stub for development / tests — return empty list.
            return Task.FromResult<IEnumerable<string>>(Array.Empty<string>());
        }
    }
}
