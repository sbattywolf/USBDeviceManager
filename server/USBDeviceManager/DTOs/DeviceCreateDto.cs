// <copyright file="DeviceCreateDto.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using System.ComponentModel.DataAnnotations;

    public class DeviceCreateDto
    {
        [Required]
        public string DeviceId { get; set; } = string.Empty;

        [Required]
        public string Name { get; set; } = string.Empty;

        public string? VendorId
        {
            get; set;
        }

        public string? ProductId
        {
            get; set;
        }

        public string? Description
        {
            get; set;
        }

        public bool IsEnabled { get; set; } = true;
    }
}
