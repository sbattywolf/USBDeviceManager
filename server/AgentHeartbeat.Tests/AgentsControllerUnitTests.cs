using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using Microsoft.Extensions.Logging.Abstractions;
using USBDeviceManager.Controllers;
using USBDeviceManager.Services;
using Xunit;
using Microsoft.AspNetCore.Mvc;

namespace AgentHeartbeat.Tests
{
    public class AgentsControllerUnitTests
    {
        private StatusService CreateStatusService(string contentRoot)
        {
            var env = new TestHostEnvironment(contentRoot);
            return new StatusService(env);
        }

        [Fact]
        public void Heartbeat_Allows_WhenExternalMode()
        {
            var sr = CreateStatusService(System.IO.Directory.GetCurrentDirectory());
            sr.SetConfigAsync(new ServiceConfig { AgentMode = "External" }).GetAwaiter().GetResult();

            var ctrl = new AgentsController(new NullLogger<AgentsController>(), sr);
            var result = ctrl.Heartbeat(Guid.NewGuid());
            Assert.IsType<OkObjectResult>(result);
        }

        [Fact]
        public void Heartbeat_Rejects_WhenEmbeddedWithLocalAgent()
        {
            var sr = CreateStatusService(System.IO.Directory.GetCurrentDirectory());
            sr.SetConfigAsync(new ServiceConfig { AgentMode = "Embedded" }).GetAwaiter().GetResult();

            var proc = Process.GetCurrentProcess();
            var t = sr.GetType();
            var field = t.GetField("_processes", BindingFlags.NonPublic | BindingFlags.Instance);
            if (field == null) throw new InvalidOperationException("_processes field not found");
            var dict = field.GetValue(sr) as IDictionary<string, Process>;
            if (dict == null)
            {
                throw new InvalidOperationException("_processes is not accessible");
            }
            dict["agent"] = proc;

            var ctrl = new AgentsController(new NullLogger<AgentsController>(), sr);
            var result = ctrl.Heartbeat(Guid.NewGuid());
            Assert.IsType<ConflictObjectResult>(result);
        }

        [Fact]
        public void Heartbeat_Forbidden_WhenDisabledMode()
        {
            var sr = CreateStatusService(System.IO.Directory.GetCurrentDirectory());
            sr.SetConfigAsync(new ServiceConfig { AgentMode = "Disabled" }).GetAwaiter().GetResult();

            var ctrl = new AgentsController(new NullLogger<AgentsController>(), sr);
            var result = ctrl.Heartbeat(Guid.NewGuid());
            Assert.IsType<ForbidResult>(result);
        }
    }

    internal class TestHostEnvironment : Microsoft.Extensions.Hosting.IHostEnvironment
    {
        public TestHostEnvironment(string contentRoot)
        {
            ApplicationName = "AgentHeartbeat.Tests.Host";
            EnvironmentName = "Development";
            ContentRootPath = contentRoot;
            ContentRootFileProvider = null;
        }

        public string EnvironmentName { get; set; }
        public string ApplicationName { get; set; }
        public string ContentRootPath { get; set; }
        public Microsoft.Extensions.FileProviders.IFileProvider? ContentRootFileProvider { get; set; }
        public string WebRootPath { get; set; }
    }
}
