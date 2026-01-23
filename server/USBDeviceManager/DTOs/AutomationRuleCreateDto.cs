// <copyright file="AutomationRuleCreateDto.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using System.ComponentModel.DataAnnotations;
    using USBDeviceManager.Models;

    /// <summary>
    /// DTO for creating or updating an automation rule.
    /// </summary>
    public class AutomationRuleCreateDto
    {
        /// <summary>
        /// Gets or sets the rule name.
        /// </summary>
        [Required]
        public string Name { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets an optional description for the rule.
        /// </summary>
        public string? Description
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets the trigger that will activate the rule.
        /// </summary>
        public AutomationTrigger Trigger
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets the action executed when the rule triggers.
        /// </summary>
        public AutomationAction Action
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets an optional device identifier referenced by the trigger.
        /// </summary>
        public int? TriggerDeviceId
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets an optional target software identifier referenced by the action.
        /// </summary>
        public int? TargetSoftwareId
        {
            get; set;
        }

        /// <summary>
        /// Gets or sets a value indicating whether the rule is enabled.
        /// </summary>
        public bool IsEnabled { get; set; } = true;
    }
}
