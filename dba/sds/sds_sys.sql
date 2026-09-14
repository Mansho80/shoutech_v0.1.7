-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sds/sds_sys.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: System Navigation, Seed Data Services & Dynamic WPF Menu Provider
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ── إنشاء المخطط الخاص بالنظام إن لم يكن موجوداً ──
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'sys')
BEGIN
    EXEC('CREATE SCHEMA [sys] AUTHORIZATION [dbo];');
END;
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Navigation & SDS Engine (sys)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;

BEGIN TRY

    -- ── 1. جدول القوائم والتنقل الرئيسي (sys.SystemMenus) ──
    IF OBJECT_ID(N'sys.SystemMenus', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.SystemMenus (
            MenuID              INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            MenuCode            VARCHAR(100) NOT NULL,
            ParentMenuID        INT NULL,
            TitleAR             NVARCHAR(150) NOT NULL,
            TitleEN             VARCHAR(150) NOT NULL,
            TargetViewName      VARCHAR(200) NULL,      -- اسم الواجهة في WPF (e.g. ChartOfAccountsView)
            TargetViewModelName VARCHAR(200) NULL,      -- اسم الـ ViewModel لتفعيل التوجيه الديناميكي
            IconKey             VARCHAR(100) NULL,      -- رمز الأيقونة
            PermissionID        INT NULL,               -- ربط مباشر بجدول sec.Permissions
            DisplayOrder        INT NOT NULL DEFAULT 0,
            IsExpandedByDefault BIT NOT NULL DEFAULT 0,
            IsVisible           BIT NOT NULL DEFAULT 1,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,

            CONSTRAINT PK_sys_SystemMenus PRIMARY KEY CLUSTERED (MenuID),
            CONSTRAINT UQ_sys_SystemMenus_Code UNIQUE (TenantID, CompanyID, MenuCode),
            CONSTRAINT FK_sys_SystemMenus_Parent FOREIGN KEY (ParentMenuID) REFERENCES sys.SystemMenus(MenuID),
            CONSTRAINT FK_sys_SystemMenus_Permission FOREIGN KEY (PermissionID) REFERENCES sec.Permissions(PermissionID)
        );

        CREATE NONCLUSTERED INDEX IX_sys_SystemMenus_Hierarchy 
        ON sys.SystemMenus (TenantID, CompanyID, ParentMenuID, DisplayOrder) 
        WHERE IsActive = 1 AND IsDeleted = 0;
    END;

    -- ── 2. تغذية كتالوج الصلاحيات الأساسية للنظام أولاً (sec.Permissions) ──
    MERGE INTO sec.Permissions AS Target
    USING (VALUES 
        ('PERM_SYS_DASHBOARD', 'SYS', N'عرض لوحة التحكم', 'View Dashboard'),
        ('PERM_FIN_COA',       'FIN', N'إدارة شجرة الحسابات', 'Manage Chart of Accounts'),
        ('PERM_FIN_JOURNAL',   'FIN', N'إدارة القيود اليومية', 'Manage Journal Entries'),
        ('PERM_FIN_PAYMENTS',  'FIN', N'إدارة السندات والمدفوعات', 'Manage Vouchers & Payments'),
        ('PERM_FIN_REPORTS',   'FIN', N'عرض التقارير المالية', 'View Financial Reports'),
        ('PERM_INV_PRODUCTS',  'INV', N'إدارة كروت المنتجات', 'Manage Products'),
        ('PERM_INV_STOCK',     'INV', N'إدارة الحركة المخزنية', 'Manage Stock Operations'),
        ('PERM_CRM_CUSTOMERS', 'CRM', N'إدارة سجل العملاء', 'Manage Customers Directory'),
        ('PERM_CRM_INVOICES',  'CRM', N'إدارة فواتير المبيعات', 'Manage Sales Invoices'),
        ('PERM_HR_EMPLOYEES',  'HR',  N'إدارة ملفات الموظفين', 'Manage Employees'),
        ('PERM_HR_PAYROLL',    'HR',  N'إدارة مسير الرواتب', 'Manage Payroll'),
        ('PERM_SYS_USERS',     'SYS', N'إدارة المستخدمين والصلاحيات', 'Manage Users & Security'),
        ('PERM_SYS_SETTINGS',  'SYS', N'إدارة إعدادات الشركة', 'Manage Company Settings')
    ) AS Source (PermissionCode, ModuleName, PermissionNameAR, PermissionNameEN)
    ON (Target.PermissionCode = Source.PermissionCode)
    WHEN NOT MATCHED THEN
        INSERT (PermissionCode, ModuleName, PermissionNameAR, PermissionNameEN)
        VALUES (Source.PermissionCode, Source.ModuleName, Source.PermissionNameAR, Source.PermissionNameEN);

    -- ── 3. شحن شجرة القوائم وتجهيز العلاقات (System Menus Seeding) ──
    -- (أ) القوائم الرئيسية (Root Categories)
    IF NOT EXISTS (SELECT 1 FROM sys.SystemMenus WHERE MenuCode = 'MNU_DASHBOARD')
        INSERT INTO sys.SystemMenus (MenuCode, TitleAR, TitleEN, TargetViewName, IconKey, PermissionID, DisplayOrder)
        VALUES ('MNU_DASHBOARD', N'لوحة التحكم', 'Dashboard', 'DashboardView', 'ViewDashboard', (SELECT PermissionID FROM sec.Permissions WHERE PermissionCode='PERM_SYS_DASHBOARD'), 10);

    IF NOT EXISTS (SELECT 1 FROM sys.SystemMenus WHERE MenuCode = 'MNU_FINANCE')
        INSERT INTO sys.SystemMenus (MenuCode, TitleAR, TitleEN, IconKey, DisplayOrder)
        VALUES ('MNU_FINANCE', N'الإدارة المالية', 'Financial Management', 'Finance', 20);

    IF NOT EXISTS (SELECT 1 FROM sys.SystemMenus WHERE MenuCode = 'MNU_INVENTORY')
        INSERT INTO sys.SystemMenus (MenuCode, TitleAR, TitleEN, IconKey, DisplayOrder)
        VALUES ('MNU_INVENTORY', N'المخزون والمستودعات', 'Inventory System', 'Warehouse', 30);

    IF NOT EXISTS (SELECT 1 FROM sys.SystemMenus WHERE MenuCode = 'MNU_CRM')
        INSERT INTO sys.SystemMenus (MenuCode, TitleAR, TitleEN, IconKey, DisplayOrder)
        VALUES ('MNU_CRM', N'المبيعات والعملاء', 'Sales & CRM', 'AccountGroup', 40);

    IF NOT EXISTS (SELECT 1 FROM sys.SystemMenus WHERE MenuCode = 'MNU_SYS_ADMIN')
        INSERT INTO sys.SystemMenus (MenuCode, TitleAR, TitleEN, IconKey, DisplayOrder)
        VALUES ('MNU_SYS_ADMIN', N'إعدادات النظام', 'System Admin', 'Cog', 90);

    -- (ب) القوائم الفرعية (Child Items)
    DECLARE @FinID INT = (SELECT MenuID FROM sys.SystemMenus WHERE MenuCode = 'MNU_FINANCE');
    DECLARE @InvID INT = (SELECT MenuID FROM sys.SystemMenus WHERE MenuCode = 'MNU_INVENTORY');
    DECLARE @SysID INT = (SELECT MenuID FROM sys.SystemMenus WHERE MenuCode = 'MNU_SYS_ADMIN');

    IF NOT EXISTS (SELECT 1 FROM sys.SystemMenus WHERE MenuCode = 'MNU_FIN_COA')
        INSERT INTO sys.SystemMenus (ParentMenuID, MenuCode, TitleAR, TitleEN, TargetViewName, TargetViewModelName, IconKey, PermissionID, DisplayOrder)
        VALUES (@FinID, 'MNU_FIN_COA', N'شجرة الحسابات', 'Chart of Accounts', 'ChartOfAccountsView', 'ChartOfAccountsViewModel', 'Sitemap', (SELECT PermissionID FROM sec.Permissions WHERE PermissionCode='PERM_FIN_COA'), 21);

    IF NOT EXISTS (SELECT 1 FROM sys.SystemMenus WHERE MenuCode = 'MNU_FIN_JOURNAL')
        INSERT INTO sys.SystemMenus (ParentMenuID, MenuCode, TitleAR, TitleEN, TargetViewName, TargetViewModelName, IconKey, PermissionID, DisplayOrder)
        VALUES (@FinID, 'MNU_FIN_JOURNAL', N'القيود اليومية', 'Journal Entries', 'JournalEntriesView', 'JournalEntriesViewModel', 'BookOpenPageVariant', (SELECT PermissionID FROM sec.Permissions WHERE PermissionCode='PERM_FIN_JOURNAL'), 22);

    IF NOT EXISTS (SELECT 1 FROM sys.SystemMenus WHERE MenuCode = 'MNU_SYS_USERS')
        INSERT INTO sys.SystemMenus (ParentMenuID, MenuCode, TitleAR, TitleEN, TargetViewName, TargetViewModelName, IconKey, PermissionID, DisplayOrder)
        VALUES (@SysID, 'MNU_SYS_USERS', N'إدارة المستخدمين والصلاحيات', 'Users & Security', 'UsersManagementView', 'UsersManagementViewModel', 'ShieldAccount', (SELECT PermissionID FROM sec.Permissions WHERE PermissionCode='PERM_SYS_USERS'), 91);

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Navigation Menus and Permissions fully seeded (sys.SystemMenus).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] sds_sys.sql failed: %s', 16, 1, @ErrMsg);
END CATCH;
GO

-- ═════════════════════════════════════════════════════════════════════════════════
-- 4. الإجراء المخزن عالي الأداء لجلب قوائم المستخدم المسموحة لـ WPF
-- ═════════════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sys.sp_GetUserNavigationMenu
    @UserID   INT,
    @TenantID INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- التحقق مما إذا كان المستخدم SuperAdmin
    DECLARE @IsSuperAdmin BIT = 0;
    SELECT @IsSuperAdmin = IsSuperAdmin 
    FROM sec.Users 
    WHERE UserID = @UserID AND TenantID = @TenantID AND IsActive = 1 AND IsDeleted = 0;

    -- جلب القوائم المصرح بها فقط بناءً على أدوار وصلاحيات المستخدم
    WITH UserPermissions AS (
        SELECT DISTINCT rp.PermissionID
        FROM sec.UserRoles ur
        INNER JOIN sec.RolePermissions rp ON ur.RoleID = rp.RoleID
        WHERE ur.UserID = @UserID
    )
    SELECT 
        m.MenuID,
        m.MenuCode,
        m.ParentMenuID,
        m.TitleAR,
        m.TitleEN,
        m.TargetViewName,
        m.TargetViewModelName,
        m.IconKey,
        m.DisplayOrder,
        m.IsExpandedByDefault
    FROM sys.SystemMenus m
    WHERE m.TenantID = @TenantID
      AND m.IsActive = 1 
      AND m.IsDeleted = 0
      AND (
            @IsSuperAdmin = 1 
            OR m.PermissionID IS NULL 
            OR m.PermissionID IN (SELECT PermissionID FROM UserPermissions)
          )
    ORDER BY m.ParentMenuID ASC, m.DisplayOrder ASC;
END;
GO