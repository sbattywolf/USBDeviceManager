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
        /// <summary>
        /// Called before an action executes; validates the model state and returns a BadRequest if invalid.
        /// </summary>
        /// <param name="context">The <see cref="ActionExecutingContext"/> for the current request.</param>
        public void OnActionExecuting(ActionExecutingContext context)
        {
            if (context?.ModelState == null)
            {
                return;
            }

            if (!context.ModelState.IsValid)
            {
                var errors = context.ModelState
                    .Where(kvp => kvp.Value?.Errors?.Count > 0)
                    .ToDictionary(
                        kvp => kvp.Key,
                        kvp => kvp.Value?.Errors.Select(e => e.ErrorMessage).ToArray() ?? System.Array.Empty<string>());

                context.Result = new BadRequestObjectResult(new { errors });
            }
        }

        /// <summary>
        /// Called after an action executes. No-op in this filter.
        /// </summary>
        /// <param name="context">The <see cref="ActionExecutedContext"/> for the current request.</param>
        public void OnActionExecuted(ActionExecutedContext context)
        {
            // no-op
        }
    }
}
