using System;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace USBDeviceManager.TestUtilities.HealthCheck
{
    /// <summary>
    /// Lightweight helper to use from xUnit fixtures.
    /// Construct with an HttpClient (e.g. from WebApplicationFactory) and call <see cref="WaitForHealthAsync"/>.
    /// </summary>
    public class HealthTestFixture
    {
        public HealthPoller Poller { get; }

        public HealthTestFixture(HttpClient client)
        {
            Poller = new HealthPoller(client ?? throw new ArgumentNullException(nameof(client)));
        }

        public Task<bool> WaitForHealthAsync(string path, TimeSpan timeout, TimeSpan pollInterval, CancellationToken cancellationToken = default)
            => Poller.PollAsync(path, timeout, pollInterval, cancellationToken);
    }
}
