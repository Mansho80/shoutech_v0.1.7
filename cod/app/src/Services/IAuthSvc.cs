// ========================================================================
// FILE: Services/IAuthSvc.cs
// PROJECT: SHOUTECH ERP V10
// ========================================================================

using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    public interface IAuthSvc
    {
        Task<AuthResult> LoginAsync(string username, string password);
        Task LogoutAsync();
        Task<UserInfo?> GetCurrentUserAsync();
        bool IsAuthenticated { get; }
    }

    public class AuthResult
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public UserInfo? User { get; set; }
        public string? Token { get; set; }
    }

    public class UserInfo
    {
        public string Id { get; set; } = string.Empty;
        public string Username { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
        public string RoleCode { get; set; } = string.Empty;
        public UsrAccLvl AccessLevel { get; set; } = UsrAccLvl.User;
        public bool IsSuperAdmin { get; set; }
        public string[]? Permissions { get; set; }
        public string? CompanyId { get; set; }
        public string? CompanyName { get; set; }
        public bool IsAuthenticated { get; set; }
        public DateTime LastLogin { get; set; }
        public string? AvatarUrl { get; set; }

        public bool IsAdministrator => AccessLevel == UsrAccLvl.Administrator || IsSuperAdmin;
        public bool IsViewer => AccessLevel == UsrAccLvl.Viewer;
        public bool IsReadOnly => IsViewer;
    }
}