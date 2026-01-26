using System.IO;
using Bunit;
using Microsoft.Extensions.DependencyInjection;
using FluentAssertions;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using USBDeviceManager.Services;
using USBDeviceManager.Pages;
using Xunit;

namespace USBDeviceManager.Tests.Unit
{
    [Trait("Category","Unit")]
    public class ServerStatusComponentTests
    {
        class TestHostEnvironment : IHostEnvironment
        {
            public string EnvironmentName { get; set; } = "Testing";
            public string ApplicationName { get; set; } = "USBDeviceManager.Tests";
            public string ContentRootPath { get; set; }
            public IFileProvider ContentRootFileProvider { get; set; }
        }

        [Fact]
        public void ServerStatus_RendersHeading_WhenRendered()
        {
            using var ctx = new TestContext();
            // register a StatusService that uses a temp content root
            var temp = Path.Combine(Path.GetTempPath(), "usbdevicemgr_test_" + System.Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(temp);
            var env = new TestHostEnvironment { ContentRootPath = temp };
            var status = new StatusService(env);
            ctx.Services.AddSingleton(status);
            // Register minimal supporting services for component rendering
            // Fake HttpClient that returns 404 for backend calls
            var fakeHttp = new USBDeviceManager.BlazorTests.TestHelpers.FakeHttpMessageHandler();
            var httpClient = new System.Net.Http.HttpClient(fakeHttp) { BaseAddress = new System.Uri("http://localhost/") };
            ctx.Services.AddSingleton<System.Net.Http.HttpClient>(httpClient);
            // Test navigation manager
            ctx.Services.AddSingleton<Microsoft.AspNetCore.Components.NavigationManager>(new USBDeviceManager.BlazorTests.TestHelpers.TestNavigationManager());

            var cut = ctx.RenderComponent<ServerStatus>();

            cut.Markup.Should().Contain("Server & Agent Status");
        }
    }
}
