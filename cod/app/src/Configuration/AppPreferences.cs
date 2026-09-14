using System;
using System.IO;
using System.Text.Json;

namespace ShouTech.App.Configuration
{
    public class AppPreferences
    {
        public string? LastCompanyCode { get; set; }
        public string? RememberedUsername { get; set; }
    }

    public static class AppPreferencesService
    {
        private static readonly object _lock = new();
        private static readonly JsonSerializerOptions _writeOptions = new()
        {
            WriteIndented = true
        };

        public static string GetPreferencesPath()
        {
            var directory = Path.Combine(AppContext.BaseDirectory, "cfg");
            Directory.CreateDirectory(directory);
            return Path.Combine(directory, "userprefs.json");
        }

        public static AppPreferences Load()
        {
            lock (_lock)
            {
                var path = GetPreferencesPath();
                if (!File.Exists(path))
                    return new AppPreferences();

                try
                {
                    var json = File.ReadAllText(path);
                    return JsonSerializer.Deserialize<AppPreferences>(json) ?? new AppPreferences();
                }
                catch
                {
                    return new AppPreferences();
                }
            }
        }

        public static void Save(AppPreferences preferences)
        {
            lock (_lock)
            {
                var path = GetPreferencesPath();
                var json = JsonSerializer.Serialize(preferences, _writeOptions);
                File.WriteAllText(path, json);
            }
        }
    }
}
