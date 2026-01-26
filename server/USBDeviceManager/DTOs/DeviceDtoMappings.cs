// <copyright file="DeviceDtoMappings.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using USBDeviceManager.Models;

    /// <summary>
    /// Mapping helpers for device-related DTOs.
    /// </summary>
    public static class DeviceDtoMappings
    {
        /// <summary>
        /// Maps a <see cref="DeviceCreateDto"/> to a <see cref="UsbDevice"/> model instance.
        /// </summary>
        /// <param name="dto">Source DTO.</param>
        /// <returns>New <see cref="UsbDevice"/> instance populated from the DTO.</returns>
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
