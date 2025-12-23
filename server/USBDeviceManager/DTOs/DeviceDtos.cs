// <copyright file="DeviceDtos.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using System.ComponentModel.DataAnnotations;
    using USBDeviceManager.Models;

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

    public static class DeviceDtoMappings
    {
        public static UsbDevice ToModel(this DeviceCreateDto dto)
        {
            return new UsbDevice
            {
                DeviceId = dto.DeviceId,
                Name = dto.Name,
                VendorId = dto.VendorId,
                ProductId = dto.ProductId,
                Description = dto.Description,
                IsEnabled = dto.IsEnabled,
                CreatedAt = System.DateTime.UtcNow,
                LastSeen = System.DateTime.UtcNow,
            };
        }
    }
}
