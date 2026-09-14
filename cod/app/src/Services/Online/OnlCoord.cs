using System;
using System.Threading;
using System.Threading.Tasks;
using ShouTech.App.Configuration;
using ShouTech.App.Services;

namespace ShouTech.App.Services.Online
{
    /// <summary>
    /// Mandatory hourly backup/sync when online. Startup backup when internet is available.
    /// </summary>
    public sealed class OnlCoord : IOnlCoord
    {
        private readonly IConnSvc _connectivity;
        private readonly ILicenSvc _license;
        private readonly IBkpServ _backup;
        private readonly ISyncServ _sync;
        private readonly IDevInfoSv _deviceInfo;
        private readonly ILogServ _logging;
        private readonly SemaphoreSlim _gate = new(1, 1);
        private readonly Timer _backgroundSyncTimer;
        private bool _running;
        private bool _isSyncing;
        private bool _startupBackupPending = true;

        public OnlCoord(
            IConnSvc connectivity,
            ILicenSvc license,
            IBkpServ backup,
            ISyncServ sync,
            IDevInfoSv deviceInfo,
            ILogServ logging)
        {
            _connectivity = connectivity;
            _license = license;
            _backup = backup;
            _sync = sync;
            _deviceInfo = deviceInfo;
            _logging = logging;
            _connectivity.StateChanged += OnConnectivityChanged;

            var settings = AppCfgSvc.Current.OnlineServices;
            var intervalSeconds = Math.Max(300, settings?.BackgroundSyncIntervalSeconds ?? 3600);
            _backgroundSyncTimer = new Timer(_ => _ = RunOnlineCycleAsync(), null, Timeout.Infinite, Timeout.Infinite);
            BackgroundSyncIntervalMs = intervalSeconds * 1000;
        }

        private int BackgroundSyncIntervalMs { get; }

        public bool IsRunning => _running;
        public bool IsSyncing => _isSyncing;
        public DateTime? LastSuccessfulSyncUtc { get; private set; }
        public int PendingSyncCount => _sync.PendingCount;

        public event EventHandler<SyncCycleResult>? SyncCycleCompleted;
        public event EventHandler<bool>? SyncingChanged;

        public async Task InitializeOfflineAsync()
        {
            _deviceInfo.Collect();
            await _license.InitializeAsync().ConfigureAwait(false);
            await _sync.SnapshotLocalUserDataAsync().ConfigureAwait(false);
            _logging.LogInfo("OnlineCoordinator", $"Offline init — license: {_license.Current.Status}");
        }

        public void Start()
        {
            if (_running)
                return;

            _running = true;
            _connectivity.StartMonitoring();
            _backgroundSyncTimer.Change(BackgroundSyncIntervalMs, BackgroundSyncIntervalMs);
            _logging.LogInfo("OnlineCoordinator", $"Background backup/sync started (every {BackgroundSyncIntervalMs / 1000}s)");

            _ = RunOnlineCycleAsync(forceStartupBackup: true);
        }

        public void StopCoordinator()
        {
            if (!_running)
                return;

            _running = false;
            _backgroundSyncTimer.Change(Timeout.Infinite, Timeout.Infinite);
            _connectivity.StopMonitoring();
        }

        public Task RunOnlineCycleAsync() => RunOnlineCycleAsync(forceStartupBackup: false);

        private async Task RunOnlineCycleAsync(bool forceStartupBackup)
        {
            if (!_running)
                return;

            if (!await _gate.WaitAsync(0).ConfigureAwait(false))
                return;

            SetSyncing(true);
            SyncCycleResult result = new() { Success = false, PendingRemaining = _sync.PendingCount };

            try
            {
                if (!_connectivity.IsNetworkAvailable)
                    return;

                _logging.LogInfo("OnlineCoordinator", "Online cycle started");

                var settings = AppCfgSvc.Current.OnlineServices;
                var forceBackup = forceStartupBackup
                                  || (_startupBackupPending && settings?.BackupOnStartup != false)
                                  || _backup.IsBackupDue();

                if (forceStartupBackup || _startupBackupPending)
                    _startupBackupPending = false;

                BackupResult? backupResult = null;
                if (forceBackup && _connectivity.IsServerReachable)
                {
                    backupResult = await _backup.RunOnlineBackupCycleAsync(force: true).ConfigureAwait(false);
                    _logging.LogInfo("OnlineCoordinator",
                        backupResult.Success
                            ? $"Startup/hourly backup: {backupResult.LocalPath}"
                            : "Backup cycle failed");
                }
                else if (forceBackup)
                {
                    backupResult = _backup.PerformRotatedBackup();
                    await _sync.SnapshotLocalUserDataAsync().ConfigureAwait(false);
                }

                if (_connectivity.IsServerReachable)
                {
                    await _license.TryOnlineValidationAsync().ConfigureAwait(false);
                    await _deviceInfo.RegisterWithServerAsync().ConfigureAwait(false);
                }

                await _sync.SnapshotLocalUserDataAsync().ConfigureAwait(false);
                var synced = _connectivity.IsServerReachable
                    ? await _sync.ProcessQueueAsync().ConfigureAwait(false)
                    : 0;

                var uploaded = backupResult?.Uploaded == true;
                if (!uploaded && _connectivity.IsServerReachable && _backup.IsBackupDue())
                    uploaded = await _backup.TryUploadRotatedBackupsAsync().ConfigureAwait(false);

                LastSuccessfulSyncUtc = DateTime.UtcNow;
                result = new SyncCycleResult
                {
                    Success = backupResult?.Success != false,
                    ItemsSynced = synced,
                    PendingRemaining = _sync.PendingCount,
                    BackupUploaded = uploaded,
                    BackupCreated = backupResult?.Success == true
                };
            }
            catch (Exception ex)
            {
                _logging.LogError("OnlineCoordinator", "Online cycle failed", ex);
                result = new SyncCycleResult { Success = false, PendingRemaining = _sync.PendingCount };
            }
            finally
            {
                SetSyncing(false);
                _gate.Release();
                SyncCycleCompleted?.Invoke(this, result);
            }
        }

        private void SetSyncing(bool value)
        {
            if (_isSyncing == value)
                return;

            _isSyncing = value;
            SyncingChanged?.Invoke(this, value);
        }

        private void OnConnectivityChanged(object? sender, ConnectivityState state)
        {
            if (!_running)
                return;

            if (state is ConnectivityState.Online or ConnectivityState.ServerReachable)
                _ = RunOnlineCycleAsync();
        }

        public void Dispose()
        {
            StopCoordinator();
            _connectivity.StateChanged -= OnConnectivityChanged;
            _connectivity.Dispose();
            _backgroundSyncTimer.Dispose();
            _gate.Dispose();
        }
    }
}
