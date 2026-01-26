// <copyright file="SoftwareDtoMappings.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using USBDeviceManager.Models;

    /// <summary>
    /// Mapping helpers for software-related DTOs.
    /// </summary>
    public static class SoftwareDtoMappings
    {
        /// <summary>
        /// Maps a <see cref="SoftwareCreateDto"/> to a <see cref="ManagedSoftware"/> model.
        /// </summary>
        /// <param name="dto">Source DTO.</param>
        /// <returns>New <see cref="ManagedSoftware"/> instance populated from the DTO.</returns>
        public static ManagedSoftware ToModel(this SoftwareCreateDto dto)
        {
            return new ManagedSoftware
            {
                Name = dto.Name,
                ExecutablePath = dto.ExecutablePath,
                StartupArguments = dto.StartupArguments,
                WorkingDirectory = dto.WorkingDirectory,
                AutoStart = dto.AutoStart,
                IsEnabled = dto.IsEnabled,
                CreatedAt = System.DateTime.UtcNow,
            };
        }
    }
}
