using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace ShouTech.App.Services.Online
{
    public enum SyncOperationType
    {
        UserProfile,
        UserPreferences,
        AuditLog,
        DeviceInfo
    }

    public sealed class SyncQueueItem
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public SyncOperationType Type { get; set; }
        public string PayloadPath { get; set; } = string.Empty;
        public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
        public int Attempts { get; set; }
    }

    public interface ISyncServ
    {
        int PendingCount { get; }
        IReadOnlyList<SyncQueueItem> PendingItems { get; }

        void EnqueueUserSnapshot();
        Task<int> ProcessQueueAsync();
        Task SnapshotLocalUserDataAsync();
    }

    public interface ISyncSvc : ISyncServ
    {
    }
}
