-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/mfg/qual.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Quality Control (مراقبة الجودة)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Quality Control (mfg.Qual*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'mfg.QualityPlans', N'U') IS NULL
    BEGIN
        CREATE TABLE mfg.QualityPlans (
            QualityPlanID       INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            PlanCode            VARCHAR(30)  NOT NULL,
            PlanNameAR          NVARCHAR(150) NOT NULL,
            PlanNameEN          VARCHAR(150) NULL,
            ProductID           INT NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_mfg_QualityPlans PRIMARY KEY CLUSTERED (QualityPlanID),
            CONSTRAINT UQ_mfg_QualityPlans UNIQUE (TenantID, CompanyID, PlanCode)
        );
    END;

    IF OBJECT_ID(N'mfg.QualityInspections', N'U') IS NULL
    BEGIN
        CREATE TABLE mfg.QualityInspections (
            InspectionID        BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            WorkOrderID         BIGINT NULL,
            ProductID           INT NOT NULL,
            InspectionDate      DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            InspectedQty        DECIMAL(18,4) NOT NULL,
            PassedQty           DECIMAL(18,4) NOT NULL DEFAULT 0,
            FailedQty           DECIMAL(18,4) NOT NULL DEFAULT 0,
            Result              VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, PASSED, FAILED, PARTIAL
            InspectorUserID     INT NULL,
            Notes               NVARCHAR(500) NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_mfg_QualityInspections PRIMARY KEY CLUSTERED (InspectionID)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Quality Control created successfully (mfg.Qual*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] qual.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
