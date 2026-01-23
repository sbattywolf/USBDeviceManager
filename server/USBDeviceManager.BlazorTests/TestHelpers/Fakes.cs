using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Components;
using USBDeviceManager.Services;

namespace USBDeviceManager.BlazorTests.TestHelpers
{
    internal class FakeHttpMessageHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var path = request.RequestUri?.AbsolutePath ?? string.Empty;
            // Return 404 for API endpoints so components gracefully handle missing backend during unit tests
            var resp = new HttpResponseMessage(HttpStatusCode.NotFound)
            {
                Content = new StringContent(string.Empty, Encoding.UTF8, "application/json")
            };
            return Task.FromResult(resp);
        }
    }

    internal class FakeDashboardClient : DashboardClient, IAsyncDisposable
    {
        public FakeDashboardClient(HttpClient http) : base(http)
        {
        }

        public new Task StartHubAsync() => Task.CompletedTask;
        public new ValueTask DisposeAsync() => ValueTask.CompletedTask;
    }

    internal class TestNavigationManager : NavigationManager
    {
        public TestNavigationManager()
        {
            Initialize("http://localhost/", "http://localhost/");
        }

        protected override void NavigateToCore(string uri, bool forceLoad)
        {
            // no-op for tests
            Uri = ToAbsoluteUri(uri).ToString();
        }
    }
}
