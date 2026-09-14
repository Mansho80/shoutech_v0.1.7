using System.Windows;
using ShouTech.App.Configuration;
using ShouTech.App.Services.Online;
using ShouTech.Application.Services;
using ShouTech.Domain.Interfaces;
using ShouTech.Infrastructure;

namespace ShouTech.App.Services
{
    /// <summary>
    /// Composition root for application-wide services (lightweight service locator).
    /// </summary>
    public static class AppHost
    {
        private static bool _initialized;

        public static ILogServ Logging { get; private set; } = new LogServ();
        public static IThmServ Theme { get; private set; } = new ThmServ();
        public static INavServ Navigation { get; private set; } = null!;
        public static IAuthSvc Auth { get; private set; } = new AuthServ();
        public static IDataServ Data { get; private set; } = new DataServ();
        public static ICoCreateSvc CompanyCreation { get; private set; } = new CoCreateSvc();
        public static IPermServ Permissions { get; private set; } = new PermServ();
        public static IInvServ Inventory { get; private set; } = null!;
        public static IBkpServ Backup { get; private set; } = null!;
        public static IConnSvc Connectivity { get; private set; } = null!;
        public static IDevInfoSv DeviceInfo { get; private set; } = null!;
        public static ILicenSvc License { get; private set; } = null!;
        public static ISyncSvc Sync { get; private set; } = null!;
        public static IOnlCoord OnlineCoordinator { get; private set; } = null!;

        // ✅ الخدمات الجديدة
        public static ISessionManager Session { get; private set; } = new SessionManager();
        public static IAuditService Audit { get; private set; } = null!;
        public static JournalService? Journal { get; private set; }
        public static IDatabaseHealth? DatabaseHealth { get; private set; }

        public static ILocSvc Localization =>
            System.Windows.Application.Current is App app ? app.Localization : _fallbackLocalization;

        private static readonly LocSvc _fallbackLocalization = new();

        /// <summary>
        /// Rebind provider-dependent services after an in-session company/database switch.
        /// The shell is recreated by the caller so newly constructed view models consume the new context.
        /// </summary>
        public static void RebindDatabaseContext()
        {
            if (!_initialized)
                return;

            var provider = ResolveDatabaseProvider();
            DatabaseProviderNames.EnsureCoreImplementation(provider);
            var connection = ResolveDatabaseConnection();

            if (DatabaseRuntime.IsSqlite(provider) && !string.IsNullOrWhiteSpace(connection))
                SqliteSchemaBootstrapper.EnsureDatabase(connection);

            Journal = CreateJournalService(provider);
            DatabaseHealth = CreateDatabaseHealth(provider);

            if (!string.IsNullOrWhiteSpace(connection))
            {
                Inventory = new InvServ(
                    new LicServ(),
                    Permissions,
                    InventoryRepositoryFactory.Create(provider, connection));
            }

            Backup = new BkpServ(Logging, DeviceInfo, Sync);
            OnlineCoordinator = new OnlCoord(
                Connectivity, License, Backup, Sync, DeviceInfo, Logging);

            Logging.LogInfo("AppHost", $"Database context rebound: {provider}");
        }

        public static void Initialize()
        {
            if (_initialized)
                return;

            AppCfgSvc.Load();
            var provider = ResolveDatabaseProvider();
            DatabaseProviderNames.EnsureCoreImplementation(provider);
            var databaseConnection = ResolveDatabaseConnection();
            if (DatabaseRuntime.IsSqlite(provider) && !string.IsNullOrWhiteSpace(databaseConnection))
                SqliteSchemaBootstrapper.EnsureDatabase(databaseConnection);

            Logging = new LogServ();
            Theme = new ThmServ();
            Navigation = new NavServ(Logging);
            Auth = new AuthServ();
            Data = new DataServ();
            CompanyCreation = new CoCreateSvc();
            Permissions = new PermServ();
            Journal = CreateJournalService(provider);
            DatabaseHealth = CreateDatabaseHealth(provider);

            Connectivity = new ConnServ(Logging);
            DeviceInfo = new DevInfoSv(Logging);
            License = new LicenSvc(Logging, DeviceInfo);
            Sync = new SyncServ(Logging, DeviceInfo);
            var inventoryConnection = databaseConnection;
            if (!string.IsNullOrWhiteSpace(inventoryConnection))
            {
                    Inventory = new InvServ(new LicServ(), Permissions,
                        InventoryRepositoryFactory.Create(provider, inventoryConnection));
            }
            else
                Logging.LogWarning("AppHost", "Inventory persistence is unavailable: no database connection configured.");
            Backup = new BkpServ(Logging, DeviceInfo, Sync);
            OnlineCoordinator = new OnlCoord(
                Connectivity, License, Backup, Sync, DeviceInfo, Logging);

            // ✅ تهيئة خدمة التدقيق
            Audit = new AuditService(Logging);

            var usrPref = UsrPref.Load();
            // Default theme is Light unless user explicitly saved Dark.
            var theme = (usrPref.Theme ?? "Light").Trim();
            var isDark = string.Equals(theme, "Dark", System.StringComparison.OrdinalIgnoreCase);
            Theme.Initialize(isDark);

            _initialized = true;
            Logging.LogInfo("AppHost", "Services initialized (offline-first)");

            // ✅ تسجيل بداية تشغيل النظام
            _ = Audit.LogSystemStartAsync();
        }

        private static JournalService? CreateJournalService(string provider)
        {
            var connection = ResolveDatabaseConnection();

            if (string.IsNullOrWhiteSpace(connection))
                connection = AppCfgSvc.Current.ConnectionStrings?.Values.FirstOrDefault()?.ConnectionString;

            if (string.IsNullOrWhiteSpace(connection))
            {
                Logging.LogWarning("AppHost", "Journal persistence is unavailable: no database connection configured.");
                return null;
            }

            return new JournalService(JournalRepositoryFactory.Create(provider, connection));
        }

        private static IDatabaseHealth? CreateDatabaseHealth(string provider)
        {
            var connection = ResolveDatabaseConnection();
            if (string.IsNullOrWhiteSpace(connection))
                return null;
            return DatabaseHealthFactory.Create(provider, connection);
        }

        private static string ResolveDatabaseProvider()
            => DatabaseRuntime.GetProvider();

        private static string? ResolveDatabaseConnection()
        {
            return DatabaseRuntime.GetConnectionString();
        }
    }

    public static class AppServiceHost
    {
        public static ILogServ Logging => AppHost.Logging;
        public static IThmServ Theme => AppHost.Theme;
        public static INavServ Navigation => AppHost.Navigation;
        public static IAuthSvc Auth => AppHost.Auth;
        public static IDataServ Data => AppHost.Data;
        public static ICoCreateSvc CompanyCreation => AppHost.CompanyCreation;
        public static IPermServ Permissions => AppHost.Permissions;
        public static IBkpServ Backup => AppHost.Backup;
        public static IConnSvc Connectivity => AppHost.Connectivity;
        public static IDevInfoSv DeviceInfo => AppHost.DeviceInfo;
        public static ILicenSvc License => AppHost.License;
        public static ISyncSvc Sync => AppHost.Sync;
        public static IOnlCoord OnlineCoordinator => AppHost.OnlineCoordinator;
        public static ISessionManager Session => AppHost.Session;
        public static IAuditService Audit => AppHost.Audit;
        public static JournalService? Journal => AppHost.Journal;
        public static IDatabaseHealth? DatabaseHealth => AppHost.DatabaseHealth;
        public static ILocSvc Localization => AppHost.Localization;
        public static void Initialize() => AppHost.Initialize();
    }

    public static class LanguageDirectionService
    {
        public const string DefaultLanguageCode = LangDirSv.DefaultLanguageCode;
        public static bool IsRtl(string? languageCode) => LangDirSv.IsRtl(languageCode);
        public static FlowDirection GetFlowDirection(string? languageCode) => LangDirSv.GetFlowDirection(languageCode);
        public static void ApplyCulture(string languageCode) => LangDirSv.ApplyCulture(languageCode);
        public static void ApplyToWindow(Window window, string? languageCode = null) => LangDirSv.ApplyToWindow(window, languageCode);
        public static void ApplyToAllWindows(string languageCode) => LangDirSv.ApplyToAllWindows(languageCode);
        public static string NormalizeLanguageCode(string? languageCode) => LangDirSv.NormalizeLanguageCode(languageCode);
    }
}