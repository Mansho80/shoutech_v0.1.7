using System;
using System.Windows;
using ShouTech.App.ViewModels;

namespace ShouTech.App.Common
{
    /// <summary>Minimize shell child windows to the main window status bar; restore on demand.</summary>
    public static class ShellWinDock
    {
        public static void Attach(Window child, Window shellHost)
        {
            ArgumentNullException.ThrowIfNull(child);
            ArgumentNullException.ThrowIfNull(shellHost);

            // Keep the child owned by the main shell. It is an in-app window,
            // not a separate Windows Taskbar application.
            child.Owner = shellHost;
            child.ShowInTaskbar = false;
            child.StateChanged += (_, _) => OnStateChanged(child, shellHost);
            child.Closed += (_, _) => Detach(child, shellHost);
        }

        private static void OnStateChanged(Window child, Window shellHost)
        {
            if (child.WindowState != WindowState.Minimized)
                return;

            if (shellHost.DataContext is not MainShVM viewModel)
                return;

            Dock(child, viewModel);
        }

        public static void Dock(Window window, MainShVM viewModel)
        {
            var title = string.IsNullOrWhiteSpace(window.Title) ? "نافذة" : window.Title;

            window.WindowState = WindowState.Normal;
            window.ShowInTaskbar = false;
            window.Hide();

            viewModel.DockWindow(title, window);
        }

        public static void Restore(DockedWinItem item, MainShVM viewModel)
        {
            if (item.Window == null)
                return;

            item.Window.ShowInTaskbar = false;
            item.Window.Owner = viewModel.OwnerWindow;
            item.Window.Show();
            item.Window.WindowState = WindowState.Normal;
            item.Window.Activate();
            viewModel.UndockWindow(item);
        }

        private static void Detach(Window child, Window shellHost)
        {
            if (shellHost.DataContext is not MainShVM viewModel)
                return;

            viewModel.RemoveDockedWindow(child);
        }
    }
}
