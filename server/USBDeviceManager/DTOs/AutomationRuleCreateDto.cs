// <copyright file="AutomationRuleCreateDto.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using System.ComponentModel.DataAnnotations;
    using USBDeviceManager.Models;

    public class AutomationRuleCreateDto
    {
        [Required]
        public string Name { get; set; } = string.Empty;

        public string? Description
        {
            get; set;
        }

        public AutomationTrigger Trigger
        {
            get; set;
        }

        public AutomationAction Action
        {
            get; set;
        }

        public int? TriggerDeviceId
        {
            get; set;
        }

        public int? TargetSoftwareId
        {
            get; set;
        }

        public bool IsEnabled { get; set; } = true;
    }
}
