using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using USBDeviceManager.Models;
using USBDeviceManager.Services.Abstractions;

namespace USBDeviceManager.Services.Usb
{
    public class InMemoryUsbDeviceProvider : IUsbDeviceProvider
    {
        private readonly ConcurrentDictionary<string, UsbDevice> _devices = new ConcurrentDictionary<string, UsbDevice>();

        public Task<IEnumerable<UsbDevice>> GetConnectedDevicesAsync()
        {
            return Task.FromResult(_devices.Values.AsEnumerable());
        }

        public Task SimulateAttachAsync(UsbDevice device)
        {
            _devices[device.DeviceId] = device;
            return Task.CompletedTask;
        }

        public Task SimulateDetachAsync(string deviceId)
        {
            _devices.TryRemove(deviceId, out _);
            return Task.CompletedTask;
        }
    }
}
