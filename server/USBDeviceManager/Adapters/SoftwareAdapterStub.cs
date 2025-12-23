// <copyright file="SoftwareAdapterStub.cs" company="PlaceholderCompany">
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
    /// In-memory stub of <see cref="ISoftwareAdapter"/> used for tests and CI.
    /// Returns predictable defaults and performs no real installation operations.
    /// </summary>
    public class SoftwareAdapterStub : ISoftwareAdapter
    {
        /// <summary>
        /// Returns an empty set of managed software entries.
        /// </summary>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>Empty collection of <see cref="ManagedSoftware"/>.</returns>
        public Task<IEnumerable<ManagedSoftware>> GetInstalledAsync(CancellationToken cancellationToken = default)
        {
            return Task.FromResult<IEnumerable<ManagedSoftware>>(Array.Empty<ManagedSoftware>());
        }

        /// <summary>
        /// Returns a default <see cref="SoftwareStatus"/> for the requested software id.
        /// </summary>
        /// <param name="softwareId">Identifier of the managed software.</param>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>A <see cref="SoftwareStatus"/> instance indicating not-running state.</returns>
        public Task<SoftwareStatus> GetSoftwareStatusAsync(int softwareId, CancellationToken cancellationToken = default)
        {
            return Task.FromResult(new SoftwareStatus { SoftwareId = softwareId, IsRunning = false, Timestamp = DateTime.UtcNow });
        }

        /// <summary>
        /// No-op install operation in the stub.
        /// </summary>
        /// <param name="software">Managed software to install (ignored).</param>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        public Task InstallAsync(ManagedSoftware software, CancellationToken cancellationToken = default)
        {
            // No-op in stub implementation.
            return Task.CompletedTask;
        }
    }
}
