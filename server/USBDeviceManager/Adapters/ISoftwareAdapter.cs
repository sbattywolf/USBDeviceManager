// <copyright file="ISoftwareAdapter.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Adapters
{
    using System.Collections.Generic;
    using System.Threading;
    using System.Threading.Tasks;
    using USBDeviceManager.Models;

    /// <summary>
    /// Abstraction for platform-specific software adapter implementations.
    /// Implementations provide discovery, installation, and status operations for managed software.
    /// </summary>
    public interface ISoftwareAdapter
    {
        /// <summary>
        /// Returns the currently detected installed software entries.
        /// </summary>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>Collection of discovered <see cref="ManagedSoftware"/> entries.</returns>
        Task<IEnumerable<ManagedSoftware>> GetInstalledAsync(CancellationToken cancellationToken = default);

        /// <summary>
        /// Gets the current runtime status for a managed software entry.
        /// </summary>
        /// <param name="softwareId">Identifier of the managed software.</param>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>A <see cref="SoftwareStatus"/> snapshot for the requested software entry.</returns>
        Task<SoftwareStatus> GetSoftwareStatusAsync(int softwareId, CancellationToken cancellationToken = default);

        /// <summary>
        /// Installs or queues installation of the specified software.
        /// </summary>
        /// <param name="software">The managed software to install.</param>
        /// <param name="cancellationToken">Cancellation token for the operation.</param>
        /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
        Task InstallAsync(ManagedSoftware software, CancellationToken cancellationToken = default);
    }
}
