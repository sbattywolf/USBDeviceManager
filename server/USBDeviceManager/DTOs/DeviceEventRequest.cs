// <copyright file="DeviceEventRequest.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    public class DeviceEventRequest
    {
        /// <summary>
        /// Request representing a device event (connected/disconnected) sent to compatibility endpoints.
        /// </summary>
        public int DeviceId
        {
            get; set;
        }

        public string EventType { get; set; } = string.Empty; // "connected" or "disconnected"
    }
}
