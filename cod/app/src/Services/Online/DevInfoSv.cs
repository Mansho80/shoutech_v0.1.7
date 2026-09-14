using System;
using System.IO;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using ShouTech.App.Common;
using ShouTech.App.Configuration;
using ShouTech.App.Services;

namespace ShouTech.App.Services.Online
{
    public sealed class DevInfoSv : IDevInfoSv, IDevInfoSvoSv
    {
        private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(15) };

        private readonly ILogServ _logging;
        private readonly string _cachePath;
        private DeviceInfoSnapshot? _cached;

        public DevInfoSv(ILogServ logging)
        {
            _logging = logging;
            _cachePath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ShouTech", "ERP", "cfg", "device.json");
        }

        public DeviceInfoSnapshot Current => _cached ??= LoadOrCollect();

        public DeviceInfoSnapshot Collect()
        {
            var settings = AppCfgSvc.Current.Application;
            var machine = Environment.MachineName;
            var os = Environment.OSVersion.VersionString;
            var user = Environment.UserName;
            var hwid = ComputeHardwareId(machine, os);

            var snapshot = new DeviceInfoSnapshot
            {
                DeviceId = LoadOrCreateDeviceId(hwid),
                HardwareId = hwid,
                MachineName = machine,
                OsVersion = os,
                UserName = user,
                AppVersion = settings?.Version ?? "10.6.0",
                InstanceId = settings?.InstanceId ?? "ST-ERP-001",
                ProcessorCount = Environment.ProcessorCount,
                WorkingSetMb = Environment.WorkingSet / (1024 * 1024),
                Culture = System.Globalization.CultureInfo.CurrentUICulture.Name
            };

            SaveCache(snapshot);
            _cached = snapshot;
            return snapshot;
        }

        public async Task RegisterWithServerAsync()
        {
            var endpoint = AppCfgSvc.Current.OnlineServices?.DeviceRegisterEndpoint;
            var baseUrl = AppCfgSvc.Current.Licensing?.Activation?.ActivationServer;
            if (string.IsNullOrWhiteSpace(endpoint) || string.IsNullOrWhiteSpace(baseUrl))
                return;

            var url = CombineUrl(baseUrl, endpoint);
            var payload = JsonSerializer.Serialize(Current, JsonDefs.Indented);
            using var content = new StringContent(payload, Encoding.UTF8, "application/json");

            try
            {
                using var response = await Http.PostAsync(url, content).ConfigureAwait(false);
                if (response.IsSuccessStatusCode)
                    _logging.LogInfo("DeviceInfo", "Device registered with server");
                else
                    _logging.LogInfo("DeviceInfo", $"Device registration returned {(int)response.StatusCode}");
            }
            catch (Exception ex)
            {
                _logging.LogInfo("DeviceInfo", $"Device registration skipped: {ex.Message}");
            }
        }

        private DeviceInfoSnapshot LoadOrCollect()
        {
            try
            {
                if (File.Exists(_cachePath))
                {
                    var json = File.ReadAllText(_cachePath);
                    var loaded = JsonSerializer.Deserialize<DeviceInfoSnapshot>(json, JsonDefs.AppSetngRead);
                    if (loaded != null && !string.IsNullOrWhiteSpace(loaded.DeviceId))
                        return loaded;
                }
            }
            catch (Exception ex)
            {
                _logging.LogWarning("DeviceInfo", $"Cache read failed: {ex.Message}");
            }

            return Collect();
        }

        private void SaveCache(DeviceInfoSnapshot snapshot)
        {
            try
            {
                var dir = Path.GetDirectoryName(_cachePath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    Directory.CreateDirectory(dir);

                File.WriteAllText(_cachePath, JsonSerializer.Serialize(snapshot, JsonDefs.Indented));
            }
            catch (Exception ex)
            {
                _logging.LogWarning("DeviceInfo", $"Cache write failed: {ex.Message}");
            }
        }

        private static string LoadOrCreateDeviceId(string hardwareId)
        {
            var idPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ShouTech", "ERP", "cfg", "device.id");

            try
            {
                if (File.Exists(idPath))
                {
                    var existing = File.ReadAllText(idPath).Trim();
                    if (!string.IsNullOrWhiteSpace(existing))
                        return existing;
                }

                var deviceId = $"ST-{hardwareId[..Math.Min(12, hardwareId.Length)].ToUpperInvariant()}";
                var dir = Path.GetDirectoryName(idPath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    Directory.CreateDirectory(dir);

                File.WriteAllText(idPath, deviceId);
                return deviceId;
            }
            catch
            {
                return $"ST-{Guid.NewGuid():N}"[..16].ToUpperInvariant();
            }
        }

        private static string ComputeHardwareId(string machine, string os)
        {
            var raw = $"{machine}|{os}|{Environment.UserDomainName}";
            var hash = SHA256.HashData(Encoding.UTF8.GetBytes(raw));
            return Convert.ToHexString(hash);
        }

        private static string CombineUrl(string baseUrl, string path)
        {
            baseUrl = baseUrl.TrimEnd('/');
            path = path.TrimStart('/');
            return $"{baseUrl}/{path}";
        }
    }
}
