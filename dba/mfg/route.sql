-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/mfg/route.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Routing / Work Centers (مسارات التصنيع)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Routing (mfg.Route*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'mfg.WorkCenters', N'U') IS NULL
    BEGIN
        CREATE TABLE mfg.WorkCenters (
            WorkCenterID        INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            WorkCenterCode      VARCHAR(30)  NOT NULL,
            WorkCenterNameAR    NVARCHAR(120) NOT NULL,
            WorkCenterNameEN    VARCHAR(120) NULL,
            CostPerHour         DECIMAL(18,4) NOT NULL DEFAULT 0,
            CapacityPerDay      DECIMAL(18,4) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_mfg_WorkCenters PRIMARY KEY CLUSTERED (WorkCenterID),
            CONSTRAINT UQ_mfg_WorkCenters UNIQUE (TenantID, CompanyID, WorkCenterCode)
        );
    END;

    IF OBJECT_ID(N'mfg.Routings', N'U') IS NULL
    BEGIN
        CREATE TABLE mfg.Routings (
            RoutingID           INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            RoutingCode         VARCHAR(40)  NOT NULL,
            ProductID           INT NOT NULL,
            RoutingNameAR       NVARCHAR(150) NOT NULL,
            VersionNo           INT NOT NULL DEFAULT 1,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_mfg_Routings PRIMARY KEY CLUSTERED (RoutingID),
            CONSTRAINT UQ_mfg_Routings UNIQUE (TenantID, CompanyID, RoutingCode, VersionNo)
        );
    END;

    IF OBJECT_ID(N'mfg.RoutingOperations', N'U') IS NULL
    BEGIN
        CREATE TABLE mfg.RoutingOperations (
            RoutingOperationID  INT IDENTITY(1,1) NOT NULL,
            RoutingID           INT NOT NULL,
            OperationSeq        INT NOT NULL,
            WorkCenterID        INT NOT NULL,
            OperationNameAR     NVARCHAR(120) NOT NULL,
            SetupTimeMin        DECIMAL(9,2) NOT NULL DEFAULT 0,
            RunTimeMin          DECIMAL(9,2) NOT NULL DEFAULT 0,
            CONSTRAINT PK_mfg_RoutingOperations PRIMARY KEY CLUSTERED (RoutingOperationID),
            CONSTRAINT FK_mfg_RoutingOperations_Routing FOREIGN KEY (RoutingID) REFERENCES mfg.Routings(RoutingID) ON DELETE CASCADE,
            CONSTRAINT FK_mfg_RoutingOperations_WC FOREIGN KEY (WorkCenterID) REFERENCES mfg.WorkCenters(WorkCenterID)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Routing created successfully (mfg.Route*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] route.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
