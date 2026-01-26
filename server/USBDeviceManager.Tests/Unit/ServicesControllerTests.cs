using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using USBDeviceManager.Controllers;
using USBDeviceManager.Services;
using Xunit;

namespace USBDeviceManager.Tests.Unit
{
    class TestHostEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Testing";
        public string ApplicationName { get; set; } = "USBDeviceManager.Tests";
        public string ContentRootPath { get; set; }
        public IFileProvider ContentRootFileProvider { get; set; }
    }

    public class ServicesControllerTests
    {
        [Fact]
        public async Task SaveConfig_Then_GetConfig_ReturnsSavedValues()
        {
            var temp = Path.Combine(Path.GetTempPath(), "usbdevicemgr_test_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(temp);
            var env = new TestHostEnvironment { ContentRootPath = temp };
            var status = new StatusService(env);
            var controller = new ServicesController(status);

            var cfg = new ServiceConfig { ServerPort = 54321, AgentPort = 54322, AgentMode = "External" };
            var saveResult = await controller.SaveConfig(cfg) as OkObjectResult;
            Assert.NotNull(saveResult);
            var saved = Assert.IsType<ServiceConfig>(saveResult.Value);
            Assert.Equal(54321, saved.ServerPort);

            var getResult = controller.GetConfig() as OkObjectResult;
            Assert.NotNull(getResult);
            var got = Assert.IsType<ServiceConfig>(getResult.Value);
            Assert.Equal(54321, got.ServerPort);
        }
    }
}
