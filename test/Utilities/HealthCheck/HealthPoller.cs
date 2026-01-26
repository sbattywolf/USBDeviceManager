using System;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace USBDeviceManager.TestUtilities.HealthCheck
{
    public class HealthPoller
    {
        private readonly HttpClient _client;

        public HealthPoller(HttpClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        /// <summary>
        /// Polls the specified path until a 200 is returned or timeout elapses.
        /// Path may be a relative path if the HttpClient has a BaseAddress.
        /// </summary>
        public async Task<bool> PollAsync(string path, TimeSpan timeout, TimeSpan interval, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrEmpty(path)) throw new ArgumentNullException(nameof(path));

            var deadline = DateTime.UtcNow + timeout;
            while (DateTime.UtcNow <= deadline)
            {
                cancellationToken.ThrowIfCancellationRequested();
                try
                {
                    using var resp = await _client.GetAsync(path, cancellationToken).ConfigureAwait(false);
                    if (resp.IsSuccessStatusCode) return true;
                }
                catch (HttpRequestException)
                {
                    // ignore and retry
                }
                catch (TaskCanceledException)
                {
                    // treat as timeout or cancellation
                }

                await Task.Delay(interval, cancellationToken).ConfigureAwait(false);
            }

            return false;
        }
    }
}
