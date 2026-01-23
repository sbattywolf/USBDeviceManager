using System.Linq;
using System.Threading.Tasks;
using FluentAssertions;
using USBDeviceManager.Models;
using USBDeviceManager.Services.Usb;
using Xunit;

namespace USBDeviceManager.Tests.Unit.Adapters
{
    public class InMemoryUsbDeviceProviderTests
    {
        [Fact]
        public async Task SimulateAttach_Then_GetConnectedDevices_ReturnsDevice()
        {
            var provider = new InMemoryUsbDeviceProvider();
            var device = new UsbDevice { DeviceId = "dev1", Name = "Wheel" };

            await provider.SimulateAttachAsync(device);

            var devices = (await provider.GetConnectedDevicesAsync()).ToList();

            devices.Should().ContainSingle()
                .Which.DeviceId.Should().Be("dev1");
        }

        [Fact]
        public async Task SimulateDetach_RemovesDevice()
        {
            var provider = new InMemoryUsbDeviceProvider();
            var device = new UsbDevice { DeviceId = "dev2", Name = "Pedals" };

            await provider.SimulateAttachAsync(device);
            await provider.SimulateDetachAsync(device.DeviceId);

            var devices = (await provider.GetConnectedDevicesAsync()).ToList();
            devices.Should().BeEmpty();
        }
    }
}
