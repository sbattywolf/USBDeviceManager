// <copyright file="AutomationDtoMappings.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.DTOs
{
    using USBDeviceManager.Models;

    /// <summary>
    /// Mapping helpers for automation-related DTOs.
    /// </summary>
    public static class AutomationDtoMappings
    {
        /// <summary>
        /// Maps an <see cref="AutomationRuleCreateDto"/> to an <see cref="AutomationRule"/> model instance.
        /// </summary>
        /// <param name="dto">Source DTO.</param>
        /// <returns>A new <see cref="AutomationRule"/> populated from the DTO.</returns>
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
