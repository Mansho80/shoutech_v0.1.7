using System;
using System.Threading.Tasks;

namespace ShouTech.App.Services.Online
{
    public sealed class SyncCycleResult
    {
        public bool Success { get; init; }
        public int ItemsSynced { get; init; }
        public int PendingRemaining { get; init; }
        public bool BackupUploaded { get; init; }
        public bool BackupCreated { get; init; }
        public DateTime CompletedUtc { get; init; } = DateTime.UtcNow;
    }

    public interface IOnlCoord : IDisposable
    {
        bool IsRunning { get; }
        bool IsSyncing { get; }
        DateTime? LastSuccessfulSyncUtc { get; }
        int PendingSyncCount { get; }

        event EventHandler<SyncCycleResult>? SyncCycleCompleted;
        event EventHandler<bool>? SyncingChanged;

        void Start();
        void StopCoordinator();
        Task RunOnlineCycleAsync();
        Task InitializeOfflineAsync();
    }
}
