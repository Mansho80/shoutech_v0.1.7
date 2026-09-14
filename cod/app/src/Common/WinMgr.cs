using System;
using System.Windows;

namespace ShouTech.App.Common
{
    /// <summary>Opens top-level windows in standard Windows SDI style (peer windows, taskbar, activate on focus).</summary>
    public static class WinMgr
    {
        private static int _cascadeOffset;

        public static void ShowIndependent(Window window, Window? shellHost = null)
        {
            ArgumentNullException.ThrowIfNull(window);

            // Enterprise: every secondary window follows shell language, theme, identity.
            UiShellSync.EnsureApplicationHooks();
            UiShellSync.Apply(window);

            // Operational windows belong to the ShouTech shell. They never get
            // their own Windows Taskbar button; only MWin is a taskbar app.
            if (shellHost != null && shellHost.IsLoaded)
                window.Owner = shellHost;
            else
                window.Owner = null;

            window.ShowInTaskbar = false;
            window.ShowActivated = true;

            if (shellHost != null && shellHost.IsLoaded)
            {
                var preferCenter = window.Resources["PreferCenterScreen"] is bool center && center;
                if (preferCenter)
                    window.WindowStartupLocation = WindowStartupLocation.CenterScreen;
                else
                    PositionNearShell(window, shellHost);

                ShellWinDock.Attach(window, shellHost);
            }
            else if (shellHost != null)
            {
                ShellWinDock.Attach(window, shellHost);
            }
            else
            {
                window.WindowStartupLocation = WindowStartupLocation.CenterScreen;
            }

            window.Show();
            window.Activate();

            // Second pass after show (resources fully available)
            UiShellSync.Apply(window);
        }

        /// <summary>Modal dialog that still inherits shell language/theme/identity.</summary>
        public static bool? ShowDialogSynced(Window window, Window? owner = null)
        {
            ArgumentNullException.ThrowIfNull(window);

            UiShellSync.EnsureApplicationHooks();
            UiShellSync.Apply(window);

            if (owner != null && owner.IsVisible)
            {
                window.Owner = owner;
                window.WindowStartupLocation = WindowStartupLocation.CenterOwner;
            }
            else if (System.Windows.Application.Current?.MainWindow is { IsVisible: true } main)
            {
                window.Owner = main;
                window.WindowStartupLocation = WindowStartupLocation.CenterOwner;
            }

            var result = window.ShowDialog();
            return result;
        }

        private static void PositionNearShell(Window window, Window shellHost)
        {
            window.WindowStartupLocation = WindowStartupLocation.Manual;

            var slot = _cascadeOffset++ % 8;
            var offset = 24 * slot;
            var desiredLeft = shellHost.Left + shellHost.Width - window.Width - 32 - offset;
            var desiredTop = shellHost.Top + 72 + offset;

            if (desiredLeft < shellHost.Left + 24)
                desiredLeft = shellHost.Left + 24 + offset;

            if (desiredTop + window.Height > shellHost.Top + shellHost.Height - 48)
                desiredTop = shellHost.Top + shellHost.Height - window.Height - 48;

            window.Left = Math.Max(0, desiredLeft);
            window.Top = Math.Max(0, desiredTop);
        }

        public static void BringToFront(Window window)
        {
            ArgumentNullException.ThrowIfNull(window);

            if (window.WindowState == WindowState.Minimized)
                window.WindowState = WindowState.Normal;

            UiShellSync.Apply(window);
            window.Show();
            window.Activate();
            window.Focus();
        }
    }
}
