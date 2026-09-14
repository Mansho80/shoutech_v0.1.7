-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/fin/inst.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Installments & Payment Plans (تقسيط المبالغ)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Installments (fin.Inst*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'fin.InstallmentPlans', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.InstallmentPlans (
            PlanID              BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            PlanNo              VARCHAR(40)  NOT NULL,
            PartnerType         VARCHAR(20)  NOT NULL, -- CUSTOMER, SUPPLIER
            PartnerID           INT NOT NULL,
            SourceDocType       VARCHAR(30)  NULL, -- SALES_INVOICE, SALES_ORDER, MANUAL
            SourceDocID         BIGINT NULL,
            TotalAmount         DECIMAL(18,4) NOT NULL,
            DownPayment         DECIMAL(18,4) NOT NULL DEFAULT 0,
            InstallmentCount    INT NOT NULL,
            StartDate           DATE NOT NULL,
            Frequency           VARCHAR(20) NOT NULL DEFAULT 'MONTHLY', -- WEEKLY, MONTHLY, QUARTERLY
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            Status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, COMPLETED, CANCELLED, DEFAULTED
            Notes               NVARCHAR(300) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_InstallmentPlans PRIMARY KEY CLUSTERED (PlanID),
            CONSTRAINT UQ_fin_InstallmentPlans UNIQUE (TenantID, CompanyID, PlanNo),
            CONSTRAINT CK_fin_InstallmentPlans_Count CHECK (InstallmentCount > 0)
        );
    END;

    IF OBJECT_ID(N'fin.InstallmentSchedule', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.InstallmentSchedule (
            ScheduleID          BIGINT IDENTITY(1,1) NOT NULL,
            PlanID              BIGINT NOT NULL,
            InstallmentNo       INT NOT NULL,
            DueDate             DATE NOT NULL,
            Amount              DECIMAL(18,4) NOT NULL,
            PaidAmount          DECIMAL(18,4) NOT NULL DEFAULT 0,
            Status              VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, PARTIAL, PAID, OVERDUE
            PaidDate            DATE NULL,
            PaymentHeaderID     BIGINT NULL,
            CONSTRAINT PK_fin_InstallmentSchedule PRIMARY KEY CLUSTERED (ScheduleID),
            CONSTRAINT FK_fin_InstallmentSchedule_Plan FOREIGN KEY (PlanID) REFERENCES fin.InstallmentPlans(PlanID) ON DELETE CASCADE,
            CONSTRAINT UQ_fin_InstallmentSchedule UNIQUE (PlanID, InstallmentNo)
        );
        CREATE NONCLUSTERED INDEX IX_fin_InstallmentSchedule_Due
            ON fin.InstallmentSchedule (DueDate, Status) WHERE Status IN ('PENDING','PARTIAL','OVERDUE');
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Installments created (fin.Inst*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] inst.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
