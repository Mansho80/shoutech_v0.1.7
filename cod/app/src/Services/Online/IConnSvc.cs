using System;

namespace ShouTech.App.Services.Online
{
    public enum ConnectivityState
    {
        Unknown,
        Offline,
        Online,
        ServerReachable
    }

    public interface IConnSvc : IDisposable
    {
        ConnectivityState State { get; }
        bool IsNetworkAvailable { get; }
        bool IsServerReachable { get; }
        DateTime LastCheckedUtc { get; }

        event EventHandler<ConnectivityState>? StateChanged;

        void StartMonitoring();
        void StopMonitoring();
        ConnectivityState CheckNow();
    }
}
