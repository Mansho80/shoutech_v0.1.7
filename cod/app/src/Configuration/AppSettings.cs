
// ========================================================================
// FILE: Configuration/AppSettings.cs
// PROJECT: SHOUTECH ERP
// FRAMEWORK: .NET 8.0 / C# 12 / WPF
// PURPOSE: Central application configuration
// ========================================================================

#nullable enable

using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows;

namespace ShouTech.App.Configuration;

/// <summary>
/// الإعدادات المركزية للتطبيق.
/// Central, strongly-typed application settings.
///
/// ملاحظة مهمة:
/// هذا الكلاس مسؤول عن إعدادات التطبيق العامة،
/// بينما UsrPref مسؤول عن تفضيلات المستخدم الشخصية.
/// </summary>
public sealed class AppSettings
{
    // --------------------------------------------------------------------
    // Singleton
    // --------------------------------------------------------------------

    private static readonly Lazy<AppSettings> _current =
        new(
            static () => Load(),
            System.Threading.LazyThreadSafetyMode.ExecutionAndPublication);

    private readonly string _applicationDataPath =
        Path.Combine(
            Environment.GetFolderPath(
                Environment.SpecialFolder.LocalApplicationData),
            "ShouTech",
            "ERP");

    /// <summary>
    /// النسخة الحالية من إعدادات التطبيق.
    /// </summary>
    public static AppSettings Current => _current.Value;

    // --------------------------------------------------------------------
    // Configuration paths
    // --------------------------------------------------------------------

    /// <summary>
    /// اسم التطبيق.
    /// </summary>
    public string ApplicationName { get; set; } = "ShouTech ERP";

    /// <summary>
    /// الإصدار.
    /// </summary>
    public string Version { get; set; } = "10.0.0";

    /// <summary>
    /// الشركة / الناشر.
    /// </summary>
    public string Publisher { get; set; } = "ShouTech";

    /// <summary>
    /// بيئة التشغيل.
    /// Development / Testing / Production
    /// </summary>
    public string EnvironmentName { get; set; } = "Production";

    /// <summary>
    /// هل التطبيق يعمل بوضع التطوير؟
    /// </summary>
    [JsonIgnore]
    public bool IsDevelopment =>
        string.Equals(
            EnvironmentName,
            "Development",
            StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// هل التطبيق يعمل بوضع الإنتاج؟
    /// </summary>
    [JsonIgnore]
    public bool IsProduction =>
        string.Equals(
            EnvironmentName,
            "Production",
            StringComparison.OrdinalIgnoreCase);

    // --------------------------------------------------------------------
    // Localization
    // --------------------------------------------------------------------

    /// <summary>
    /// اللغة الافتراضية.
    /// </summary>
    public string DefaultLanguage { get; set; } = "ar";

    /// <summary>
    /// اتجاه الواجهة.
    /// </summary>
    public FlowDirection Direction { get; set; } = FlowDirection.RightToLeft;

    // --------------------------------------------------------------------
    // Theme
    // --------------------------------------------------------------------

    /// <summary>
    /// الثيم الافتراضي.
    /// </summary>
    public string DefaultTheme { get; set; } = "Light";

    // --------------------------------------------------------------------
    // Window defaults
    // --------------------------------------------------------------------

    public double WindowWidth { get; set; } = 1400;

    public double WindowHeight { get; set; } = 850;

    public double WindowLeft { get; set; }

    public double WindowTop { get; set; }

    public bool WindowMaximized { get; set; }

    // --------------------------------------------------------------------
    // Database
    // --------------------------------------------------------------------

    /// <summary>
    /// اسم قاعدة البيانات المحلية الافتراضية.
    /// </summary>
    public string DatabaseName { get; set; } = "ShouTech_ERP.db";

    /// <summary>
    /// هل نستخدم قاعدة بيانات محلية؟
    /// </summary>
    public bool UseLocalDatabase { get; set; } = true;

    /// <summary>
    /// هل نستخدم SQLite؟
    /// </summary>
    public bool UseSqlite { get; set; } = true;

    // --------------------------------------------------------------------
    // Security
    // --------------------------------------------------------------------

    /// <summary>
    /// تفعيل سجل التدقيق.
    /// </summary>
    public bool EnableAuditLog { get; set; } = true;

    /// <summary>
    /// تفعيل التحقق الأمني.
    /// </summary>
    public bool EnableSecurityChecks { get; set; } = true;

    /// <summary>
    /// تفعيل حماية العبث بالملفات.
    /// </summary>
    public bool EnableTamperProtection { get; set; } = true;

    // --------------------------------------------------------------------
    // Licensing
    // --------------------------------------------------------------------

    /// <summary>
    /// تفعيل نظام الترخيص.
    /// </summary>
    public bool EnableLicense { get; set; } = true;

    /// <summary>
    /// تفعيل دعم Dongle.
    /// </summary>
    public bool EnableDongle { get; set; }

    /// <summary>
    /// السماح بالعمل Offline.
    /// </summary>
    public bool AllowOfflineMode { get; set; } = true;

    // --------------------------------------------------------------------
    // Startup
    // --------------------------------------------------------------------

    /// <summary>
    /// إظهار شاشة البداية.
    /// </summary>
    public bool ShowSplashScreen { get; set; } = true;

    /// <summary>
    /// الحد الأقصى لوقت شاشة البداية بالثواني.
    /// </summary>
    public int SplashTimeoutSeconds { get; set; } = 5;

    /// <summary>
    /// فحص قاعدة البيانات عند التشغيل.
    /// </summary>
    public bool CheckDatabaseOnStartup { get; set; } = true;

    /// <summary>
    /// فحص الترخيص عند التشغيل.
    /// </summary>
    public bool CheckLicenseOnStartup { get; set; } = true;

    // --------------------------------------------------------------------
    // Performance
    // --------------------------------------------------------------------

    /// <summary>
    /// تفعيل التخزين المؤقت.
    /// </summary>
    public bool EnableCaching { get; set; } = true;

    /// <summary>
    /// الحد الأقصى للعمليات المتزامنة.
    /// </summary>
    public int MaxConcurrentOperations { get; set; } = 8;

    // --------------------------------------------------------------------
    // File system
    // --------------------------------------------------------------------

    [JsonIgnore]
    public string ApplicationDataPath => _applicationDataPath;

    [JsonIgnore]
    public string ConfigurationDirectory =>
        Path.Combine(ApplicationDataPath, "Configuration");

    [JsonIgnore]
    public string SettingsFilePath =>
        Path.Combine(ConfigurationDirectory, "appsettings.json");

    [JsonIgnore]
    public string DatabaseDirectory =>
        Path.Combine(ApplicationDataPath, "Database");

    [JsonIgnore]
    public string LogsDirectory =>
        Path.Combine(ApplicationDataPath, "Logs");

    // --------------------------------------------------------------------
    // JSON
    // --------------------------------------------------------------------

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        AllowTrailingCommas = true,
        ReadCommentHandling = JsonCommentHandling.Skip
    };

    // --------------------------------------------------------------------
    // Load
    // --------------------------------------------------------------------

    /// <summary>
    /// تحميل الإعدادات من appsettings.json.
    /// في حال عدم وجود الملف يتم إنشاء إعدادات افتراضية آمنة.
    /// </summary>
    public static AppSettings Load()
    {
        try
        {
            var settings = new AppSettings();

            Directory.CreateDirectory(settings.ConfigurationDirectory);
            Directory.CreateDirectory(settings.DatabaseDirectory);
            Directory.CreateDirectory(settings.LogsDirectory);

            if (!File.Exists(settings.SettingsFilePath))
            {
                settings.Normalize();
                settings.Save();
                return settings;
            }

            var json = File.ReadAllText(settings.SettingsFilePath);

            if (string.IsNullOrWhiteSpace(json))
            {
                settings.Normalize();
                return settings;
            }

            var loaded =
                JsonSerializer.Deserialize<AppSettings>(
                    json,
                    JsonOptions);

            if (loaded is null)
            {
                settings.Normalize();
                return settings;
            }

            loaded.Normalize();
            return loaded;
        }
        catch
        {
            // لا نفشل إقلاع البرنامج بسبب ملف إعدادات تالف.
            var fallback = new AppSettings();
            fallback.Normalize();
            return fallback;
        }
    }

    // --------------------------------------------------------------------
    // Save
    // --------------------------------------------------------------------

    /// <summary>
    /// حفظ الإعدادات بشكل ذري قدر الإمكان.
    /// </summary>
    public void Save()
    {
        Normalize();

        Directory.CreateDirectory(ConfigurationDirectory);
        Directory.CreateDirectory(DatabaseDirectory);
        Directory.CreateDirectory(LogsDirectory);

        var json =
            JsonSerializer.Serialize(
                this,
                JsonOptions);

        var tempFile = SettingsFilePath + ".tmp";

        File.WriteAllText(tempFile, json);

        if (File.Exists(SettingsFilePath))
        {
            File.Replace(
                tempFile,
                SettingsFilePath,
                null);
        }
        else
        {
            File.Move(
                tempFile,
                SettingsFilePath);
        }
    }

    // --------------------------------------------------------------------
    // Normalize
    // --------------------------------------------------------------------

    /// <summary>
    /// تصحيح القيم غير الصالحة ومنع إعدادات غير منطقية.
    /// </summary>
    public void Normalize()
    {
        ApplicationName =
            string.IsNullOrWhiteSpace(ApplicationName)
                ? "ShouTech ERP"
                : ApplicationName.Trim();

        Version =
            string.IsNullOrWhiteSpace(Version)
                ? "10.0.0"
                : Version.Trim();

        Publisher =
            string.IsNullOrWhiteSpace(Publisher)
                ? "ShouTech"
                : Publisher.Trim();

        EnvironmentName =
            NormalizeEnvironment(EnvironmentName);

        DefaultLanguage =
            NormalizeLanguage(DefaultLanguage);

        DefaultTheme =
            NormalizeTheme(DefaultTheme);

        DatabaseName =
            string.IsNullOrWhiteSpace(DatabaseName)
                ? "ShouTech_ERP.db"
                : Path.GetFileName(DatabaseName.Trim());

        if (WindowWidth < 800)
            WindowWidth = 800;

        if (WindowHeight < 600)
            WindowHeight = 600;

        if (WindowWidth > 10000)
            WindowWidth = 10000;

        if (WindowHeight > 10000)
            WindowHeight = 10000;

        if (SplashTimeoutSeconds < 1)
            SplashTimeoutSeconds = 1;

        if (SplashTimeoutSeconds > 60)
            SplashTimeoutSeconds = 60;

        if (MaxConcurrentOperations < 1)
            MaxConcurrentOperations = 1;

        if (MaxConcurrentOperations > 128)
            MaxConcurrentOperations = 128;

        // العربية هي الاتجاه الافتراضي في ShouTech ERP.
        Direction =
            string.Equals(
                DefaultLanguage,
                "ar",
                StringComparison.OrdinalIgnoreCase)
                ? FlowDirection.RightToLeft
                : FlowDirection.LeftToRight;
    }

    // --------------------------------------------------------------------
    // Helpers
    // --------------------------------------------------------------------

    private static string NormalizeEnvironment(string? value)
    {
        if (string.Equals(
                value,
                "Development",
                StringComparison.OrdinalIgnoreCase))
            return "Development";

        if (string.Equals(
                value,
                "Testing",
                StringComparison.OrdinalIgnoreCase))
            return "Testing";

        return "Production";
    }

    private static string NormalizeLanguage(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return "ar";

        var language = value.Trim().ToLowerInvariant();

        return language switch
        {
            "ar" or "ar-sa" or "ar-kw" or "ar-jo" => "ar",
            "en" or "en-us" or "en-gb" => "en",
            _ => "ar"
        };
    }

    private static string NormalizeTheme(string? value)
    {
        return string.Equals(
            value,
            "Dark",
            StringComparison.OrdinalIgnoreCase)
            ? "Dark"
            : "Light";
    }
}
