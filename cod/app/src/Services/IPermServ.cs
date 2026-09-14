// shoutech_erp_v0.1.6/cod/app/src/Services/IPermServ.cs
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    /// <summary>
    /// Permission keys used across the system.
    /// Keep values stable after release.
    /// </summary>
    public static class PermKey
    {
        // System
        public const string SysAdmin = "SYS.ADMIN";
        public const string SysSettings = "SYS.SETTINGS";
        public const string SysUsers = "SYS.USERS";
        public const string SysBackup = "SYS.BACKUP";

        // Accounting
        public const string AccView = "ACC.VIEW";
        public const string AccCreate = "ACC.CREATE";
        public const string AccPost = "ACC.POST";
        public const string AccDelete = "ACC.DELETE";

        // Inventory
        public const string InvView = "INV.VIEW";
        public const string InvCreate = "INV.CREATE";
        public const string InvMove = "INV.MOVE";
        public const string InvDelete = "INV.DELETE";

        // Sales
        public const string SalesView = "SALES.VIEW";
        public const string SalesCreate = "SALES.CREATE";
        public const string SalesPost = "SALES.POST";

        // Purchase
        public const string PurchView = "PURCH.VIEW";
        public const string PurchCreate = "PURCH.CREATE";
        public const string PurchPost = "PURCH.POST";
    }

    public interface IPermServ
    {
        /// <summary>
        /// Returns true if the current user has the given permission.
        /// </summary>
        bool Has(string permissionKey);

        /// <summary>
        /// Returns true if the current user has ALL of the given permissions.
        /// </summary>
        bool HasAll(params string[] permissionKeys);

        /// <summary>
        /// Returns true if the current user has ANY of the given permissions.
        /// </summary>
        bool HasAny(params string[] permissionKeys);

        /// <summary>
        /// Loads permissions for the given user (called after login).
        /// </summary>
        Task LoadForUserAsync(string userId, CancellationToken ct = default);

        /// <summary>
        /// Clears loaded permissions (called on logout).
        /// </summary>
        void Clear();

        /// <summary>
        /// Returns a snapshot of currently loaded permissions.
        /// </summary>
        IReadOnlyCollection<string> GetCurrentPermissions();
    }
}