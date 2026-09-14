using System;
using System.Net.Http;
using System.Net.NetworkInformation;
using System.Threading;
using System.Threading.Tasks;
using ShouTech.App.Configuration;
using ShouTech.App.Services;

namespace ShouTech.App.Services.Online
{
    public sealed class ConnServ : IConnSvc
    {
        private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(5) };

        private readonly ILogServ _logging;
        private readonly Timer _timer;
        private ConnectivityState _state = ConnectivityState.Unknown;
        private volatile bool _checking;

        public ConnServ(ILogServ logging)
        {
            _logging = logging;
            var interval = Math.Max(15, AppCfgSvc.Current.OnlineServices?.ConnectivityCheckIntervalSeconds ?? 60);
            _timer = new Timer(_ => _ = CheckAsync(), null, Timeout.Infinite, Timeout.Infinite);
            TimerIntervalMs = interval * 1000;
        }

        private int TimerIntervalMs { get; }

        public ConnectivityState State => _state;
        public bool IsNetworkAvailable => _state is ConnectivityState.Online or ConnectivityState.ServerReachable;
        public bool IsServerReachable => _state == ConnectivityState.ServerReachable;
        public DateTime LastCheckedUtc { get; private set; }

        public event EventHandler<ConnectivityState>? StateChanged;

        public void StartMonitoring()
        {
            _ = CheckAsync();
            _timer.Change(TimerIntervalMs, TimerIntervalMs);
        }

        public void StopMonitoring()
        {
            _timer.Change(Timeout.Infinite, Timeout.Infinite);
        }

        public ConnectivityState CheckNow()
        {
            CheckAsync().GetAwaiter().GetResult();
            return _state;
        }

        private async Task CheckAsync()
        {
            if (_checking)
                return;

            _checking = true;
            try
            {
                var next = await ProbeAsync().ConfigureAwait(false);
                LastCheckedUtc = DateTime.UtcNow;

                if (next == _state)
                    return;

                _state = next;
                _logging.LogInfo("Connectivity", $"State changed to {_state}");
                StateChanged?.Invoke(this, _state);
            }
            catch (Exception ex)
            {
                _logging.LogInfo("Connectivity", $"Check failed: {ex.Message}");
            }
            finally
            {
                _checking = false;
            }
        }

        private static async Task<ConnectivityState> ProbeAsync()
        {
            if (!NetworkInterface.GetIsNetworkAvailable())
                return ConnectivityState.Offline;

            var activationUrl = AppCfgSvc.Current.Licensing?.Activation?.ActivationServer;
            var apiUrl = AppCfgSvc.Current.Integrations?.RestApi?.Endpoint;

            var target = !string.IsNullOrWhiteSpace(activationUrl) ? activationUrl : apiUrl;
            if (string.IsNullOrWhiteSpace(target))
                return ConnectivityState.Online;

            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Head, NormalizeUrl(target));
                using var response = await Http.SendAsync(request).ConfigureAwait(false);
                return response.IsSuccessStatusCode || (int)response.StatusCode < 500
                    ? ConnectivityState.ServerReachable
                    : ConnectivityState.Online;
            }
            catch (HttpRequestException)
            {
                return ConnectivityState.Online;
            }
            catch (TaskCanceledException)
            {
                return ConnectivityState.Online;
            }
        }

        private static string NormalizeUrl(string url)
        {
            if (Uri.TryCreate(url, UriKind.Absolute, out var uri))
                return uri.GetLeftPart(UriPartial.Authority);

            return url.TrimEnd('/');
        }

        public void Dispose() => _timer.Dispose();
    }
}
