using System;

namespace ShouTech.App.Services
{
    /// <summary>
    /// تطبيق وهمي لإدارة الجلسة (سيتم تطويره لاحقاً)
    /// </summary>
    public class SessionManager : ISessionManager
    {
        public string? CurrentUser { get; set; }
        public bool IsLoggedIn => !string.IsNullOrEmpty(CurrentUser);

        public void Login(string username)
        {
            CurrentUser = username;
            AppHost.Logging.LogInfo("Session", $"✅ بدء جلسة المستخدم: {username}");
        }

        public void Logout()
        {
            if (CurrentUser != null)
            {
                AppHost.Logging.LogInfo("Session", $"🚪 إنهاء جلسة المستخدم: {CurrentUser}");
                CurrentUser = null;
            }
        }
    }
}