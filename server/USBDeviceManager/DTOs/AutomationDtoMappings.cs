// <copyright file="AutomationDtoMappings.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using USBDeviceManager.Models;

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
