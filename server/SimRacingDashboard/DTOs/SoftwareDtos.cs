// <copyright file="SoftwareDtos.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using System.ComponentModel.DataAnnotations;
    using USBDeviceManager.Models;

    public class SoftwareCreateDto
    {
        [Required]
        public string Name { get; set; } = string.Empty;

        [Required]
        public string ExecutablePath { get; set; } = string.Empty;

        public string? StartupArguments
        {
            get; set;
        }

        public string? WorkingDirectory
        {
            get; set;
        }

        public bool AutoStart { get; set; } = false;

        public bool IsEnabled { get; set; } = true;
    }

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
