-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/crm/rep.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Sales Representatives · Targets · Handheld Routes (مندوب المبيعات)
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'crm')
    EXEC('CREATE SCHEMA [crm] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Sales Representatives (crm.Rep*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'crm.SalesRepGroups', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.SalesRepGroups (
            SalesRepGroupID     INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            GroupCode           VARCHAR(20)  NOT NULL,
            GroupNameAR         NVARCHAR(100) NOT NULL,
            GroupNameEN         VARCHAR(100) NULL,
            CommissionPercent   DECIMAL(9,4) NOT NULL DEFAULT 0,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_crm_SalesRepGroups PRIMARY KEY CLUSTERED (SalesRepGroupID),
            CONSTRAINT UQ_crm_SalesRepGroups UNIQUE (TenantID, CompanyID, GroupCode)
        );
    END;

    IF OBJECT_ID(N'crm.SalesReps', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.SalesReps (
            SalesRepID          INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NULL,
            SalesRepCode        VARCHAR(30)  NOT NULL,
            FullNameAR          NVARCHAR(150) NOT NULL,
            FullNameEN          VARCHAR(150) NULL,
            SalesRepGroupID     INT NULL,
            EmployeeID          INT NULL,
            UserID              INT NULL,
            Mobile              VARCHAR(30) NULL,
            Email               VARCHAR(120) NULL,
            CommissionPercent   DECIMAL(9,4) NOT NULL DEFAULT 0,
            CreditLimit         DECIMAL(18,4) NOT NULL DEFAULT 0,
            TerritoryAR         NVARCHAR(150) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_crm_SalesReps PRIMARY KEY CLUSTERED (SalesRepID),
            CONSTRAINT UQ_crm_SalesReps UNIQUE (TenantID, CompanyID, SalesRepCode),
            CONSTRAINT FK_crm_SalesReps_Group FOREIGN KEY (SalesRepGroupID) REFERENCES crm.SalesRepGroups(SalesRepGroupID)
        );
        CREATE NONCLUSTERED INDEX IX_crm_SalesReps_Active
            ON crm.SalesReps (TenantID, CompanyID, IsActive) WHERE IsDeleted = 0;
    END;

    IF OBJECT_ID(N'crm.SalesRepTargets', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.SalesRepTargets (
            TargetID            INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            SalesRepID          INT NOT NULL,
            PeriodYear          INT NOT NULL,
            PeriodMonth         TINYINT NULL,
            TargetAmount        DECIMAL(18,4) NOT NULL,
            TargetQty           DECIMAL(18,4) NULL,
            AchievedAmount      DECIMAL(18,4) NOT NULL DEFAULT 0,
            AchievedQty         DECIMAL(18,4) NOT NULL DEFAULT 0,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            Notes               NVARCHAR(300) NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_crm_SalesRepTargets PRIMARY KEY CLUSTERED (TargetID),
            CONSTRAINT FK_crm_SalesRepTargets_Rep FOREIGN KEY (SalesRepID) REFERENCES crm.SalesReps(SalesRepID),
            CONSTRAINT UQ_crm_SalesRepTargets UNIQUE (TenantID, CompanyID, SalesRepID, PeriodYear, PeriodMonth)
        );
    END;

    IF OBJECT_ID(N'crm.HandheldDevices', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.HandheldDevices (
            DeviceID            INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            DeviceCode          VARCHAR(40)  NOT NULL,
            DeviceNameAR        NVARCHAR(100) NOT NULL,
            SalesRepID          INT NULL,
            SerialNo            VARCHAR(80) NULL,
            LastSyncAt          DATETIME2(7) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_crm_HandheldDevices PRIMARY KEY CLUSTERED (DeviceID),
            CONSTRAINT UQ_crm_HandheldDevices UNIQUE (TenantID, CompanyID, DeviceCode),
            CONSTRAINT FK_crm_HandheldDevices_Rep FOREIGN KEY (SalesRepID) REFERENCES crm.SalesReps(SalesRepID)
        );
    END;

    IF OBJECT_ID(N'crm.HandheldRoutes', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.HandheldRoutes (
            RouteID             INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            RouteCode           VARCHAR(30)  NOT NULL,
            RouteNameAR         NVARCHAR(120) NOT NULL,
            SalesRepID          INT NOT NULL,
            DeviceID            INT NULL,
            DayOfWeek           TINYINT NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_crm_HandheldRoutes PRIMARY KEY CLUSTERED (RouteID),
            CONSTRAINT UQ_crm_HandheldRoutes UNIQUE (TenantID, CompanyID, RouteCode),
            CONSTRAINT FK_crm_HandheldRoutes_Rep FOREIGN KEY (SalesRepID) REFERENCES crm.SalesReps(SalesRepID)
        );
    END;

    IF OBJECT_ID(N'crm.RouteCustomers', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.RouteCustomers (
            RouteCustomerID     INT IDENTITY(1,1) NOT NULL,
            RouteID             INT NOT NULL,
            CustomerID          INT NOT NULL,
            VisitOrder          INT NOT NULL DEFAULT 0,
            CONSTRAINT PK_crm_RouteCustomers PRIMARY KEY CLUSTERED (RouteCustomerID),
            CONSTRAINT FK_crm_RouteCustomers_Route FOREIGN KEY (RouteID) REFERENCES crm.HandheldRoutes(RouteID) ON DELETE CASCADE,
            CONSTRAINT UQ_crm_RouteCustomers UNIQUE (RouteID, CustomerID)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Sales Representatives module created (crm.Rep*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] rep.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
