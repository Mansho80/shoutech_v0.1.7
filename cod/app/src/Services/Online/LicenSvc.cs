using System;
using System.Globalization;
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
    public sealed class LicenSvc : ILicenSvc
    {
        private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(15) };

        private readonly ILogServ _logging;
        private readonly IDevInfoSv _deviceInfo;
        private readonly string _licensePath;

        public LicenSvc(ILogServ logging, IDevInfoSv deviceInfo)
        {
            _logging = logging;
            _deviceInfo = deviceInfo;
            _licensePath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ShouTech", "ERP", "cfg", "license.local.json");
        }

        public LicenseInfo Current { get; private set; } = new();
        public bool IsValid => Current.Status is LicenseStatus.Valid or LicenseStatus.OfflineGrace;
        public bool AllowsOfflineOperation => AppCfgSvc.Current.Licensing?.Activation?.OfflineActivationAllowed ?? true;
        public bool HasSupportAccess => ValidateSupportAccess();

        public async Task<LicenseStatus> InitializeAsync()
        {
            Current = LoadLocal() ?? CreateFromConfig();
            Current.Status = ValidateOffline();
            SaveLocal(Current);
            await Task.CompletedTask.ConfigureAwait(false);
            return Current.Status;
        }

        public LicenseStatus ValidateOffline()
        {
            var device = _deviceInfo.Current;
            var activation = AppCfgSvc.Current.Licensing?.Activation;

            if (string.IsNullOrWhiteSpace(Current.LicenseKey))
            {
                Current.Status = AllowsOfflineOperation ? LicenseStatus.OfflineGrace : LicenseStatus.NotActivated;
                Current.IsOfflineMode = true;
                return Current.Status;
            }

            if (activation?.HardwareIdBased == true
                && !string.IsNullOrWhiteSpace(Current.HardwareId)
                && !string.Equals(Current.HardwareId, device.HardwareId, StringComparison.OrdinalIgnoreCase))
            {
                Current.Status = LicenseStatus.InvalidHardware;
                Current.IsOfflineMode = true;
                return Current.Status;
            }

            if (Current.ExpiryDate.Date < DateTime.Now.Date)
            {
                Current.Status = LicenseStatus.Expired;
                Current.IsOfflineMode = true;
                return Current.Status;
            }

            Current.Status = AllowsOfflineOperation ? LicenseStatus.OfflineGrace : LicenseStatus.Valid;
            Current.IsOfflineMode = true;
            return Current.Status;
        }

        public bool ValidateSupportAccess()
        {
            var grant = Current.SupportGrant;
            var device = _deviceInfo.Current;
            if (grant == null
                || string.IsNullOrWhiteSpace(grant.GrantId)
                || !string.Equals(grant.DeviceId, device.DeviceId, StringComparison.OrdinalIgnoreCase)
                || !string.Equals(grant.HardwareId, device.HardwareId, StringComparison.OrdinalIgnoreCase)
                || grant.ExpiresAtUtc <= DateTime.UtcNow)
            {
                return false;
            }

            var publicKey = Environment.GetEnvironmentVariable("SHOUTECH_SUPPORT_PUBLIC_KEY");
            if (string.IsNullOrWhiteSpace(publicKey) || string.IsNullOrWhiteSpace(grant.Signature))
                return false;

            var signedContent = string.Join("|", grant.GrantId, grant.DeviceId, grant.HardwareId,
                grant.ExpiresAtUtc.ToUniversalTime().ToString("O", CultureInfo.InvariantCulture), grant.Scope);

            try
            {
                using var rsa = RSA.Create();
                rsa.ImportFromPem(publicKey);
                return rsa.VerifyData(
                    Encoding.UTF8.GetBytes(signedContent),
                    Convert.FromBase64String(grant.Signature),
                    HashAlgorithmName.SHA256,
                    RSASignaturePadding.Pkcs1);
            }
            catch (Exception ex)
            {
                _logging.LogWarning("Support", $"Support grant validation failed: {ex.Message}");
                return false;
            }
        }

        public async Task<LicenseStatus> TryOnlineValidationAsync()
        {
            var baseUrl = AppCfgSvc.Current.Licensing?.Activation?.ActivationServer;
            var endpoint = AppCfgSvc.Current.OnlineServices?.LicenseValidateEndpoint ?? "/license/validate";
            if (string.IsNullOrWhiteSpace(baseUrl))
            {
                ValidateOffline();
                return Current.Status;
            }

            var url = $"{baseUrl.TrimEnd('/')}/{endpoint.TrimStart('/')}";
            var payload = JsonSerializer.Serialize(new
            {
                licenseKey = Current.LicenseKey,
                hardwareId = _deviceInfo.Current.HardwareId,
                deviceId = _deviceInfo.Current.DeviceId,
                appVersion = _deviceInfo.Current.AppVersion
            }, JsonDefs.Indented);

            try
            {
                using var content = new StringContent(payload, Encoding.UTF8, "application/json");
                using var response = await Http.PostAsync(url, content).ConfigureAwait(false);
                Current.LastOnlineCheck = DateTime.UtcNow;

                if (response.IsSuccessStatusCode)
                {
                    var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                    ApplyServerResponse(body);
                    Current.Status = LicenseStatus.Valid;
                    Current.IsOfflineMode = false;
                    SaveLocal(Current);
                    _logging.LogInfo("License", "Online validation succeeded");
                    return Current.Status;
                }

                _logging.LogInfo("License", $"Online validation returned {(int)response.StatusCode}");
            }
            catch (Exception ex)
            {
                _logging.LogInfo("License", $"Online validation skipped: {ex.Message}");
            }

            return ValidateOffline();
        }

        private void ApplyServerResponse(string json)
        {
            try
            {
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                if (root.TryGetProperty("expiryDate", out var expiry)
                    && DateTime.TryParse(expiry.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var dt))
                {
                    Current.ExpiryDate = dt;
                }

                if (root.TryGetProperty("licenseKey", out var key))
                    Current.LicenseKey = key.GetString() ?? Current.LicenseKey;

                if (root.TryGetProperty("supportGrant", out var grant)
                    && grant.ValueKind == JsonValueKind.Object)
                {
                    Current.SupportGrant = grant.Deserialize<SupportGrant>(JsonDefs.AppSetngRead);
                }
            }
            catch
            {
                // Keep local license if response is not parseable
            }
        }

        private LicenseInfo? LoadLocal()
        {
            try
            {
                if (!File.Exists(_licensePath))
                    return null;

                var json = File.ReadAllText(_licensePath);
                return JsonSerializer.Deserialize<LicenseInfo>(json, JsonDefs.AppSetngRead);
            }
            catch (Exception ex)
            {
                _logging.LogWarning("License", $"Local license load failed: {ex.Message}");
                return null;
            }
        }

        private LicenseInfo CreateFromConfig()
        {
            var licensing = AppCfgSvc.Current.Licensing;
            DateTime expiry = DateTime.MaxValue;
            if (!string.IsNullOrWhiteSpace(licensing?.ExpiryDate)
                && DateTime.TryParse(licensing.ExpiryDate, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var parsed))
            {
                expiry = parsed;
            }

            return new LicenseInfo
            {
                LicenseKey = licensing?.DongleInfo?.SerialNumber ?? "LOCAL-DEV",
                HardwareId = _deviceInfo.Current.HardwareId,
                ExpiryDate = expiry,
                ActivatedAt = DateTime.UtcNow,
                Status = LicenseStatus.Unknown,
                IsOfflineMode = true
            };
        }

        private void SaveLocal(LicenseInfo info)
        {
            try
            {
                var dir = Path.GetDirectoryName(_licensePath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    Directory.CreateDirectory(dir);

                File.WriteAllText(_licensePath, JsonSerializer.Serialize(info, JsonDefs.Indented));
            }
            catch (Exception ex)
            {
                _logging.LogWarning("License", $"Local license save failed: {ex.Message}");
            }
        }
    }
}
