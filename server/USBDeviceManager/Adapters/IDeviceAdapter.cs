// <copyright file="IDeviceAdapter.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Adapters
{
    using System.Collections.Generic;
    using System.Threading;
    using System.Threading.Tasks;
    using USBDeviceManager.Models;

    /// <summary>
    /// Abstraction for platform-specific device adapter implementations.
    /// Implementations provide discovery, status and registration operations for USB devices.
    /// </summary>
    public interface IDeviceAdapter
    {
        /// <summary>
        /// Returns the currently connected USB devices.
        /// </summary>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>Collection of discovered <see cref="UsbDevice"/> instances.</returns>
        Task<IEnumerable<UsbDevice>> GetConnectedDevicesAsync(CancellationToken cancellationToken = default);

        /// <summary>
        /// Gets the current status for a tracked device.
        /// </summary>
        /// <param name="deviceId">Identifier of the device.</param>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>A <see cref="DeviceStatus"/> snapshot for the requested device.</returns>
        Task<DeviceStatus> GetDeviceStatusAsync(int deviceId, CancellationToken cancellationToken = default);

        /// <summary>
        /// Registers a new device in the system.
        /// </summary>
        /// <param name="device">The device to register.</param>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
        Task RegisterDeviceAsync(UsbDevice device, CancellationToken cancellationToken = default);
    }
}
