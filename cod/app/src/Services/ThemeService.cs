using ShouTech.App.Common;
using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Windows;
using ShouTech.App.Configuration;

namespace ShouTech.App.Services
{
    /// <summary>
    /// Enterprise theme manager — swaps merged resource dictionaries at runtime
    /// and persists preference via <see cref="UsrPref"/>.
    /// </summary>
    public class ThemeService : IThemeService
    {
        private const string DarkThemeUri = "pack://application:,,,/Themes/DarkTheme.xaml";
        private const string LightThemeUri = "pack://application:,,,/Themes/LightTheme.xaml";

        private bool _isDark;

        public event EventHandler<bool>? ThemeChanged;

        public bool GetCurrentTheme() => _isDark;

        public void Initialize(bool isDark)
        {
            ApplyThemeInternal(isDark, persist: false);
        }

        public void SetTheme(bool isDark)
        {
            ApplyThemeInternal(isDark, persist: true);
        }

        public void ToggleTheme() => SetTheme(!_isDark);

        private void ApplyThemeInternal(bool isDark, bool persist)
        {
            if (_isDark == isDark && persist)
            {
                var existing = FindThemeDictionary();
                if (existing != null)
                    return;
            }

            _isDark = isDark;
            SwapThemeDictionary(isDark);
            ApplyThemeToOpenWindows();

            if (persist)
                SavePreference(isDark);

            ThemeChanged?.Invoke(this, isDark);
            try { UiShellSync.OnThemeChanged(); } catch { }
        }

        private static void SwapThemeDictionary(bool isDark)
        {
            var app = System.Windows.Application.Current;
            if (app == null)
                return;

            var merged = app.Resources.MergedDictionaries;
            RemoveAllThemeDictionaries(merged);

            var uri = new Uri(isDark ? DarkThemeUri : LightThemeUri, UriKind.Absolute);
            merged.Add(new ResourceDictionary { Source = uri });
        }

        private static ResourceDictionary? FindThemeDictionary()
        {
            var app = System.Windows.Application.Current;
            if (app == null)
                return null;

            return app.Resources.MergedDictionaries
                .FirstOrDefault(d => d.Contains("ThemeName"));
        }

        private static void RemoveAllThemeDictionaries(Collection<ResourceDictionary> merged)
        {
            var themeDictionaries = merged
                .Where(d => d.Contains("ThemeName"))
                .ToList();

            foreach (var dictionary in themeDictionaries)
                merged.Remove(dictionary);
        }

        private static void SavePreference(bool isDark)
        {
            try
            {
                var pref = UsrPref.Load();
                pref.Theme = isDark ? "Dark" : "Light";
                pref.Save();
            }
            catch
            {
                // Non-fatal: theme still applied in memory
            }
        }

        private static void ApplyThemeToOpenWindows()
        {
            var app = System.Windows.Application.Current;
            if (app == null)
                return;

            foreach (Window window in app.Windows)
            {
                if (window == null)
                    continue;

                // All ShouTech windows share one visual surface; the theme dictionary
                // controls whether that surface is light or dark.
                window.SetResourceReference(Window.BackgroundProperty, "BackgroundBrush");
                window.SetResourceReference(Window.ForegroundProperty, "TextBrush");

                if (!window.IsLoaded)
                    ShlChrHlpr.Apply(window);
                else
                    window.SetResourceReference(Window.BackgroundProperty, "BackgroundBrush");
                window.InvalidateVisual();
                window.UpdateLayout();
            }
        }
    }
}
