using System;
using System.Reflection;
using System.Threading.Tasks;
using FluentAssertions;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using Moq;
using USBDeviceManager.Hubs;
using Xunit;

namespace USBDeviceManager.Tests.Unit
{
    [Trait("Category","Unit")]
    public class MonitoringHubTests
    {
        private static void SetProtectedProperty(object target, string propertyName, object value)
        {
            PropertyInfo? prop = target.GetType().GetProperty(propertyName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            if (prop == null)
            {
                // try base types
                prop = target.GetType().BaseType?.GetProperty(propertyName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            }

            if (prop == null)
            {
                throw new InvalidOperationException($"Property {propertyName} not found on {target.GetType()}");
            }

            MethodInfo? setter = prop.GetSetMethod(true);
            if (setter == null)
            {
                // try to set backing field if no setter exists
                FieldInfo? field = target.GetType().GetField($"<{propertyName}>k__BackingField", BindingFlags.Instance | BindingFlags.NonPublic);
                if (field == null)
                {
                    throw new InvalidOperationException($"No setter or backing field for {propertyName} on {target.GetType()}");
                }

                field.SetValue(target, value);
            }
            else
            {
                prop.SetValue(target, value);
            }
        }

        [Fact]
        public async Task JoinGroup_AddsToGroupAndLogs()
        {
            var mockLogger = new Mock<ILogger<MonitoringHub>>();
            var mockGroups = new Mock<IGroupManager>();
            var mockContext = new Mock<HubCallerContext>();

            mockContext.SetupGet(c => c.ConnectionId).Returns("conn-1");
            mockGroups.Setup(g => g.AddToGroupAsync("conn-1", "my-group", default)).Returns(Task.CompletedTask).Verifiable();

            var hub = new MonitoringHub(mockLogger.Object);

            // inject Context and Groups via reflection
            SetProtectedProperty(hub, "Context", mockContext.Object);
            SetProtectedProperty(hub, "Groups", mockGroups.Object);

            await hub.JoinGroup("my-group");

            mockGroups.Verify();

            mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("joined group")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception?, string>>()
                ), Times.Once);
        }

        [Fact]
        public async Task LeaveGroup_RemovesFromGroupAndLogs()
        {
            var mockLogger = new Mock<ILogger<MonitoringHub>>();
            var mockGroups = new Mock<IGroupManager>();
            var mockContext = new Mock<HubCallerContext>();

            mockContext.SetupGet(c => c.ConnectionId).Returns("conn-2");
            mockGroups.Setup(g => g.RemoveFromGroupAsync("conn-2", "my-group", default)).Returns(Task.CompletedTask).Verifiable();

            var hub = new MonitoringHub(mockLogger.Object);
            SetProtectedProperty(hub, "Context", mockContext.Object);
            SetProtectedProperty(hub, "Groups", mockGroups.Object);

            await hub.LeaveGroup("my-group");

            mockGroups.Verify();

            mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("left group")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception?, string>>()
                ), Times.Once);
        }

        [Fact]
        public async Task OnConnectedAndDisconnected_Logs()
        {
            var mockLogger = new Mock<ILogger<MonitoringHub>>();
            var mockContext = new Mock<HubCallerContext>();
            mockContext.SetupGet(c => c.ConnectionId).Returns("conn-3");

            var hub = new MonitoringHub(mockLogger.Object);
            SetProtectedProperty(hub, "Context", mockContext.Object);

            await hub.OnConnectedAsync();

            mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("Client connected")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception?, string>>()
                ), Times.Once);

            await hub.OnDisconnectedAsync(null);

            mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("Client disconnected")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception?, string>>()
                ), Times.Once);
        }
    }
}
