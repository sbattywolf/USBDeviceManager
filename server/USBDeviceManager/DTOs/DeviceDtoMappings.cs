// <copyright file="DeviceDtoMappings.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using USBDeviceManager.Models;

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
