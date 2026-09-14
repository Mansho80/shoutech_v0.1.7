using ShouTech.App.Services;

namespace ShouTech.App.Common
{
    /// <summary>Fixed English text for the main window status bar (never localized).</summary>
    internal static class StatBarEn
    {
        public const string Ready = "Ready";
        public const string Dashboard = "Executive Dashboard";
        public const string Loading = "Loading...";
        public const string About = "About";
        public const string Save = "Saving...";
        public const string Undo = "Undo";
        public const string Redo = "Redo";
        public const string Print = "Printing...";
        public const string Search = "Search...";
        public const string SaveSuccess = "Saved successfully";
        public const string OperationFailed = "Operation failed";
        public const string ViewerMode = "Read-only mode";
        public const string DarkMode = "Dark mode";
        public const string LightMode = "Light mode";
        public const string DefaultCompany = "Main Company";
        public const string Version = "Version 10.6.0";
        public const string UserLabel = "User";

        public static string RoleLabel(UsrAccLvl level) => level switch
        {
            UsrAccLvl.Administrator => "Administrator",
            UsrAccLvl.Viewer => "Viewer",
            _ => "User"
        };

        public static string ModuleName(string moduleKey) => moduleKey switch
        {
            "File" => "File",
            "Inventory" => "Inventory",
            "Accounting" => "Accounting",
            "Vouchers" => "Vouchers",
            "Invoices" => "Invoices",
            "PointOfSale" => "Point of Sale",
            "Orders" => "Orders",
            "Customers" => "Customers",
            "SalesRepresentative" => "Sales Representative",
            "Manufacturing" => "Manufacturing",
            "Banks" => "Banks",
            "Reports" => "Reports",
            "Tools" => "Tools",
            "Administration" => "Administration",
            "View" => "View",
            "Session" => "Session",
            "Help" => "Help",
            _ => "General"
        };

        public static string BuildUserDisplay(string username, string fullName, UsrAccLvl accessLevel)
        {
            var role = RoleLabel(accessLevel);
            if (string.IsNullOrWhiteSpace(username))
                return role;

            if (string.IsNullOrWhiteSpace(fullName) || fullName.Equals(username, System.StringComparison.OrdinalIgnoreCase))
                return $"{UserLabel}: {username} — {role}";

            return $"{UserLabel}: {username} — {role}";
        }
    }
}
