namespace ShouTech.App.Services
{
    /// <summary>
    /// Application-wide authenticated session snapshot for shell UI and services.
    /// </summary>
    public static class UsrSession
    {
        public static UserInfo? Current { get; private set; }

        public static bool IsAuthenticated => Current?.IsAuthenticated == true;
        public static bool IsAdministrator => Current?.IsAdministrator == true;
        public static bool IsViewer => Current?.IsViewer == true;
        public static bool IsReadOnly => Current?.IsReadOnly == true;

        public static void Apply(UserInfo? user) => Current = user;

        public static void Clear() => Current = null;
    }
}
