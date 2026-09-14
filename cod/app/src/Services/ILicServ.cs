// shoutech_erp_v0.1.6/cod/app/src/Services/ILicServ.cs
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    public enum LicEd : byte
    {
        Demo = 0,
        Viewer = 1,
        Core = 10
    }

    public enum LicStat : byte
    {
        Valid = 0,
        GracePeriod = 1,
        Expired = 2,
        Revoked = 3,
        HardwareMismatch = 4,
        InvalidSignature = 5,
        DeviceLimitExceeded = 6,
        NotFound = 7
    }

    public static class ModKey
    {
        public const string Acc = "ACC";
        public const string Inv = "INV";
        public const string Sales = "SALES";
        public const string Purch = "PURCH";
        public const string Hr = "HR";
        public const string Mfg = "MFG";
        public const string Pos = "POS";
        public const string Ai = "AI";
        public const string AdvRpt = "ADV_RPT";
        public const string MultiCur = "MULTI_CUR";
        public const string WhiteLabel = "WL";
    }

    public sealed class LicResult
    {
        public LicStat Status { get; init; }
        public LicEd Edition { get; init; }
        public DateTime? ExpiresAt { get; init; }
        public DateTime? GraceEndsAt { get; init; }
        public int? MaxDevices { get; init; }
        public int? ActiveDevices { get; init; }
        public string? Message { get; init; }
        public IReadOnlySet<string> Modules { get; init; } = new HashSet<string>();

        public bool IsUsable => Status is LicStat.Valid or LicStat.GracePeriod;
        public bool IsViewer => Edition == LicEd.Viewer;
        public bool IsDemo => Edition == LicEd.Demo;
        public bool CanWrite => IsUsable && Edition != LicEd.Viewer;
    }

    public interface ILicServ
    {
        Task<LicResult> ValidateAsync(CancellationToken ct = default);
        Task<LicResult> RefreshAsync(CancellationToken ct = default);

        LicEd CurrentEdition { get; }
        bool CanWrite { get; }
        bool IsModuleEnabled(string moduleKey);

        Task EnsureUsableAsync(CancellationToken ct = default);
        Task EnsureCanWriteAsync(CancellationToken ct = default);
        Task EnsureModuleAsync(string moduleKey, CancellationToken ct = default);
    }
}