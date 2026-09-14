-- ============================================================================
-- FILE       : mst.sys
-- PROJECT    : SHOUTECH ERP V10
-- MODULE     : MASTER DATABASE
-- VERSION    : 10.0.0 Ultimate+
-- TARGET     : SQL Server 2019
-- DESCRIPTION:
-- Central Master Database for:
--   - Companies
--   - Users
--   - Fiscal Years
--   - Licensing
--   - Security
--   - Audit
--   - Monitoring
--   - System Configuration
--
-- DESIGN GOALS:
--   ✅ Enterprise Ready
--   ✅ SQL Server 2019 Compatible
--   ✅ Idempotent Deployment
--   ✅ Soft Delete
--   ✅ RowVersion
--   ✅ Audit Ready
--   ✅ Backup Ready
--   ✅ High Performance Indexing
-- ============================================================================

USE master;
GO

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

SET XACT_ABORT ON;
GO

SET NOCOUNT ON;
GO

PRINT N'=====================================================================';
PRINT N'SHOUTECH ERP V10 Ultimate+ - Master Database Deployment';
PRINT N'=====================================================================';
GO

-- ============================================================================
-- SQLCMD VARIABLES
-- ============================================================================

:setvar MST_DB_NAME "SHOUTECH_MST"
:setvar MST_DATA_PATH "C:\SHOUTECH\MST\Data\"
:setvar MST_LOG_PATH  "C:\SHOUTECH\MST\Log\"

-- ============================================================================
-- CREATE DATABASE
-- ============================================================================

IF DB_ID(N'$(MST_DB_NAME)') IS NULL
BEGIN

    DECLARE @CreateDB nvarchar(max);

    SET @CreateDB = N'
    CREATE DATABASE [$(MST_DB_NAME)]
    ON PRIMARY
    (
        NAME = N''$(MST_DB_NAME)_Data'',
        FILENAME = N''$(MST_DATA_PATH)$(MST_DB_NAME).mdf'',
        SIZE = 256MB,
        FILEGROWTH = 64MB
    )
    LOG ON
    (
        NAME = N''$(MST_DB_NAME)_Log'',
        FILENAME = N''$(MST_LOG_PATH)$(MST_DB_NAME)_Log.ldf'',
        SIZE = 128MB,
        FILEGROWTH = 64MB
    );';

    EXEC sys.sp_executesql @CreateDB;

    PRINT N'[OK] Database created.';
END
ELSE
BEGIN
    PRINT N'[SKIP] Database already exists.';
END
GO

USE [$(MST_DB_NAME)];
GO

-- ============================================================================
-- DATABASE SETTINGS
-- ============================================================================

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_scoped_configurations
    WHERE name = 'MAXDOP'
)
BEGIN
    PRINT N'[INFO] Database configuration check.';
END

ALTER DATABASE CURRENT SET READ_COMMITTED_SNAPSHOT ON;
ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

-- ============================================================================
-- SCHEMAS
-- ============================================================================

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = 'cfg'
)
EXEC('CREATE SCHEMA cfg');
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = 'aud'
)
EXEC('CREATE SCHEMA aud');
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = 'lic'
)
EXEC('CREATE SCHEMA lic');
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = 'ops'
)
EXEC('CREATE SCHEMA ops');
GO

-- ============================================================================
-- DEPLOYMENT LOG
-- ============================================================================

IF OBJECT_ID('dbo.DeploymentHistory','U') IS NULL
BEGIN

    CREATE TABLE dbo.DeploymentHistory
    (
        DeploymentID       bigint IDENTITY(1,1) NOT NULL,
        VersionNumber      nvarchar(50) NOT NULL,
        DeploymentDateUTC  datetime2(7) NOT NULL
            CONSTRAINT DF_DeploymentHistory_Date
            DEFAULT SYSUTCDATETIME(),

        ExecutedBy         sysname NULL,

        Notes              nvarchar(2000) NULL,

        RowVersion         rowversion,

        CONSTRAINT PK_DeploymentHistory
        PRIMARY KEY CLUSTERED
        (
            DeploymentID
        )
    );

END
GO

-- ============================================================================
-- SYSTEM SETTINGS
-- ============================================================================

IF OBJECT_ID('cfg.SystemSettings','U') IS NULL
BEGIN

    CREATE TABLE cfg.SystemSettings
    (
        SettingID bigint IDENTITY(1,1) NOT NULL,

        SettingCategory nvarchar(100) NOT NULL,

        SettingKey nvarchar(200) NOT NULL,

        SettingValue nvarchar(max) NULL,

        SettingType nvarchar(20) NOT NULL
            CONSTRAINT DF_SystemSettings_Type
            DEFAULT 'STRING',

        IsEncrypted bit NOT NULL
            CONSTRAINT DF_SystemSettings_Encrypted
            DEFAULT 0,

        IsSystem bit NOT NULL
            CONSTRAINT DF_SystemSettings_System
            DEFAULT 0,

        CreatedAt datetime2(7) NOT NULL
            CONSTRAINT DF_SystemSettings_CreatedAt
            DEFAULT SYSUTCDATETIME(),

        UpdatedAt datetime2(7) NULL,

        RowVersion rowversion,

        CONSTRAINT PK_SystemSettings
            PRIMARY KEY CLUSTERED (SettingID),

        CONSTRAINT UQ_SystemSettings
            UNIQUE
            (
                SettingCategory,
                SettingKey
            ),

        CONSTRAINT CK_SystemSettings_Type
            CHECK
            (
                SettingType IN
                (
                    'STRING',
                    'INT',
                    'BOOL',
                    'DECIMAL',
                    'JSON'
                )
            )
    );

END
GO


-- ============================================================================
-- SECTION 1
-- COMPANIES
-- ============================================================================

IF OBJECT_ID('dbo.Companies','U') IS NULL
BEGIN

    CREATE TABLE dbo.Companies
    (
        CompanyID uniqueidentifier NOT NULL
            CONSTRAINT DF_Companies_ID
            DEFAULT NEWID(),

        CompanyCode nvarchar(50) NOT NULL,

        CompanyNameAR nvarchar(250) NOT NULL,

        CompanyNameEN nvarchar(250) NULL,

        TaxNumber nvarchar(50) NULL,

        CommercialRegistration nvarchar(100) NULL,

        CreatedBy UNIQUEIDENTIFIER NULL,

        UpdatedBy UNIQUEIDENTIFIER NULL,

        DeletedBy UNIQUEIDENTIFIER NULL,

        Phone nvarchar(50) NULL,

        Mobile nvarchar(50) NULL,

        Email nvarchar(255) NULL,

        Website nvarchar(255) NULL,

        AddressLine1 nvarchar(255) NULL,

        AddressLine2 nvarchar(255) NULL,

        City nvarchar(100) NULL,

        Country nvarchar(100) NULL,

        CurrencyCode char(3) NOT NULL
            CONSTRAINT DF_Companies_Currency
            DEFAULT 'SAR',

        LanguageCode nvarchar(10) NOT NULL
            CONSTRAINT DF_Companies_Language
            DEFAULT 'ar-SA',

        IsActive bit NOT NULL
            CONSTRAINT DF_Companies_IsActive
            DEFAULT 1,

        IsDeleted bit NOT NULL
            CONSTRAINT DF_Companies_IsDeleted
            DEFAULT 0,

        DeletedAt datetime2(7) NULL,

        CreatedAt datetime2(7) NOT NULL
            CONSTRAINT DF_Companies_CreatedAt
            DEFAULT SYSUTCDATETIME(),

        UpdatedAt datetime2(7) NULL,
        CreatedBy UNIQUEIDENTIFIER NULL,
        UpdatedBy UNIQUEIDENTIFIER NULL,
        DeletedBy UNIQUEIDENTIFIER NULL,
        RowVersion rowversion,

        CONSTRAINT PK_Companies
            PRIMARY KEY CLUSTERED
            (
                CompanyID
            ),

        CONSTRAINT UQ_Companies_Code
            UNIQUE
            (
                CompanyCode
            )
    );

END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Companies_Active'
      AND object_id = OBJECT_ID('dbo.Companies')
)
BEGIN

    CREATE NONCLUSTERED INDEX IX_Companies_Active
    ON dbo.Companies
    (
        IsActive
    )
    WHERE IsDeleted = 0;

END;
GO

-- ============================================================================
-- SECTION 2
-- USERS
-- ============================================================================

IF OBJECT_ID('dbo.Users','U') IS NULL
BEGIN

    CREATE TABLE dbo.Users
    (
        UserID uniqueidentifier NOT NULL
            CONSTRAINT DF_Users_ID
            DEFAULT NEWID(),

        CompanyID uniqueidentifier NOT NULL,

        Username nvarchar(100) NOT NULL,

        PasswordHash nvarchar(500) NOT NULL,

        PasswordSalt nvarchar(500) NOT NULL,

        MustChangePassword BIT NOT NULL DEFAULT 1,

        TwoFactorEnabled BIT NOT NULL DEFAULT 0,

        LastPasswordChangeDate DATETIME2(7) NULL,

        FullNameAR nvarchar(250) NOT NULL,

        FullNameEN nvarchar(250) NULL,

        Email nvarchar(255) NULL,

        Mobile nvarchar(50) NULL,

        PreferredLanguage nvarchar(10)
            CONSTRAINT DF_Users_Language
            DEFAULT 'ar-SA',

        IsLocked bit NOT NULL
            CONSTRAINT DF_Users_Locked
            DEFAULT 0,

        FailedLoginAttempts int NOT NULL
            CONSTRAINT DF_Users_Failed
            DEFAULT 0,

        LastLoginDate datetime2(7) NULL,

        PasswordChangedAt datetime2(7) NULL,

        IsActive bit NOT NULL
            CONSTRAINT DF_Users_Active
            DEFAULT 1,

        IsDeleted bit NOT NULL
            CONSTRAINT DF_Users_Deleted
            DEFAULT 0,

        DeletedAt datetime2(7) NULL,

        CreatedAt datetime2(7) NOT NULL
            CONSTRAINT DF_Users_CreatedAt
            DEFAULT SYSUTCDATETIME(),

        UpdatedAt datetime2(7) NULL,

        RowVersion rowversion,

        CONSTRAINT PK_Users
            PRIMARY KEY CLUSTERED
            (
                UserID
            ),

        CONSTRAINT FK_Users_Company
            FOREIGN KEY
            (
                CompanyID
            )
            REFERENCES dbo.Companies
            (
                CompanyID
            ),

        CONSTRAINT UQ_Users_Username
            UNIQUE
            (
                Username
            )
    );

END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'UX_Users_Email'
      AND object_id = OBJECT_ID('dbo.Users')
)
BEGIN

    CREATE UNIQUE NONCLUSTERED INDEX UX_Users_Email
    ON dbo.Users
    (
        Email
    )
    WHERE Email IS NOT NULL;

END;
GO

-- ============================================================================
-- SECTION 3
-- FISCAL YEARS
-- ============================================================================

IF OBJECT_ID('dbo.FiscalYears','U') IS NULL
BEGIN

    CREATE TABLE dbo.FiscalYears
    (
        FiscalYearID bigint IDENTITY(1,1) NOT NULL,

        CompanyID uniqueidentifier NOT NULL,

        FiscalYear int NOT NULL,

        DatabaseName nvarchar(128) NOT NULL,

        DatabaseVersion NVARCHAR(50) NULL,

        LastBackupDate DATETIME2(7) NULL,

        StartDate date NOT NULL,

        EndDate date NOT NULL,

        IsCurrent bit NOT NULL
            DEFAULT 0,

        IsClosed bit NOT NULL
            DEFAULT 0,

        ClosedAt datetime2(7) NULL,

        CreatedAt datetime2(7) NOT NULL
            DEFAULT SYSUTCDATETIME(),

        RowVersion rowversion,

        CONSTRAINT PK_FiscalYears
            PRIMARY KEY CLUSTERED
            (
                FiscalYearID
            ),

        CONSTRAINT UQ_FiscalYears
            UNIQUE
            (
                CompanyID,
                FiscalYear
            ),

        CONSTRAINT FK_FiscalYears_Company
            FOREIGN KEY
            (
                CompanyID
            )
            REFERENCES dbo.Companies
            (
                CompanyID
            )
    );

END;
GO

-- ============================================================================
-- SECTION 4
-- LOGIN HISTORY
-- ============================================================================

IF OBJECT_ID('dbo.LoginHistory','U') IS NULL
BEGIN

    CREATE TABLE dbo.LoginHistory
    (
        LoginHistoryID bigint IDENTITY(1,1) NOT NULL,

        UserID uniqueidentifier NOT NULL,

        LoginDate datetime2(7) NOT NULL
            DEFAULT SYSUTCDATETIME(),

        LoginStatus nvarchar(20) NOT NULL,

        IPAddress nvarchar(50) NULL,

        UserAgent nvarchar(500) NULL,

        FailureReason nvarchar(500) NULL,

        RowVersion rowversion,

        MachineName NVARCHAR(100),
        
        SessionID NVARCHAR(100),

        CONSTRAINT PK_LoginHistory
            PRIMARY KEY CLUSTERED
            (
                LoginHistoryID
            ),

        CONSTRAINT FK_LoginHistory_User
            FOREIGN KEY
            (
                UserID
            )
            REFERENCES dbo.Users
            (
                UserID
            )
    );

END;
GO

-- ============================================================================
-- SECTION 5
-- LICENSES
-- ============================================================================

IF OBJECT_ID('lic.Licenses','U') IS NULL
BEGIN

    CREATE TABLE lic.Licenses
    (
        LicenseID uniqueidentifier NOT NULL
            CONSTRAINT DF_Licenses_ID
            DEFAULT NEWID(),

        CompanyID uniqueidentifier NOT NULL,

        LicenseKey nvarchar(500) NOT NULL,

        LicenseKeyHash VARBINARY(64),

        Edition nvarchar(30) NOT NULL,

        MaxUsers int NOT NULL,

        MaxCompanies int NOT NULL,

        MaxDevices int NOT NULL,

        ActivationDate datetime2(7) NULL,

        ExpiryDate date NOT NULL,

        IsActive bit NOT NULL
            CONSTRAINT DF_Licenses_IsActive
            DEFAULT 1,

        IsDeleted bit NOT NULL
            CONSTRAINT DF_Licenses_IsDeleted
            DEFAULT 0,

        DeletedAt datetime2(7) NULL,

        CreatedAt datetime2(7) NOT NULL
            CONSTRAINT DF_Licenses_CreatedAt
            DEFAULT SYSUTCDATETIME(),

        UpdatedAt datetime2(7) NULL,

        RowVersion rowversion,

        CONSTRAINT PK_Licenses
            PRIMARY KEY CLUSTERED
            (
                LicenseID
            ),

        CONSTRAINT FK_Licenses_Company
            FOREIGN KEY
            (
                CompanyID
            )
            REFERENCES dbo.Companies
            (
                CompanyID
            ),

        CONSTRAINT CK_Licenses_Edition
            CHECK
            (
                Edition IN
                (
                    'STARTER',
                    'PROFESSIONAL',
                    'ENTERPRISE',
                    'ULTIMATE'
                )
            )
    );

END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Licenses_Company'
      AND object_id = OBJECT_ID('lic.Licenses')
)
BEGIN

    CREATE NONCLUSTERED INDEX IX_Licenses_Company
    ON lic.Licenses
    (
        CompanyID,
        ExpiryDate
    )
    WHERE IsDeleted = 0;

END;
GO

-- ============================================================================
-- SECTION 6
-- LICENSE MODULES
-- ============================================================================

IF OBJECT_ID('lic.LicenseModules','U') IS NULL
BEGIN

    CREATE TABLE lic.LicenseModules
    (
        LicenseModuleID bigint IDENTITY(1,1) NOT NULL,

        LicenseID uniqueidentifier NOT NULL,

        ModuleCode nvarchar(50) NOT NULL,

        IsEnabled bit NOT NULL
            DEFAULT 1,

        CreatedAt datetime2(7) NOT NULL
            DEFAULT SYSUTCDATETIME(),

        RowVersion rowversion,

        CONSTRAINT PK_LicenseModules
            PRIMARY KEY CLUSTERED
            (
                LicenseModuleID
            ),

        CONSTRAINT UQ_LicenseModules
            UNIQUE
            (
                LicenseID,
                ModuleCode
            ),

        CONSTRAINT FK_LicenseModules_License
            FOREIGN KEY
            (
                LicenseID
            )
            REFERENCES lic.Licenses
            (
                LicenseID
            )
    );

END;
GO

-- ============================================================================
-- SECTION 7
-- DONGLE BINDINGS
-- ============================================================================

IF OBJECT_ID('lic.DongleBindings','U') IS NULL
BEGIN

    CREATE TABLE lic.DongleBindings
    (
        BindingID uniqueidentifier NOT NULL
            DEFAULT NEWID(),

        LicenseID uniqueidentifier NOT NULL,

        HardwareID nvarchar(500) NOT NULL,

        DeviceName nvarchar(250) NULL,

        FirstSeen DATETIME2(7),

        LastSeen datetime2(7) NULL,

        IsActive bit NOT NULL
            DEFAULT 1,

        CreatedAt datetime2(7) NOT NULL
            DEFAULT SYSUTCDATETIME(),

        RowVersion rowversion,

        CONSTRAINT PK_DongleBindings
            PRIMARY KEY CLUSTERED
            (
                BindingID
            ),

        CONSTRAINT UQ_DongleBindings_Hardware
            UNIQUE
            (
                HardwareID
            ),

        CONSTRAINT FK_DongleBindings_License
            FOREIGN KEY
            (
                LicenseID
            )
            REFERENCES lic.Licenses
            (
                LicenseID
            )
    );

END;
GO

-- ============================================================================
-- SECTION 8
-- BACKUP HISTORY
-- ============================================================================

IF OBJECT_ID('ops.BackupHistory','U') IS NULL
BEGIN

    CREATE TABLE ops.BackupHistory
    (
        BackupID bigint IDENTITY(1,1) NOT NULL,

        BackupDateUTC datetime2(7) NOT NULL
            DEFAULT SYSUTCDATETIME(),

        BackupType nvarchar(20) NOT NULL,

        BackupPath nvarchar(500) NOT NULL,

        BackupSizeMB decimal(18,2) NULL,

        DatabaseName NVARCHAR(128),

        IsSuccessful bit NOT NULL
            DEFAULT 1,

        ErrorMessage nvarchar(max) NULL,

        RowVersion rowversion,

        CONSTRAINT PK_BackupHistory
            PRIMARY KEY CLUSTERED
            (
                BackupID
            ),

        CONSTRAINT CK_BackupHistory_Type
            CHECK
            (
                BackupType IN
                (
                    'FULL',
                    'DIFF',
                    'LOG'
                )
            )
    );

END;
GO

-- ============================================================================
-- SECTION 9
-- SYSTEM HEALTH
-- ============================================================================

IF OBJECT_ID('ops.SystemHealth','U') IS NULL
BEGIN

    CREATE TABLE ops.SystemHealth
    (
        HealthID bigint IDENTITY(1,1) NOT NULL,

        CaptureTimeUTC datetime2(7) NOT NULL
            DEFAULT SYSUTCDATETIME(),

        CPUPercent DECIMAL(5,2),

        MemoryPercent DECIMAL(5,2),

        DatabaseSizeMB decimal(18,2) NULL,

        ActiveUsers int NULL,

        LastBackupDate datetime2(7) NULL,

        WarningCount int NOT NULL
            DEFAULT 0,

        ErrorCount int NOT NULL
            DEFAULT 0,

        Notes nvarchar(2000) NULL,

        RowVersion rowversion,

        CONSTRAINT PK_SystemHealth
            PRIMARY KEY CLUSTERED
            (
                HealthID
            )
    );

END;
GO

-- ============================================================================
-- SECTION 10
-- AUDIT RETENTION POLICY
-- ============================================================================

IF OBJECT_ID('aud.AuditRetentionPolicy','U') IS NULL
BEGIN

    CREATE TABLE aud.AuditRetentionPolicy
    (
        PolicyID int IDENTITY(1,1) NOT NULL,

        TableName nvarchar(128) NOT NULL,

        RetentionDays int NOT NULL,

        ArchiveAfterDays int NULL,

        IsActive bit NOT NULL
            DEFAULT 1,

        CreatedAt datetime2(7) NOT NULL
            DEFAULT SYSUTCDATETIME(),

        RowVersion rowversion,

        PurgeEnabled BIT,

        CONSTRAINT PK_AuditRetentionPolicy
            PRIMARY KEY CLUSTERED
            (
                PolicyID
            ),

        CONSTRAINT UQ_AuditRetentionPolicy
            UNIQUE
            (
                TableName
            )
    );

END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM aud.AuditRetentionPolicy
)
BEGIN

    INSERT INTO aud.AuditRetentionPolicy
    (
        TableName,
        RetentionDays,
        ArchiveAfterDays
    )
    VALUES
    ('MasterAuditLog',3650,1825),
    ('LoginHistory',1095,730);

END;
GO

-- ============================================================================
-- SECTION 11
-- MASTER AUDIT LOG
-- ============================================================================

IF OBJECT_ID('aud.MasterAuditLog','U') IS NULL
BEGIN

    CREATE TABLE aud.MasterAuditLog
    (
        AuditID bigint IDENTITY(1,1) NOT NULL,

        TableName nvarchar(128) NOT NULL,

        RecordID nvarchar(100) NOT NULL,

        ActionType nvarchar(20) NOT NULL,

        OldValues nvarchar(max) NULL,

        NewValues nvarchar(max) NULL,

        ChangedBy uniqueidentifier NULL,

        ChangedAtUTC datetime2(7) NOT NULL
            CONSTRAINT DF_MasterAuditLog_ChangedAt
            DEFAULT SYSUTCDATETIME(),

        ApplicationName nvarchar(100) NULL,

        SessionID nvarchar(100) NULL,

        IPAddress nvarchar(50) NULL,

        ChangedFields NVARCHAR(MAX),

        RowVersion rowversion,

        CONSTRAINT PK_MasterAuditLog
            PRIMARY KEY CLUSTERED
            (
                AuditID
            ),

        CONSTRAINT CK_MasterAuditLog_Action
            CHECK
            (
                ActionType IN
                (
                    'INSERT',
                    'UPDATE',
                    'DELETE'
                )
            )
    );

END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_MasterAuditLog_Table_Date'
      AND object_id = OBJECT_ID('aud.MasterAuditLog')
)
BEGIN

    CREATE NONCLUSTERED INDEX IX_MasterAuditLog_Table_Date
    ON aud.MasterAuditLog
    (
        TableName,
        ChangedAtUTC DESC
    );

END;
GO

-- ============================================================================
-- SECTION 12
-- AUDIT PROCEDURE
-- ============================================================================

CREATE OR ALTER PROCEDURE aud.sp_WriteAuditLog
(
    @TableName nvarchar(128),
    @RecordID nvarchar(100),
    @ActionType nvarchar(20),
    @OldValues nvarchar(max) = NULL,
    @NewValues nvarchar(max) = NULL,
    @ChangedBy uniqueidentifier = NULL,
    @ApplicationName nvarchar(100) = NULL,
    @SessionID nvarchar(100) = NULL,
    @IPAddress nvarchar(50) = NULL
)
AS
BEGIN

    SET NOCOUNT ON;

    INSERT INTO aud.MasterAuditLog
    (
        TableName,
        RecordID,
        ActionType,
        OldValues,
        NewValues,
        ChangedBy,
        ApplicationName,
        SessionID,
        IPAddress
    )
    VALUES
    (
        @TableName,
        @RecordID,
        @ActionType,
        @OldValues,
        @NewValues,
        @ChangedBy,
        @ApplicationName,
        @SessionID,
        @IPAddress
    );

END;
GO

-- ============================================================================
-- SECTION 13
-- COMPANIES AUDIT TRIGGER
-- ============================================================================

CREATE OR ALTER TRIGGER dbo.trg_Companies_Audit
ON dbo.Companies
AFTER INSERT, UPDATE
AS
BEGIN

    SET NOCOUNT ON;

    INSERT INTO aud.MasterAuditLog
    (
        TableName,
        RecordID,
        ActionType,
        NewValues
    )
    SELECT
        'Companies',
        CAST(i.CompanyID AS nvarchar(100)),
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM deleted d
                WHERE d.CompanyID = i.CompanyID
            )
            THEN 'UPDATE'
            ELSE 'INSERT'
        END,
        (
            SELECT
                i.CompanyCode,
                i.CompanyNameAR,
                i.CompanyNameEN,
                i.TaxNumber
            FOR JSON PATH,
            WITHOUT_ARRAY_WRAPPER
        )
    FROM inserted i;

END;
GO

-- ============================================================================
-- SECTION 14
-- SYSTEM HEALTH PROCEDURE
-- ============================================================================

CREATE OR ALTER PROCEDURE ops.sp_SystemHealthCheck
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @DatabaseSizeMB decimal(18,2);

    SELECT
        @DatabaseSizeMB =
        SUM(size) * 8.0 / 1024
    FROM sys.database_files;

    INSERT INTO ops.SystemHealth
    (
        DatabaseName,
        DatabaseSizeMB,
        ActiveUsers
    )
    SELECT
        DB_NAME(),
        @DatabaseSizeMB,
        (
            SELECT COUNT(*)
            FROM sys.dm_exec_sessions
            WHERE is_user_process = 1
        );

END;
GO

-- ============================================================================
-- SECTION 15
-- RECORD BACKUP
-- ============================================================================

CREATE OR ALTER PROCEDURE ops.sp_RecordBackup
(
    @BackupType nvarchar(20),
    @BackupPath nvarchar(500),
    @BackupSizeMB decimal(18,2),
    @IsSuccessful bit,
    @ErrorMessage nvarchar(max) = NULL
)
AS
BEGIN

    INSERT INTO ops.BackupHistory
    (
        BackupType,
        BackupPath,
        BackupSizeMB,
        IsSuccessful,
        ErrorMessage
    )
    VALUES
    (
        @BackupType,
        @BackupPath,
        @BackupSizeMB,
        @IsSuccessful,
        @ErrorMessage
    );

END;
GO

-- ============================================================================
-- SECTION 16
-- DATABASE REGISTRY
-- ============================================================================

IF OBJECT_ID('ops.DatabaseRegistry','U') IS NULL
BEGIN

    CREATE TABLE ops.DatabaseRegistry
    (
        RegistryID bigint IDENTITY(1,1) NOT NULL,

        CompanyID uniqueidentifier NOT NULL,

        FiscalYearID bigint NULL,

        DatabaseName nvarchar(128) NOT NULL,

        DatabaseType nvarchar(20) NOT NULL,

        DatabaseStatus nvarchar(20) NOT NULL,

        DatabaseVersion nvarchar(50) NOT NULL,

        PhysicalPath NVARCHAR(500),

        CreatedAtUTC datetime2(7) NOT NULL
            CONSTRAINT DF_DatabaseRegistry_CreatedAt
            DEFAULT SYSUTCDATETIME(),

        LastVerifiedAtUTC datetime2(7) NULL,

        Notes nvarchar(2000) NULL,

        RowVersion rowversion,

        CONSTRAINT PK_DatabaseRegistry
            PRIMARY KEY CLUSTERED
            (
                RegistryID
            ),

        CONSTRAINT UQ_DatabaseRegistry_Name
            UNIQUE
            (
                DatabaseName
            ),

        CONSTRAINT FK_DatabaseRegistry_Company
            FOREIGN KEY
            (
                CompanyID
            )
            REFERENCES dbo.Companies
            (
                CompanyID
            ),

        CONSTRAINT CK_DatabaseRegistry_Type
            CHECK
            (
                DatabaseType IN
                (
                    'MST',
                    'FISCAL'
                )
            ),

        CONSTRAINT CK_DatabaseRegistry_Status
            CHECK
            (
                DatabaseStatus IN
                (
                    'ACTIVE',
                    'ARCHIVED',
                    'OFFLINE'
                )
            )
    );

END;
GO

-- ============================================================================
-- SECTION 17
-- CREATE FISCAL YEAR
-- ============================================================================

CREATE OR ALTER PROCEDURE ops.sp_CreateFiscalYear
(
      @CompanyID uniqueidentifier
    , @FiscalYear int
    , @CreatedBy uniqueidentifier = NULL
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CompanyCode nvarchar(50);
    DECLARE @DatabaseName nvarchar(128);

    BEGIN TRY

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Companies
            WHERE CompanyID = @CompanyID
              AND IsDeleted = 0
        )
        BEGIN
            THROW 50001,
                  N'Company does not exist.',
                  1;
        END;

        SELECT
            @CompanyCode = CompanyCode
        FROM dbo.Companies
        WHERE CompanyID = @CompanyID;

        SET @DatabaseName =
            @CompanyCode + '_' +
            CAST(@FiscalYear AS nvarchar(4));

        IF EXISTS
        (
            SELECT 1
            FROM sys.databases
            WHERE name = @DatabaseName
        )
        BEGIN
            THROW 50002,
                  N'Fiscal year database already exists.',
                  1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.FiscalYears
            WHERE CompanyID = @CompanyID
              AND FiscalYear = @FiscalYear
        )
        BEGIN
            THROW 50003,
                  N'Fiscal year already registered.',
                  1;
        END;

        INSERT INTO dbo.FiscalYears
        (
              CompanyID
            , FiscalYear
            , DatabaseName
            , StartDate
            , EndDate
            , IsCurrent
        )
        VALUES
        (
              @CompanyID
            , @FiscalYear
            , @DatabaseName
            , DATEFROMPARTS(@FiscalYear,1,1)
            , DATEFROMPARTS(@FiscalYear,12,31)
            , 1
        );

        UPDATE dbo.FiscalYears
        SET IsCurrent = 0
        WHERE CompanyID = @CompanyID
          AND FiscalYear <> @FiscalYear;

        INSERT INTO ops.DatabaseRegistry
        (
              CompanyID
            , DatabaseName
            , DatabaseType
            , DatabaseStatus
            , DatabaseVersion
        )
        VALUES
        (
              @CompanyID
            , @DatabaseName
            , 'FISCAL'
            , 'ACTIVE'
            , '10.0.0'
        );

        EXEC aud.sp_WriteAuditLog
             @TableName = 'FiscalYears',
             @RecordID = @DatabaseName,
             @ActionType = 'INSERT';

    END TRY

    BEGIN CATCH

        DECLARE @Msg nvarchar(4000);

        SET @Msg = ERROR_MESSAGE();

        THROW 50099,
              @Msg,
              1;

    END CATCH

END;
GO

-- ============================================================================
-- SECTION 18
-- VALIDATE LICENSE
-- ============================================================================

CREATE OR ALTER PROCEDURE lic.sp_ValidateLicense
(
      @LicenseKey nvarchar(500)
)
AS
BEGIN

    SET NOCOUNT ON;

    SELECT TOP (1)
          LicenseID
        , CompanyID
        , Edition
        , MaxUsers
        , MaxCompanies
        , MaxDevices
        , ExpiryDate
        , IsActive
    FROM lic.Licenses
    WHERE LicenseKeyHash = @Hash
      AND IsActive = 1
      AND IsDeleted = 0
      AND ExpiryDate >= CAST(SYSUTCDATETIME() AS date);

END;
GO

-- ============================================================================
-- SECTION 19
-- REGISTER DONGLE
-- ============================================================================

CREATE OR ALTER PROCEDURE lic.sp_RegisterDongle
(
      @LicenseID uniqueidentifier
    , @HardwareID nvarchar(500)
    , @DeviceName nvarchar(250)
)
AS
BEGIN

    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM lic.DongleBindings
        WHERE LicenseID = @LicenseID
          AND HardwareID = @HardwareID
    )
    BEGIN

        INSERT INTO lic.DongleBindings
        (
              LicenseID
            , HardwareID
            , DeviceName
        )
        VALUES
        (
              @LicenseID
            , @HardwareID
            , @DeviceName
        );

    END;

END;
GO


-- ============================================================================
-- DEFAULT SETTINGS
-- ============================================================================

IF NOT EXISTS
(
    SELECT 1
    FROM cfg.SystemSettings
    WHERE SettingKey = 'ApplicationName'
)
BEGIN

    INSERT INTO cfg.SystemSettings
    (
        SettingCategory,
        SettingKey,
        SettingValue,
        IsSystem
    )
    VALUES
    ('GENERAL','ApplicationName','SHOUTECH ERP',1),
    ('GENERAL','Version','10.0.0',1),
    ('DATABASE','BackupRetentionDays','365',1),
    ('SECURITY','PasswordMinLength','8',1),
    ('SECURITY','MaxLoginAttempts','5',1),
    ('SECURITY','SessionTimeoutMinutes','480',1);

END
GO