using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using ShouTech.App.Common;
using ShouTech.App.Configuration;
using ShouTech.App.Services;

namespace ShouTech.App.Services.Online
{
    public sealed class SyncServ : ISyncServ, ISyncSvc
    {
        private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };

        private readonly ILogServ _logging;
        private readonly IDevInfoSv _deviceInfo;
        private readonly string _queuePath;
        private readonly string _snapshotDir;
        private List<SyncQueueItem> _queue = new();

        public SyncServ(ILogServ logging, IDevInfoSv deviceInfo)
        {
            _logging = logging;
            _deviceInfo = deviceInfo;

            var root = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ShouTech", "ERP", "sync");

            _queuePath = Path.Combine(root, "queue.json");
            _snapshotDir = Path.Combine(root, "snapshots");
            LoadQueue();
        }

        public int PendingCount => _queue.Count;
        public IReadOnlyList<SyncQueueItem> PendingItems => _queue;

        public async Task SnapshotLocalUserDataAsync()
        {
            if (!Directory.Exists(_snapshotDir))
                Directory.CreateDirectory(_snapshotDir);

            var stamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss", System.Globalization.CultureInfo.InvariantCulture);
            var snapshotPath = Path.Combine(_snapshotDir, $"users_{stamp}.json");

            var userDataRoot = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ShouTech", "ERP");

            var snapshot = new
            {
                capturedAt = DateTime.UtcNow,
                device = _deviceInfo.Current,
                files = CollectExistingUserFiles(userDataRoot)
            };

            await File.WriteAllTextAsync(snapshotPath, JsonSerializer.Serialize(snapshot, JsonDefs.Indented))
                .ConfigureAwait(false);

            _queue.Add(new SyncQueueItem
            {
                Type = SyncOperationType.UserProfile,
                PayloadPath = snapshotPath
            });

            SaveQueue();
            _logging.LogInfo("Sync", $"User snapshot queued: {snapshotPath}");
        }

        public void EnqueueUserSnapshot()
        {
            _ = SnapshotLocalUserDataAsync();
        }

        public async Task<int> ProcessQueueAsync()
        {
            if (_queue.Count == 0)
                return 0;

            var baseUrl = ResolveSyncBaseUrl();
            if (string.IsNullOrWhiteSpace(baseUrl))
                return 0;

            var endpoint = AppCfgSvc.Current.OnlineServices?.SyncEndpoint ?? "/sync";
            var url = $"{baseUrl.TrimEnd('/')}/{endpoint.TrimStart('/')}";
            var processed = 0;

            foreach (var item in _queue.ToList())
            {
                try
                {
                    if (!File.Exists(item.PayloadPath))
                    {
                        _queue.Remove(item);
                        continue;
                    }

                    var payload = await File.ReadAllTextAsync(item.PayloadPath).ConfigureAwait(false);
                    using var content = new StringContent(payload, Encoding.UTF8, "application/json");
                    using var response = await Http.PostAsync(url, content).ConfigureAwait(false);

                    item.Attempts++;
                    if (response.IsSuccessStatusCode)
                    {
                        _queue.Remove(item);
                        processed++;
                        _logging.LogInfo("Sync", $"Uploaded sync item {item.Id}");
                    }
                    else
                    {
                        _logging.LogWarning("Sync", $"Sync item {item.Id} failed with {(int)response.StatusCode}");
                    }
                }
                catch (Exception ex)
                {
                    item.Attempts++;
                    _logging.LogWarning("Sync", $"Sync item {item.Id} error: {ex.Message}");
                }
            }

            SaveQueue();
            return processed;
        }

        private static string? ResolveSyncBaseUrl()
        {
            var activation = AppCfgSvc.Current.Licensing?.Activation?.ActivationServer;
            if (!string.IsNullOrWhiteSpace(activation))
                return activation;

            return AppCfgSvc.Current.Integrations?.RestApi?.Endpoint;
        }

        private static Dictionary<string, string> CollectExistingUserFiles(string root)
        {
            var result = new Dictionary<string, string>();
            var candidates = new[]
            {
                Path.Combine(root, "cfg", "user.dat"),
                Path.Combine(root, "userprefs.json"),
                Path.Combine(root, "cfg", "license.local.json"),
                Path.Combine(root, "cfg", "device.json")
            };

            foreach (var file in candidates.Where(File.Exists))
            {
                try
                {
                    result[Path.GetFileName(file)] = File.ReadAllText(file);
                }
                catch
                {
                    // Skip unreadable files
                }
            }

            return result;
        }

        private void LoadQueue()
        {
            try
            {
                if (!File.Exists(_queuePath))
                    return;

                var json = File.ReadAllText(_queuePath);
                _queue = JsonSerializer.Deserialize<List<SyncQueueItem>>(json, JsonDefs.AppSetngRead) ?? new();
            }
            catch (Exception ex)
            {
                _logging.LogWarning("Sync", $"Queue load failed: {ex.Message}");
                _queue = new();
            }
        }

        private void SaveQueue()
        {
            try
            {
                var dir = Path.GetDirectoryName(_queuePath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    Directory.CreateDirectory(dir);

                File.WriteAllText(_queuePath, JsonSerializer.Serialize(_queue, JsonDefs.Indented));
            }
            catch (Exception ex)
            {
                _logging.LogWarning("Sync", $"Queue save failed: {ex.Message}");
            }
        }
    }
}
