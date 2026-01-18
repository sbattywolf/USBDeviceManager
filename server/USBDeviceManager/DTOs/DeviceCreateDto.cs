// <copyright file="DeviceCreateDto.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using System.ComponentModel.DataAnnotations;

    /// <summary>
    /// DTO used to create or update a `UsbDevice` record.
    /// </summary>
    public class DeviceCreateDto
    {
        /// <summary>
        /// Gets or sets the device identifier provided by the platform.
        /// </summary>
        [Required]
        public string DeviceId { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the friendly name for the device.
        /// </summary>
        [Required]
        public string Name { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the optional vendor identifier.
        /// </summary>
        public string? VendorId
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets the optional product identifier.
        /// </summary>
        public string? ProductId
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets an optional description for the device.
        /// </summary>
        public string? Description
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets a value indicating whether the device should be considered enabled.
        /// </summary>
        public bool IsEnabled { get; set; } = true;
    }
}
