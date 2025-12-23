// <copyright file="SoftwareCreateDto.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using System.ComponentModel.DataAnnotations;

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
}
