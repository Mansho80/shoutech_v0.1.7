-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/mfg/bom.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Bill of Materials (قائمة المواد)
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'mfg')
    EXEC('CREATE SCHEMA [mfg] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building BOM (mfg.BOM*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'mfg.BOMHeaders', N'U') IS NULL
    BEGIN
        CREATE TABLE mfg.BOMHeaders (
            BOMHeaderID         INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BOMCode             VARCHAR(40)  NOT NULL,
            ProductID           INT NOT NULL,
            VersionNo           INT NOT NULL DEFAULT 1,
            BOMNameAR           NVARCHAR(150) NOT NULL,
            BOMNameEN           VARCHAR(150) NULL,
            BaseQty             DECIMAL(18,4) NOT NULL DEFAULT 1,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_mfg_BOMHeaders PRIMARY KEY CLUSTERED (BOMHeaderID),
            CONSTRAINT UQ_mfg_BOMHeaders UNIQUE (TenantID, CompanyID, BOMCode, VersionNo)
        );
    END;

    IF OBJECT_ID(N'mfg.BOMLines', N'U') IS NULL
    BEGIN
        CREATE TABLE mfg.BOMLines (
            BOMLineID           INT IDENTITY(1,1) NOT NULL,
            BOMHeaderID         INT NOT NULL,
            LineNumber          INT NOT NULL,
            ComponentProductID  INT NOT NULL,
            Qty                 DECIMAL(18,6) NOT NULL,
            ScrapPercent        DECIMAL(9,4) NOT NULL DEFAULT 0,
            WarehouseID         INT NULL,
            Notes               NVARCHAR(200) NULL,
            CONSTRAINT PK_mfg_BOMLines PRIMARY KEY CLUSTERED (BOMLineID),
            CONSTRAINT FK_mfg_BOMLines_Header FOREIGN KEY (BOMHeaderID) REFERENCES mfg.BOMHeaders(BOMHeaderID) ON DELETE CASCADE,
            CONSTRAINT CK_mfg_BOMLines_Qty CHECK (Qty > 0)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] BOM created successfully (mfg.BOM*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] bom.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
