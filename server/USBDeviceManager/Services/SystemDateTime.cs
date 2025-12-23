// <copyright file="SystemDateTime.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Services
{
    using System;

    public class SystemDateTime : IDateTime
    {
        /// <inheritdoc/>
        public DateTime UtcNow => DateTime.UtcNow;
    }
}
