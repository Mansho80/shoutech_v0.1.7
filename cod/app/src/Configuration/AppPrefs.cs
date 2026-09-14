using System;
using System.IO;
using System.Text.Json;
using ShouTech.App.Common;

namespace ShouTech.App.Configuration
{
    public class AppPrefs
    {
        public string? LastCompanyCode { get; set; }
        public string? RememberedUsername { get; set; }
        public bool HideUsernameOnNextLaunch { get; set; }
    }

    public static class AppPrefsSvc
    {
        private static readonly object _lock = new();

        public static string GetPreferencesPath()
        {
            var directory = Path.Combine(AppContext.BaseDirectory, "cfg");
            Directory.CreateDirectory(directory);
            return Path.Combine(directory, "userprefs.json");
        }

        public static AppPrefs Load()
        {
            lock (_lock)
            {
                var path = GetPreferencesPath();
                if (!File.Exists(path))
                    return new AppPrefs();

                try
                {
                    var json = File.ReadAllText(path);
                    return JsonSerializer.Deserialize<AppPrefs>(json) ?? new AppPrefs();
                }
                catch
                {
                    return new AppPrefs();
                }
            }
        }

        public static void Save(AppPrefs preferences)
        {
            lock (_lock)
            {
                var path = GetPreferencesPath();
                var json = JsonSerializer.Serialize(preferences, JsonDefs.Indented);
                File.WriteAllText(path, json);
            }
        }
    }
}
