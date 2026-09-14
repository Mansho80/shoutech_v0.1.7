using System;
using System.Threading.Tasks;

namespace ShouTech.App.Services.Online
{
    public enum LicenseStatus
    {
        Unknown,
        Valid,
        Expired,
        InvalidHardware,
        NotActivated,
        OfflineGrace
    }

    public sealed class LicenseInfo
    {
        public string LicenseKey { get; set; } = string.Empty;
        public string HardwareId { get; set; } = string.Empty;
        public DateTime ExpiryDate { get; set; } = DateTime.MaxValue;
        public DateTime? ActivatedAt { get; set; }
        public DateTime? LastOnlineCheck { get; set; }
        public LicenseStatus Status { get; set; } = LicenseStatus.Unknown;
        public bool IsOfflineMode { get; set; }
        public SupportGrant? SupportGrant { get; set; }
    }

    public sealed class SupportGrant
    {
        public string GrantId { get; set; } = string.Empty;
        public string DeviceId { get; set; } = string.Empty;
        public string HardwareId { get; set; } = string.Empty;
        public DateTime ExpiresAtUtc { get; set; }
        public string Scope { get; set; } = "diagnostics";
        public string Signature { get; set; } = string.Empty;
    }

    public interface ILicenSvc
    {
        LicenseInfo Current { get; }
        bool IsValid { get; }
        bool AllowsOfflineOperation { get; }
        bool HasSupportAccess { get; }

        LicenseStatus ValidateOffline();
        bool ValidateSupportAccess();
        Task<LicenseStatus> TryOnlineValidationAsync();
        Task<LicenseStatus> InitializeAsync();
    }
}
