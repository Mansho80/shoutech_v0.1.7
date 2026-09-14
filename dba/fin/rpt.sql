-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/fin/rpt.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Financial Report Definitions (Excel-like flexible reports)
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'fin')
    EXEC('CREATE SCHEMA [fin] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Financial Report Catalog (fin.Rpt*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'fin.ReportDefinitions', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.ReportDefinitions (
            ReportDefID         INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            ReportCode          VARCHAR(50)  NOT NULL,
            ReportNameAR        NVARCHAR(150) NOT NULL,
            ReportNameEN        VARCHAR(150) NULL,
            ModuleCode          VARCHAR(40)  NOT NULL DEFAULT 'FIN',
            ReportType          VARCHAR(30)  NOT NULL DEFAULT 'GRID', -- GRID, PIVOT, CHART, STATEMENT
            LayoutJSON          NVARCHAR(MAX) NULL,          -- columns, widths, formulas (Excel-like)
            QueryTemplate       NVARCHAR(MAX) NULL,
            IsSystem            BIT NOT NULL DEFAULT 0,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedBy           INT NULL,
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_ReportDefinitions PRIMARY KEY CLUSTERED (ReportDefID),
            CONSTRAINT UQ_fin_ReportDefinitions UNIQUE (TenantID, CompanyID, ReportCode)
        );
    END;

    IF OBJECT_ID(N'fin.ReportColumns', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.ReportColumns (
            ReportColumnID      INT IDENTITY(1,1) NOT NULL,
            ReportDefID         INT NOT NULL,
            ColumnKey           VARCHAR(50)  NOT NULL,
            HeaderAR            NVARCHAR(100) NOT NULL,
            HeaderEN            VARCHAR(100) NULL,
            DataType            VARCHAR(20)  NOT NULL DEFAULT 'STRING',
            WidthPx             INT NOT NULL DEFAULT 120,
            IsVisible           BIT NOT NULL DEFAULT 1,
            IsEditable          BIT NOT NULL DEFAULT 0,
            Formula             NVARCHAR(500) NULL,            -- simple cell formulas
            DisplayOrder        INT NOT NULL DEFAULT 0,
            CONSTRAINT PK_fin_ReportColumns PRIMARY KEY CLUSTERED (ReportColumnID),
            CONSTRAINT FK_fin_ReportColumns_Def FOREIGN KEY (ReportDefID) REFERENCES fin.ReportDefinitions(ReportDefID) ON DELETE CASCADE,
            CONSTRAINT UQ_fin_ReportColumns UNIQUE (ReportDefID, ColumnKey)
        );
    END;

    IF OBJECT_ID(N'fin.SavedReports', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.SavedReports (
            SavedReportID       INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            ReportDefID         INT NOT NULL,
            SavedNameAR         NVARCHAR(150) NOT NULL,
            SavedNameEN         VARCHAR(150) NULL,
            LayoutJSON          NVARCHAR(MAX) NOT NULL,         -- user-customized columns/formulas
            FilterJSON          NVARCHAR(MAX) NULL,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_SavedReports PRIMARY KEY CLUSTERED (SavedReportID),
            CONSTRAINT FK_fin_SavedReports_Def FOREIGN KEY (ReportDefID) REFERENCES fin.ReportDefinitions(ReportDefID)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Financial Report Catalog created successfully (fin.Rpt*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] rpt.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
