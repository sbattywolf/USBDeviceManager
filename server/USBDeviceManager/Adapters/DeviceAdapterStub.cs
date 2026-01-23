// <copyright file="DeviceAdapterStub.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Adapters
{
    using System;
    using System.Collections.Generic;
    using System.Threading;
    using System.Threading.Tasks;
    using USBDeviceManager.Models;

    /// <summary>
    /// Lightweight in-memory stub implementation of <see cref="IDeviceAdapter"/> used for testing and CI.
    /// This implementation performs no real hardware operations and returns predictable defaults.
    /// </summary>
    public class DeviceAdapterStub : IDeviceAdapter
    {
        /// <summary>
        /// Returns an empty set of connected devices for CI/tests.
        /// </summary>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>Empty collection of <see cref="UsbDevice"/>.</returns>
        public Task<IEnumerable<UsbDevice>> GetConnectedDevicesAsync(CancellationToken cancellationToken = default)
        {
            return Task.FromResult<IEnumerable<UsbDevice>>(Array.Empty<UsbDevice>());
        }

        /// <summary>
        /// Returns a default <see cref="DeviceStatus"/> for the requested device id.
        /// </summary>
        /// <param name="deviceId">Identifier of the device.</param>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>A <see cref="DeviceStatus"/> instance indicating disconnected state.</returns>
        public Task<DeviceStatus> GetDeviceStatusAsync(int deviceId, CancellationToken cancellationToken = default)
        {
            return Task.FromResult(new DeviceStatus { DeviceId = deviceId, IsConnected = false, Timestamp = DateTime.UtcNow });
        }

        /// <summary>
        /// No-op register operation in the stub.
        /// </summary>
        /// <param name="device">Device to register (ignored).</param>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
        public Task RegisterDeviceAsync(UsbDevice device, CancellationToken cancellationToken = default)
        {
            // No-op stub for tests and CI environments.
            return Task.CompletedTask;
        }
    }
}
