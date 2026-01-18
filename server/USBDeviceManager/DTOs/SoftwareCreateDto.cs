// <copyright file="SoftwareCreateDto.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using System.ComponentModel.DataAnnotations;

    /// <summary>
    /// DTO used to create or update a `ManagedSoftware` entry.
    /// </summary>
    public class SoftwareCreateDto
    {
        /// <summary>
        /// Gets or sets the display name of the software.
        /// </summary>
        [Required]
        public string Name { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the path to the executable.
        /// </summary>
        [Required]
        public string ExecutablePath { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets optional startup arguments.
        /// </summary>
        public string? StartupArguments
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets the working directory for the process.
        /// </summary>
        public string? WorkingDirectory
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets a value indicating whether the software should auto-start.
        /// </summary>
        public bool AutoStart { get; set; } = false;

        /// <summary>
        /// Gets or sets a value indicating whether the software entry is enabled.
        /// </summary>
        public bool IsEnabled { get; set; } = true;
    }
}
