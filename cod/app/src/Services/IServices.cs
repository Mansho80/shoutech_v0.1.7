using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ShouTech.App.Configuration;

namespace ShouTech.App.Services
{
    public interface IDataService
    {
        Task<int> GetTotalCustomersAsync();
        Task<int> GetTotalProductsAsync();
        Task<int> GetTotalPendingApprovalsAsync();
        Task<List<RecentDocument>> GetRecentDocumentsAsync(int count);
    }

    public interface IDataServ : IDataService { }

    public interface ICompanyRegistryService
    {
        Task<List<CompanyInfo>> GetCompaniesAsync();
        Task<bool> HasCompaniesAsync();
    }

    public interface ICoRegSvc : ICompanyRegistryService { }

    public interface IPermissionService
    {
        bool HasPermission(string permissionKey);
    }

    public interface IThemeService
    {
        event EventHandler<bool>? ThemeChanged;

        bool GetCurrentTheme();
        void Initialize(bool isDark);
        void SetTheme(bool isDark);
        void ToggleTheme();
    }

    public interface IThmServ : IThemeService { }

    public interface IBackupService
    {
        void PerformBackup();
    }

    public interface INavigationService
    {
        object NavigateTo(string pageKey);
        Task<object> NavigateToAsync(string pageKey);
        object NavigateToModule(string actionTitle, string moduleKey, string? tabName = null, string? tabHeader = null);
        void ClearCache();
    }

    public interface INavServ : INavigationService { }

    public interface ILoggingService
    {
        void LogInfo(string category, string message);
        void LogWarning(string category, string message);
        void LogError(string category, string message, Exception? ex = null);
    }

    public interface ILogServ : ILoggingService
    {
        void LogAuthAttempt(string username, bool success, string? reason = null);
    }

    public interface IAuthService
    {
        Task<AuthResult> LoginAsync(string username, string password);
        Task LogoutAsync();
        Task<UserInfo?> GetCurrentUserAsync();
        bool IsAuthenticated { get; }
    }

    public interface ICoCreateSvc
    {
        Task<CoCreateResult> CreateAsync(NewCoReq request);
    }

    public interface ISessionManager
    {
        string? CurrentUser { get; set; }
        bool IsLoggedIn { get; }
        void Login(string username);
        void Logout();
    }

    public interface IAuditService
    {
        Task LogSystemStartAsync();
        Task LogSystemStopAsync();
    }

    public class UserModel
    {
        public string UserId { get; set; } = "USER-001";
        public string FullName { get; set; } = "المدير العام";
        public string Email { get; set; } = "admin@shoutech.com";
        public string CompanyName { get; set; } = "شو تيك للبرمجيات";
        public bool IsAuthenticated { get; set; } = true;
        public List<string> Roles { get; set; } = new();
    }

    public class RecentDocument
    {
        public string DocumentNumber { get; set; } = "";
        public string DocumentType { get; set; } = "";
        public DateTime Date { get; set; } = DateTime.Now;
        public string CustomerName { get; set; } = "";
        public decimal TotalAmount { get; set; }
        public string Status { get; set; } = "";
    }
}