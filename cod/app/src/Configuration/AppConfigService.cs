// ========================================================================
// FILE: cod/app/src/Configuration/AppConfigService.cs
// PROJECT: SHOUTECH ERP V10 - Configuration Loader
// ========================================================================

using System;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace ShouTech.App.Configuration
{
    /// <summary>
    /// خدمة تحميل الإعدادات المركزية من ملف cfg/appset.json
    /// </summary>
    public static class AppConfigService
    {
        public static AppSetng Current => AppCfgSvc.Current;
        public static string? LoadedPath => AppCfgSvc.LoadedPath;
        public static bool IsLoaded => AppCfgSvc.IsLoaded;

        public static void Load(string? explicitPath = null) => AppCfgSvc.Load(explicitPath);
        public static void Reload() => AppCfgSvc.Reload();
        public static void Save(string? explicitPath = null) => AppCfgSvc.Save(explicitPath);
    }
}
