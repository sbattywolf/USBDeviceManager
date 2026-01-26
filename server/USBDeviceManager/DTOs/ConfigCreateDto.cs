// <copyright file="ConfigCreateDto.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs;

/// <summary>
/// DTO used to create a combined device/software automation configuration via the compatibility API.
/// </summary>
public class ConfigCreateDto
{
    /// <summary>
    /// Gets or sets an optional device identifier to configure.
    /// </summary>
    public string? DeviceId
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets an optional friendly name for the configuration.
    /// </summary>
    public string? FriendlyName
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the USB port label or identifier.
    /// </summary>
    public string? UsbPort
    {
        get; set;
    }

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

    // Software/run settings

    /// <summary>
    /// Gets or sets the path that triggers automation.
    /// </summary>
    public string? TriggerPath
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the name of the software to run.
    /// </summary>
    public string? SoftwareName
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets trigger parameters for the software run.
    /// </summary>
    public string? TriggerParams
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the working directory for the software run.
    /// </summary>
    public string? WorkingDirectory
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets an optional enabled flag for the configuration.
    /// </summary>
    public bool? IsEnabled
    {
        get; set;
    }
}
