using System;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Xunit;
using USBDeviceManager.TestUtilities.HealthCheck;

namespace USBDeviceManager.TestUtilities.HealthCheckTests
{
    [Trait("Category","Unit")]
    public class HealthPollerTests
    {
        [Fact]
        public async Task PollAsync_ReturnsTrue_WhenHealthAvailable()
        {
            var builder = new WebHostBuilder()
                .Configure(app =>
                {
                    app.Map("/health", h => h.Run(async ctx =>
                    {
                        ctx.Response.StatusCode = (int)HttpStatusCode.OK;
                        await ctx.Response.WriteAsync("OK");
                    }));
                });

            using var server = new TestServer(builder);
            using var client = server.CreateClient();

            var poller = new HealthPoller(client);
            var success = await poller.PollAsync("/health", TimeSpan.FromSeconds(5), TimeSpan.FromMilliseconds(100));

            Assert.True(success);
        }

        [Fact]
        public async Task PollAsync_ReturnsFalse_WhenUnreachable()
        {
            using var client = new HttpClient { BaseAddress = new Uri("http://localhost:52892") };
            var poller = new HealthPoller(client);
            var success = await poller.PollAsync("/no-such-path", TimeSpan.FromSeconds(1), TimeSpan.FromMilliseconds(100));
            Assert.False(success);
        }
    }
}
