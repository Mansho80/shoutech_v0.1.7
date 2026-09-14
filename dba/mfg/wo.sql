-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/mfg/wo.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Work Orders (أوامر التصنيع)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Work Orders (mfg.WO*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'mfg.WorkOrders', N'U') IS NULL
    BEGIN
        CREATE TABLE mfg.WorkOrders (
            WorkOrderID         BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NOT NULL,
            WONumber            VARCHAR(40)  NOT NULL,
            ProductID           INT NOT NULL,
            BOMHeaderID         INT NULL,
            RoutingID           INT NULL,
            PlannedQty          DECIMAL(18,4) NOT NULL,
            CompletedQty        DECIMAL(18,4) NOT NULL DEFAULT 0,
            ScrapQty            DECIMAL(18,4) NOT NULL DEFAULT 0,
            PlannedStart        DATETIME2(7) NULL,
            PlannedEnd          DATETIME2(7) NULL,
            ActualStart         DATETIME2(7) NULL,
            ActualEnd           DATETIME2(7) NULL,
            Status              VARCHAR(20) NOT NULL DEFAULT 'PLANNED', -- PLANNED, RELEASED, INPROGRESS, COMPLETED, CANCELLED
            Priority            TINYINT NOT NULL DEFAULT 5,
            WarehouseID         INT NULL,
            Notes               NVARCHAR(500) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_mfg_WorkOrders PRIMARY KEY CLUSTERED (WorkOrderID),
            CONSTRAINT UQ_mfg_WorkOrders UNIQUE (TenantID, CompanyID, WONumber),
            CONSTRAINT CK_mfg_WorkOrders_Qty CHECK (PlannedQty > 0)
        );
        CREATE NONCLUSTERED INDEX IX_mfg_WorkOrders_Status
            ON mfg.WorkOrders (TenantID, CompanyID, Status) WHERE IsDeleted = 0;
    END;

    IF OBJECT_ID(N'mfg.WorkOrderMaterials', N'U') IS NULL
    BEGIN
        CREATE TABLE mfg.WorkOrderMaterials (
            WOMaterialID        BIGINT IDENTITY(1,1) NOT NULL,
            WorkOrderID         BIGINT NOT NULL,
            ProductID           INT NOT NULL,
            RequiredQty         DECIMAL(18,6) NOT NULL,
            IssuedQty           DECIMAL(18,6) NOT NULL DEFAULT 0,
            WarehouseID         INT NULL,
            CONSTRAINT PK_mfg_WorkOrderMaterials PRIMARY KEY CLUSTERED (WOMaterialID),
            CONSTRAINT FK_mfg_WorkOrderMaterials_WO FOREIGN KEY (WorkOrderID) REFERENCES mfg.WorkOrders(WorkOrderID) ON DELETE CASCADE
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Work Orders created successfully (mfg.WO*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] wo.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
