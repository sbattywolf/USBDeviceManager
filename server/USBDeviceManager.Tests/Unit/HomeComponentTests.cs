using System;
using System.Net.Http;
using Bunit;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using USBDeviceManager.Components.Pages;
using USBDeviceManager.Services;
using Xunit;

namespace USBDeviceManager.Tests.Unit
{
    [Trait("Category","Unit")]
    public class HomeComponentTests : TestContext
    {
        [Fact]
        public void Home_RendersHeader_WhenRendered()
        {
            // Arrange - register a DashboardClient (uses HttpClient) and minimal JS runtime
            var http = new HttpClient() { BaseAddress = new Uri("http://localhost") };
            Services.AddSingleton(new DashboardClient(http));
            Services.AddSingleton<Microsoft.JSInterop.IJSRuntime>(new Mock<Microsoft.JSInterop.IJSRuntime>().Object);

            // Act
            var cut = RenderComponent<Home>();

            // Assert
            cut.Markup.Should().Contain("USB Device Manager");
        }
    }
}
