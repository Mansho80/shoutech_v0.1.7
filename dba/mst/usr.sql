-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/mst/usr.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Master Security & Identity Architecture (RBAC)
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ── إنشاء المخطط الخاص بالأمان إن لم يكن موجوداً ──
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'sec')
BEGIN
    EXEC('CREATE SCHEMA [sec] AUTHORIZATION [dbo];');
END;
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Initializing Security & Identity Schema (sec)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;

BEGIN TRY

    -- ── 1. جدول المستخدمين (sec.Users) ──
    IF OBJECT_ID(N'sec.Users', N'U') IS NULL
    BEGIN
        CREATE TABLE sec.Users (
            UserID              INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            UserGuid            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
            Username            NVARCHAR(100) NOT NULL,
            NormalizedUsername  AS UPPER(Username) PERSISTED,
            PasswordHash        NVARCHAR(500) NOT NULL,
            SecurityStamp       NVARCHAR(100) NULL,
            FullName            NVARCHAR(200) NOT NULL,
            Email               NVARCHAR(150) NULL,
            PhoneNumber         VARCHAR(30) NULL,
            AccessFailedCount   INT NOT NULL DEFAULT 0,
            LockoutEnabled      BIT NOT NULL DEFAULT 1,
            LockoutEnd          DATETIMEOFFSET NULL,
            IsSuperAdmin        BIT NOT NULL DEFAULT 0,
            IsActive            BIT NOT NULL DEFAULT 1,
            
            -- Audit & Soft Delete
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedBy           INT NULL,
            UpdatedAt           DATETIME2(7) NULL,
            DeletedBy           INT NULL,
            DeletedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,

            CONSTRAINT PK_sec_Users PRIMARY KEY CLUSTERED (UserID),
            CONSTRAINT UQ_sec_Users_UserGuid UNIQUE (UserGuid),
            CONSTRAINT UQ_sec_Users_Username UNIQUE (TenantID, CompanyID, NormalizedUsername)
        );

        CREATE NONCLUSTERED INDEX IX_sec_Users_Lookup 
        ON sec.Users (TenantID, CompanyID, IsActive) 
        INCLUDE (Username, FullName, Email) 
        WHERE IsDeleted = 0;
    END;

    -- ── 2. جدول الأدوار (sec.Roles) ──
    IF OBJECT_ID(N'sec.Roles', N'U') IS NULL
    BEGIN
        CREATE TABLE sec.Roles (
            RoleID              INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            RoleCode            VARCHAR(50) NOT NULL,
            RoleNameAR          NVARCHAR(100) NOT NULL,
            RoleNameEN          VARCHAR(100) NOT NULL,
            Description         NVARCHAR(500) NULL,
            IsSystemRole        BIT NOT NULL DEFAULT 0,
            IsActive            BIT NOT NULL DEFAULT 1,
            
            -- Audit & Soft Delete
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedBy           INT NULL,
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,

            CONSTRAINT PK_sec_Roles PRIMARY KEY CLUSTERED (RoleID),
            CONSTRAINT UQ_sec_Roles_Code UNIQUE (TenantID, CompanyID, RoleCode)
        );
    END;

    -- ── 3. جدول كتالوج الصلاحيات الدقيقة (sec.Permissions) ──
    IF OBJECT_ID(N'sec.Permissions', N'U') IS NULL
    BEGIN
        CREATE TABLE sec.Permissions (
            PermissionID        INT IDENTITY(1,1) NOT NULL,
            PermissionCode      VARCHAR(100) NOT NULL,
            ModuleName          VARCHAR(50) NOT NULL,
            PermissionNameAR    NVARCHAR(150) NOT NULL,
            PermissionNameEN    VARCHAR(150) NOT NULL,
            Description         NVARCHAR(300) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),

            CONSTRAINT PK_sec_Permissions PRIMARY KEY CLUSTERED (PermissionID),
            CONSTRAINT UQ_sec_Permissions_Code UNIQUE (PermissionCode)
        );
    END;

    -- ── 4. جدول ربط الأدوار بالصلاحيات (sec.RolePermissions) ──
    IF OBJECT_ID(N'sec.RolePermissions', N'U') IS NULL
    BEGIN
        CREATE TABLE sec.RolePermissions (
            RoleID              INT NOT NULL,
            PermissionID        INT NOT NULL,
            GrantedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            GrantedBy           INT NULL,

            CONSTRAINT PK_sec_RolePermissions PRIMARY KEY CLUSTERED (RoleID, PermissionID),
            CONSTRAINT FK_sec_RolePermissions_Roles FOREIGN KEY (RoleID) REFERENCES sec.Roles(RoleID) ON DELETE CASCADE,
            CONSTRAINT FK_sec_RolePermissions_Permissions FOREIGN KEY (PermissionID) REFERENCES sec.Permissions(PermissionID) ON DELETE CASCADE
        );
    END;

    -- ── 5. جدول تعيين الأدوار للمستخدمين (sec.UserRoles) ──
    IF OBJECT_ID(N'sec.UserRoles', N'U') IS NULL
    BEGIN
        CREATE TABLE sec.UserRoles (
            UserID              INT NOT NULL,
            RoleID              INT NOT NULL,
            AssignedAt          DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            AssignedBy          INT NULL,

            CONSTRAINT PK_sec_UserRoles PRIMARY KEY CLUSTERED (UserID, RoleID),
            CONSTRAINT FK_sec_UserRoles_Users FOREIGN KEY (UserID) REFERENCES sec.Users(UserID) ON DELETE CASCADE,
            CONSTRAINT FK_sec_UserRoles_Roles FOREIGN KEY (RoleID) REFERENCES sec.Roles(RoleID) ON DELETE CASCADE
        );
    END;

    -- ── 6. جدول جلسات المستخدمين والتتبع (sec.UserSessions) ──
    IF OBJECT_ID(N'sec.UserSessions', N'U') IS NULL
    BEGIN
        CREATE TABLE sec.UserSessions (
            SessionID           BIGINT IDENTITY(1,1) NOT NULL,
            SessionToken        UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
            UserID              INT NOT NULL,
            WorkstationName     VARCHAR(100) NULL,
            IPAddress           VARCHAR(45) NULL,
            AppVersion          VARCHAR(20) NULL,
            LoginTime           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            LastHeartbeat       DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            LogoutTime          DATETIME2(7) NULL,
            IsRevoked           BIT NOT NULL DEFAULT 0,

            CONSTRAINT PK_sec_UserSessions PRIMARY KEY CLUSTERED (SessionID),
            CONSTRAINT UQ_sec_UserSessions_Token UNIQUE (SessionToken),
            CONSTRAINT FK_sec_UserSessions_Users FOREIGN KEY (UserID) REFERENCES sec.Users(UserID)
        );
    END;

    -- ── 7. تغذية البيانات الأولية للنظام (Enterprise Seeding) ──
    IF NOT EXISTS (SELECT 1 FROM sec.Users WHERE NormalizedUsername = 'ADMIN')
    BEGIN
        INSERT INTO sec.Users (TenantID, CompanyID, Username, PasswordHash, FullName, Email, IsSuperAdmin, IsActive)
        VALUES (1, 1, 'admin', 'AQAAAAEAACcQAAAAEH2...', N'مدير النظام القياسي', 'admin@shoutech.com', 1, 1);
    END;

    IF NOT EXISTS (SELECT 1 FROM sec.Roles WHERE RoleCode = 'ROLE_SUPERADMIN')
    BEGIN
        INSERT INTO sec.Roles (TenantID, CompanyID, RoleCode, RoleNameAR, RoleNameEN, IsSystemRole, IsActive)
        VALUES (1, 1, 'ROLE_SUPERADMIN', N'مدير النظام الأعلى', 'Super Administrator', 1, 1);
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Security Schema & Tables created successfully (sec.*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] usr.sql failed: %s', 16, 1, @Err);
END CATCH;
GO