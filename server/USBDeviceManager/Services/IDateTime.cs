// <copyright file="IDateTime.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Services
{
    using System;

    /// <summary>
    /// Provides an abstraction over system time for easier testing.
    /// </summary>
    public interface IDateTime
    {
        /// <summary>
        /// Gets the current UTC time.
        /// </summary>
        DateTime UtcNow { get; }
    }
    
}
