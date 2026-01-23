using System;
using System.Net.Http;
using Bunit;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using USBDeviceManager.Pages;
using USBDeviceManager.Services;
using Xunit;

namespace USBDeviceManager.Tests.Unit
{
    [Trait("Category","Unit")]
    public class ServerStatusComponentTests : TestContext
    {
        [Fact]
        public void ServerStatus_RendersHeading_WhenRendered()
        {
            // Arrange
            var http = new HttpClient() { BaseAddress = new Uri("http://localhost") };
            Services.AddSingleton(new StatusService(Environment.CurrentDirectory));
            Services.AddSingleton(new DashboardClient(http));
            Services.AddSingleton<Microsoft.JSInterop.IJSRuntime>(new Mock<Microsoft.JSInterop.IJSRuntime>().Object);

            // Act
            var cut = RenderComponent<ServerStatus>();

            // Assert
            cut.Markup.Should().Contain("Server & Agent Status");
        }
    }
}
