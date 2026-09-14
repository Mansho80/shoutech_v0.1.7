// ========================================================================
// FILE: cod/app/src/Configuration/AppCfgSvc.cs
// PROJECT: SHOUTECH ERP V10 - Configuration Loader
// ========================================================================

using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using ShouTech.App.Common;
using ShouTech.Domain.Interfaces;

namespace ShouTech.App.Configuration
{
    /// <summary>
    /// خدمة تحميل الإعدادات المركزية من ملف cfg/appset.json
    /// </summary>
    public static class AppCfgSvc
    {
        private static AppSetng? _settings;
        private static readonly object _lock = new();
        private static string? _loadedPath;

        /// <summary>
        /// الإعدادات الحالية (تُحمّل تلقائياً عند أول طلب)
        /// </summary>
        public static AppSetng Current
        {
            get
            {
                if (_settings == null)
                    Load();
                return _settings!;
            }
        }

        /// <summary>
        /// المسار الذي تم تحميل الملف منه
        /// </summary>
        public static string? LoadedPath => _loadedPath;

        /// <summary>
        /// هل تم تحميل الإعدادات بنجاح؟
        /// </summary>
        public static bool IsLoaded => _settings != null;

        /// <summary>
        /// تحميل ملف الإعدادات
        /// </summary>
        public static void Load(string? explicitPath = null)
        {
            lock (_lock)
            {
                string? path = explicitPath;

                if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
                {
                    // مسارات بحث مرتبة حسب الأولوية
                    var candidates = new[]
                    {
                        // بجانب الـ EXE (الأكثر شيوعاً بعد النشر)
                        Path.Combine(AppContext.BaseDirectory, "cfg", "appset.json"),
                        Path.Combine(AppContext.BaseDirectory, "appset.json"),

                        // مجلد العمل الحالي
                        Path.Combine(Directory.GetCurrentDirectory(), "cfg", "appset.json"),
                        Path.Combine(Directory.GetCurrentDirectory(), "appset.json"),

                        // أثناء التطوير (من bin/Debug/... صعوداً)
                        Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "cfg", "appset.json")),
                        Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "cfg", "appset.json")),
                        Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "cfg", "appset.json")),

                        // مسارات مطلقة شائعة (للتطوير المحلي)
                        @"D:\SyrianHouse\Tool\shoutech_erp_v9\cfg\appset.json",
                        @"D:\Tools\Down2\shoutech_erp_v9\cfg\appset.json"
                    };

                    path = candidates.FirstOrDefault(File.Exists);
                }

                if (path == null || !File.Exists(path))
                {
                    // إنشاء إعدادات افتراضية بدلاً من رمي استثناء قاتل
                    _settings = CreateDefaultSettings();
                    _loadedPath = null;
                    return;
                }

                try
                {
                    var json = File.ReadAllText(path);
                    _settings = JsonSerializer.Deserialize<AppSetng>(json, JsonDefs.AppSetngRead)
                                ?? CreateDefaultSettings();
                    ApplyEnvironmentOverrides(_settings);
                    ApplyDevelopmentDefaults(_settings);
                    NormalizeDatabaseSettings(_settings);
                    _loadedPath = path;
                }
                catch (Exception)
                {
                    // في حال فشل التحليل نستخدم القيم الافتراضية
                    _settings = CreateDefaultSettings();
                    NormalizeDatabaseSettings(_settings);
                    _loadedPath = null;
                }
            }
        }

        public static void Save(string? explicitPath = null)
        {
            lock (_lock)
            {
                _settings ??= CreateDefaultSettings();
                NormalizeDatabaseSettings(_settings);
                var path = ResolveWritableSettingsPath(explicitPath);
                var directory = Path.GetDirectoryName(path);
                if (!string.IsNullOrWhiteSpace(directory))
                    Directory.CreateDirectory(directory);
                File.WriteAllText(path, JsonSerializer.Serialize(_settings, JsonDefs.Indented));
                _loadedPath = path;
            }
        }

        private static void ApplyEnvironmentOverrides(AppSetng settings)
        {
            var connection = Environment.GetEnvironmentVariable("SHOUTECH_DB_CONNECTION")
                ?? Environment.GetEnvironmentVariable("SHOUTECH_CONNECTION_STRING");
            var provider = Environment.GetEnvironmentVariable("SHOUTECH_DB_PROVIDER");
            if (!string.IsNullOrWhiteSpace(connection))
            {
                if (!settings.ConnectionStrings.TryGetValue("Default", out var defaultConnection))
                {
                    defaultConnection = new ConnectionStringSettings();
                    settings.ConnectionStrings["Default"] = defaultConnection;
                }

                defaultConnection.ConnectionString = connection;
            }

            if (!string.IsNullOrWhiteSpace(provider) &&
                settings.ConnectionStrings.TryGetValue("Default", out var selectedConnection))
            {
                settings.Database ??= new DatabaseSettings();

                var normalized = CoerceSupportedProvider(
                    provider.Trim(),
                    settings.Database.DefaultProvider);

                selectedConnection.Provider = normalized;
                settings.Database.DefaultProvider = normalized;
            }
        }

        private static void ApplyDevelopmentDefaults(AppSetng settings)
        {
            if (!string.Equals(settings.Application.EnvironmentType, "Development", StringComparison.OrdinalIgnoreCase))
                return;

            settings.Application.RequireDongle = false;
            settings.Application.RequireLicense = false;
            settings.Security.RequireDongle = false;
            settings.Security.RequireLicense = false;
            if (settings.Licensing?.Activation != null)
            {
                settings.Licensing.Activation.RequireOnlineActivation = false;
                settings.Licensing.Activation.ActivationServer = string.Empty;
            }
        }

        /// <summary>
        /// إعادة تحميل الإعدادات من الملف
        /// </summary>
        public static void Reload()
        {
            lock (_lock)
            {
                _settings = null;
                _loadedPath = null;
            }
            Load();
        }

        private static AppSetng CreateDefaultSettings()
        {
            return new AppSetng
            {
                ConnectionStrings = new System.Collections.Generic.Dictionary<string, ConnectionStringSettings>(StringComparer.OrdinalIgnoreCase)
                {
                    ["Default"] = new ConnectionStringSettings { Provider = DatabaseProviderNames.Sqlite }
                },
                Database = new DatabaseSettings
                {
                    DefaultProvider = DatabaseProviderNames.Sqlite,
                    SupportedProviders = CreateSupportedProviderCatalog()
                },
                Application = new ApplicationSettings
                {
                    Name = "شو تيك لإدارة المؤسسات",
                    NameEn = "ShouTech Enterprise Management System",
                    ShortName = "شو تيك ERP",
                    ShortNameEn = "ShouTech ERP",
                    BrandTagline = "Unified Business Intelligence for Regional Growth",
                    BrandTaglineAr = "ذكاء أعمال موحد لنمو المؤسسات الإقليمية",
                    VisionStatement = "Empower regional enterprises with secure, intelligent, and scalable ERP.",
                    VisionStatementAr = "نقوّم المؤسسات الإقليمية بذكاء وأمان وقابلية توسع عالية.",
                    TargetMarket = "Middle East & North Africa",
                    PrimaryAudience = "SMB + Corporate + Multi-company groups",
                    EnterpriseStyle = "Enterprise / Arabic-first / Offline-first",
                    Version = "10.6.0",
                    Build = "20260801",
                    Copyright = "© 2026 ShouTech. All rights reserved.",
                    Environment = "Development",
                    RequireDongle = true,
                    RequireLicense = true,
                    CheckFileIntegrity = true,
                    MinSplashSeconds = 4.5
                },
                Branding = new BrandingSettings
                {
                    Theme = new ThemeSettings
                    {
                        Mode = "Dark",
                        PrimaryColor = "#0078D4",
                        PrimaryDark = "#005A9E",
                        PrimaryLight = "#2B88D8",
                        SecondaryColor = "#00B7C3",
                        SecondaryDark = "#008A94",
                        SecondaryLight = "#33C8D2",
                        AccentColor = "#FF6B35",
                        Background = "#1E1E1E",
                        Surface = "#2D2D2D",
                        SurfaceLight = "#3D3D3D",
                        SurfaceDark = "#1A1A1A",
                        Text = "#FFFFFF",
                        TextSecondary = "#AAAAAA",
                        TextDisabled = "#666666",
                        Success = "#107C10",
                        Warning = "#FFB900",
                        Error = "#D13438",
                        Info = "#0078D4"
                    },
                    SplashScreen = new SplashScreenSettings
                    {
                        ShowSplash = true,
                        MinDisplaySeconds = 4.5,
                        ShowVersion = true,
                        ShowProgress = true,
                        BackgroundColor = "#1A1A1A",
                        TextColor = "#FFFFFF"
                    }
                },
                Languages = new LanguagesSettings
                {
                    Default = "ar",
                    Fallback = "en"
                },
                Currency = new CurrencySettings
                {
                    DefaultCode = "SYP",
                    DefaultSymbol = "ل.س"
                },
                Security = new SecuritySettings
                {
                    RequireDongle = true,
                    RequireLicense = true,
                    SessionTimeoutMinutes = 30,
                    MaxLoginAttempts = 5
                },
                Company = new CompanySettings
                {
                    BrandSlogan = "Building trust through enterprise automation",
                    BrandSloganAr = "نبني الثقة عبر أتمتة مؤسسية متقدمة",
                    MarketRegion = "Middle East",
                    OperationCenter = "Damascus - Syria",
                    CommercialName = "شو تيك",
                    CommercialNameEn = "ShouTech",
                    Address = "دمشق - سوريا",
                    AddressEn = "Damascus - Syria",
                    DefaultCurrencyCode = "SYP",
                    DefaultLanguage = "en",
                    TimeZone = "Asia/Damascus"
                },
                MultiCompany = new MultiCompanySettings
                {
                    Enabled = true,
                    DefaultCompanyCode = "001",
                    Companies = new System.Collections.Generic.List<CompanyInfo>
                    {
                        new CompanyInfo
                        {
                            Code = "001",
                            Name = "الشركة الرئيسية",
                            NameEn = "Main Company",
                            Database = "SHOUTECH_MST",
                            IsDefault = true,
                            Enabled = true
                        }
                    }
                }
            };
        }

        private static void NormalizeDatabaseSettings(AppSetng settings)
        {
            settings.ConnectionStrings ??= new System.Collections.Generic.Dictionary<string, ConnectionStringSettings>(StringComparer.OrdinalIgnoreCase);
            if (!settings.ConnectionStrings.TryGetValue("Default", out var defaultConnection) || defaultConnection == null)
            {
                defaultConnection = new ConnectionStringSettings();
                settings.ConnectionStrings["Default"] = defaultConnection;
            }

            settings.Database ??= new DatabaseSettings();
            settings.Database.SupportedProviders = CreateSupportedProviderCatalog();

            settings.Database.DefaultProvider = CoerceSupportedProvider(
                settings.Database.DefaultProvider,
                DatabaseProviderNames.Sqlite);

            foreach (var key in settings.ConnectionStrings.Keys.ToList())
            {
                var connection = settings.ConnectionStrings[key] ?? new ConnectionStringSettings();
                connection.Provider = CoerceSupportedProvider(connection.Provider, settings.Database.DefaultProvider);
                settings.ConnectionStrings[key] = connection;
            }
        }

        private static string CoerceSupportedProvider(string? provider, string? fallbackProvider)
        {
            var normalized = DatabaseProviderNames.Normalize(provider);
            if (DatabaseProviderNames.IsSupported(normalized))
                return normalized;

            if (DatabaseProviderNames.IsLegacy(normalized))
                return DatabaseProviderNames.PostgreSql;

            var fallback = DatabaseProviderNames.Normalize(fallbackProvider);
            return DatabaseProviderNames.IsSupported(fallback)
                ? fallback
                : DatabaseProviderNames.Sqlite;
        }

        private static System.Collections.Generic.List<ProviderInfo> CreateSupportedProviderCatalog() =>
            new()
            {
                new ProviderInfo { Name = DatabaseProviderNames.Sqlite, Assembly = "Microsoft.Data.Sqlite", ProviderFactory = "Microsoft.Data.Sqlite.SqliteFactory" },
                new ProviderInfo { Name = DatabaseProviderNames.PostgreSql, Assembly = "Npgsql", ProviderFactory = "Npgsql.NpgsqlFactory" }
            };

        private static string ResolveWritableSettingsPath(string? explicitPath)
        {
            if (!string.IsNullOrWhiteSpace(explicitPath))
                return Path.GetFullPath(explicitPath);
            if (!string.IsNullOrWhiteSpace(_loadedPath))
                return _loadedPath;
            return Path.Combine(Directory.GetCurrentDirectory(), "cfg", "appset.json");
        }
    }
}
