// <copyright file="ValidationFilter.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Filters
{
    using System.Linq;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.AspNetCore.Mvc.Filters;

    /// <summary>
    /// Simple validation filter that returns consistent BadRequest responses
    /// when model binding/validation fails.
    /// </summary>
    public class ValidationFilter : IActionFilter
    {
        /// <inheritdoc/>
        public void OnActionExecuting(ActionExecutingContext context)
        {
            if (context?.ModelState == null)
            {
                return;
            }

            if (!context.ModelState.IsValid)
            {
                var errors = context.ModelState
                    .Where(kvp => kvp.Value != null && kvp.Value.Errors != null && kvp.Value.Errors.Count > 0)
                    .ToDictionary(
                        kvp => kvp.Key,
                        kvp => kvp.Value.Errors.Select(e => e.ErrorMessage).ToArray());

                context.Result = new BadRequestObjectResult(new { errors = errors });
            }
        }

        /// <inheritdoc/>
        public void OnActionExecuted(ActionExecutedContext context)
        {
            // no-op
        }
    }
}
