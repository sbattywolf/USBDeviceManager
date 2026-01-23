// <copyright file="DeviceEventRequest.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    /// <summary>
    /// Request representing a device event (connected/disconnected) sent to compatibility endpoints.
    /// </summary>
    public class DeviceEventRequest
    {
        /// <summary>
        /// Gets or sets the numeric device identifier for the event.
        /// </summary>
        public int DeviceId
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets the event type: "connected" or "disconnected".
        /// </summary>
        public string EventType { get; set; } = string.Empty;
    }
}
