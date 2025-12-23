// <copyright file="IDateTime.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Services
{
    using System;

    public interface IDateTime
    {
        DateTime UtcNow
        {
            get;
        }
    }
}
