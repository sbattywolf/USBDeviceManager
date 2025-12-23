// <copyright file="ConfigCreateDto.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs;

public class ConfigCreateDto
{
    public string? DeviceId
    {
        get; set;
    }

    public string? FriendlyName
    {
        get; set;
    }

    public string? UsbPort
    {
        get; set;
    }

    public string? VendorId
    {
        get; set;
    }

    public string? ProductId
    {
        get; set;
    }

    // Software/run settings
    public string? TriggerPath
    {
        get; set;
    }

    public string? SoftwareName
    {
        get; set;
    }

    public string? TriggerParams
    {
        get; set;
    }

    public string? WorkingDirectory
    {
        get; set;
    }

    public bool? IsEnabled
    {
        get; set;
    }
}
