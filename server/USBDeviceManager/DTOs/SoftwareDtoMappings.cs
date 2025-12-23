// <copyright file="SoftwareDtoMappings.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using USBDeviceManager.Models;

    public static class SoftwareDtoMappings
    {
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
