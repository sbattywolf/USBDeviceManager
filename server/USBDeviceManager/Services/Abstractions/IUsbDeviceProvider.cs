using System.Collections.Generic;
using System.Threading.Tasks;
using USBDeviceManager.Models;

namespace USBDeviceManager.Services.Abstractions
{
    public interface IUsbDeviceProvider
    {
        /// <summary>
        /// Returns currently connected USB devices.
        /// </summary>
        Task<IEnumerable<UsbDevice>> GetConnectedDevicesAsync();

        /// <summary>
        /// Simulate attaching a USB device (for tests).
        /// </summary>
        Task SimulateAttachAsync(UsbDevice device);

        /// <summary>
        /// Simulate detaching a USB device (for tests).
        /// </summary>
        Task SimulateDetachAsync(string deviceId);
    }
}
