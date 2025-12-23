// <copyright file="Clock.cs" company="PlaceholderCompany">
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

    /// <summary>
    /// Default implementation of <see cref="IDateTime"/> that uses <see cref="DateTime.UtcNow"/>.
    /// </summary>
    public class SystemDateTime : IDateTime
    {
        /// <inheritdoc />
        public DateTime UtcNow => DateTime.UtcNow;
    }
}
