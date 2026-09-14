using System;
using System.Windows;
using System.Windows.Media;
using ShouTech.App.Localization;
using ShouTech.App.Services;

namespace ShouTech.App.Common
{
    /// <summary>
    /// Ensures every window follows the main shell: language, flow direction,
    /// localization keys, theme inheritance, and shared company/user identity.
    /// Call from WinMgr and any Show/ShowDialog path.
    /// </summary>
    public static class UiShellSync
    {
        private static bool _hooksAttached;

        /// <summary>Subscribe once at application startup.</summary>
        public static void EnsureApplicationHooks()
        {
            if (_hooksAttached)
                return;

            var app = System.Windows.Application.Current;
            if (app == null)
                return;

            app.Activated -= OnAppActivated;
            app.Activated += OnAppActivated;
            _hooksAttached = true;
        }

        private static void OnAppActivated(object? sender, EventArgs e)
        {
            // Lightweight: re-apply language direction if culture changed while minimized.
            try { ApplyAllOpenWindows(); } catch { }
        }

        public static void Apply(Window? window)
        {
            if (window == null)
                return;

            try
            {
                var lang = App.CurrentLanguageCode ?? LangDirSv.DefaultLanguageCode;

                // 1) RTL/LTR + XmlLanguage
                LangDirSv.ApplyToWindow(window, lang);

                // 2) LocProps / bound localization keys on this window tree
                try { UiLoczr.ApplyToWindow(window); } catch { }

                // 3) Theme: Application.Resources already hold theme dictionaries.
                //    Force Background to theme brush when present so child windows match shell.
                try
                {
                    if (System.Windows.Application.Current?.TryFindResource("BackgroundBrush") is Brush bg)
                        window.Background = bg;
                    else if (System.Windows.Application.Current?.TryFindResource("ShellBackgroundBrush") is Brush shellBg)
                        window.Background = shellBg;

                    if (System.Windows.Application.Current?.TryFindResource("TextBrush") is Brush fg)
                        window.Foreground = fg;
                }
                catch { }

                // 4) Typography consistency with main window when available
                try
                {
                    var main = System.Windows.Application.Current?.MainWindow;
                    if (main != null && !ReferenceEquals(main, window))
                    {
                        if (main.FontFamily != null)
                            window.FontFamily = main.FontFamily;
                    }
                }
                catch { }

                // 5) Optional title suffix: company — user (does not rewrite specialized titles)
                try { AppendContextToTitleIfNeeded(window); } catch { }

                // Re-apply after load so late-bound controls receive LocProps
                if (!window.IsLoaded)
                {
                    void OnLoaded(object? s, RoutedEventArgs e)
                    {
                        window.Loaded -= OnLoaded;
                        try
                        {
                            LangDirSv.ApplyToWindow(window, App.CurrentLanguageCode);
                            UiLoczr.ApplyToWindow(window);
                        }
                        catch { }
                    }
                    window.Loaded += OnLoaded;
                }
            }
            catch
            {
                // Never block window open due to chrome sync.
            }
        }

        public static void ApplyAllOpenWindows()
        {
            var app = System.Windows.Application.Current;
            if (app == null)
                return;

            foreach (Window window in app.Windows)
            {
                try { Apply(window); }
                catch { }
            }
        }

        /// <summary>
        /// Shared caption fragment: "Company — User (Role)".
        /// </summary>
        public static string BuildIdentityCaption()
        {
            var company = AppState.CurrentCompanyDisplayName;
            var user = UsrSession.Current?.FullName;
            if (string.IsNullOrWhiteSpace(user))
                user = UsrSession.Current?.Username;
            var role = UsrSession.Current?.Role;

            if (string.IsNullOrWhiteSpace(company) && string.IsNullOrWhiteSpace(user))
                return string.Empty;

            if (string.IsNullOrWhiteSpace(user))
                return company;

            if (string.IsNullOrWhiteSpace(company))
            {
                return string.IsNullOrWhiteSpace(role)
                    ? user!
                    : $"{user} ({role})";
            }

            return string.IsNullOrWhiteSpace(role)
                ? $"{company} — {user}"
                : $"{company} — {user} ({role})";
        }

        private static void AppendContextToTitleIfNeeded(Window window)
        {
            // Only windows that opt-in via Tag == "ShellContextTitle"
            if (window.Tag is not string tag ||
                !tag.Equals("ShellContextTitle", StringComparison.OrdinalIgnoreCase))
                return;

            var identity = BuildIdentityCaption();
            if (string.IsNullOrWhiteSpace(identity))
                return;

            var baseTitle = window.Title ?? string.Empty;
            var marker = " | ";
            var idx = baseTitle.IndexOf(marker, StringComparison.Ordinal);
            if (idx >= 0)
                baseTitle = baseTitle[..idx].TrimEnd();

            window.Title = string.IsNullOrWhiteSpace(baseTitle)
                ? identity
                : $"{baseTitle}{marker}{identity}";
        }

        /// <summary>Call after language change from App.SetLanguage.</summary>
        public static void OnLanguageChanged(string languageCode)
        {
            try
            {
                LangDirSv.ApplyCulture(languageCode);
                LangDirSv.ApplyToAllWindows(languageCode);
                UiLoczr.ScheduleApplyToAllWindows();
                ApplyAllOpenWindows();
            }
            catch { }
        }

        /// <summary>Call after theme toggle.</summary>
        public static void OnThemeChanged()
        {
            try { ApplyAllOpenWindows(); }
            catch { }
        }
    }
}
