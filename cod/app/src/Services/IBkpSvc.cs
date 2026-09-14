// shoutech_erp_v0.1.6/cod/app/src/Services/IBkpSvc.cs
using System.Threading;
using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    public class BackupResult
    {
        public bool Success { get; set; }
        public string? LocalPath { get; set; }
        public bool Uploaded { get; set; }
        public string? Message { get; set; }
    }

    public interface IBkpServ
    {
        Task<string> CreateBackupAsync(string companyCode, CancellationToken ct = default);
        Task RestoreBackupAsync(string backupFilePath, CancellationToken ct = default);
        Task<bool> ValidateBackupAsync(string backupFilePath, CancellationToken ct = default);
        void PerformBackup();
        BackupResult PerformRotatedBackup();
        bool IsBackupDue();
        Task<BackupResult> RunOnlineBackupCycleAsync(bool force = false, CancellationToken ct = default);
        Task<bool> TryUploadRotatedBackupsAsync(CancellationToken ct = default);
    }
}