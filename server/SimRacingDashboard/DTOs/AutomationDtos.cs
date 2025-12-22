// <copyright file="AutomationDtos.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SimRacingDashboard.DTOs
{
    using System.ComponentModel.DataAnnotations;
    using SimRacingDashboard.Models;

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

    public static class AutomationDtoMappings
    {
        public static AutomationRule ToModel(this AutomationRuleCreateDto dto)
        {
            return new AutomationRule
            {
                Name = dto.Name,
                Description = dto.Description,
                Trigger = dto.Trigger,
                Action = dto.Action,
                TriggerDeviceId = dto.TriggerDeviceId,
                TargetSoftwareId = dto.TargetSoftwareId,
                IsEnabled = dto.IsEnabled,
            };
        }
    }
}
