-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/fin/fin_asst.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Fixed Assets (الأصول الثابتة) — Depreciation & Tracking
-- GRADE: Enterprise Production Standard (Tier-1) — IAS 16 Compliant
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'fin')
    EXEC('CREATE SCHEMA [fin] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Fixed Assets (fin.Asset*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'fin.AssetCategories', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.AssetCategories (
            AssetCategoryID     INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            CategoryCode        VARCHAR(30)  NOT NULL,
            CategoryNameAR      NVARCHAR(120) NOT NULL,
            CategoryNameEN      VARCHAR(120) NULL,
            DepreciationMethod  VARCHAR(30) NOT NULL DEFAULT 'STRAIGHT_LINE', -- STRAIGHT_LINE, DECLINING, UNITS
            UsefulLifeYears     DECIMAL(9,2) NOT NULL DEFAULT 5,
            SalvagePercent      DECIMAL(9,4) NOT NULL DEFAULT 0,
            AssetAccountID      INT NULL,
            AccumDepAccountID   INT NULL,
            DepExpenseAccountID INT NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_AssetCategories PRIMARY KEY CLUSTERED (AssetCategoryID),
            CONSTRAINT UQ_fin_AssetCategories UNIQUE (TenantID, CompanyID, CategoryCode)
        );
    END;

    IF OBJECT_ID(N'fin.Assets', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.Assets (
            AssetID             INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NULL,
            AssetCode           VARCHAR(40)  NOT NULL,
            AssetNameAR         NVARCHAR(200) NOT NULL,
            AssetNameEN         VARCHAR(200) NULL,
            AssetCategoryID     INT NOT NULL,
            AcquisitionDate     DATE NOT NULL,
            AcquisitionCost     DECIMAL(18,4) NOT NULL,
            SalvageValue        DECIMAL(18,4) NOT NULL DEFAULT 0,
            UsefulLifeMonths    INT NOT NULL,
            DepreciationMethod  VARCHAR(30) NOT NULL DEFAULT 'STRAIGHT_LINE',
            AccumulatedDep      DECIMAL(18,4) NOT NULL DEFAULT 0,
            BookValue           DECIMAL(18,4) NOT NULL,
            Status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, DISPOSED, FULLY_DEP
            DisposalDate        DATE NULL,
            DisposalAmount      DECIMAL(18,4) NULL,
            LocationAR          NVARCHAR(150) NULL,
            SerialNo            VARCHAR(80) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_Assets PRIMARY KEY CLUSTERED (AssetID),
            CONSTRAINT UQ_fin_Assets UNIQUE (TenantID, CompanyID, AssetCode),
            CONSTRAINT FK_fin_Assets_Category FOREIGN KEY (AssetCategoryID) REFERENCES fin.AssetCategories(AssetCategoryID),
            CONSTRAINT CK_fin_Assets_Cost CHECK (AcquisitionCost >= 0)
        );
        CREATE NONCLUSTERED INDEX IX_fin_Assets_Status
            ON fin.Assets (TenantID, CompanyID, Status) WHERE IsDeleted = 0;
    END;

    IF OBJECT_ID(N'fin.DepreciationEntries', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.DepreciationEntries (
            DepreciationEntryID BIGINT IDENTITY(1,1) NOT NULL,
            AssetID             INT NOT NULL,
            PeriodYear          INT NOT NULL,
            PeriodMonth         TINYINT NOT NULL,
            DepreciationAmount  DECIMAL(18,4) NOT NULL,
            BookValueAfter      DECIMAL(18,4) NOT NULL,
            JournalHeaderID     BIGINT NULL,
            PostedAt            DATETIME2(7) NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            CONSTRAINT PK_fin_DepreciationEntries PRIMARY KEY CLUSTERED (DepreciationEntryID),
            CONSTRAINT FK_fin_DepreciationEntries_Asset FOREIGN KEY (AssetID) REFERENCES fin.Assets(AssetID),
            CONSTRAINT UQ_fin_DepreciationEntries UNIQUE (AssetID, PeriodYear, PeriodMonth)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Fixed Assets module created successfully (fin.Asset*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] fin_asst.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
