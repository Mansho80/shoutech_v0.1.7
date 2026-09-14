-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/hr/payr.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Payroll (الرواتب)
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'hr')
    EXEC('CREATE SCHEMA [hr] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Payroll (hr.Payr*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'hr.PayrollRuns', N'U') IS NULL
    BEGIN
        CREATE TABLE hr.PayrollRuns (
            PayrollRunID        BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            RunCode             VARCHAR(30)  NOT NULL,
            PeriodYear          INT NOT NULL,
            PeriodMonth         TINYINT NOT NULL,
            Status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT', -- DRAFT, CALCULATED, APPROVED, POSTED
            TotalGross          DECIMAL(18,4) NOT NULL DEFAULT 0,
            TotalDeductions     DECIMAL(18,4) NOT NULL DEFAULT 0,
            TotalNet            DECIMAL(18,4) NOT NULL DEFAULT 0,
            JournalHeaderID     BIGINT NULL,
            PostedAt            DATETIME2(7) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_hr_PayrollRuns PRIMARY KEY CLUSTERED (PayrollRunID),
            CONSTRAINT UQ_hr_PayrollRuns UNIQUE (TenantID, CompanyID, PeriodYear, PeriodMonth)
        );
    END;

    IF OBJECT_ID(N'hr.PayrollLines', N'U') IS NULL
    BEGIN
        CREATE TABLE hr.PayrollLines (
            PayrollLineID       BIGINT IDENTITY(1,1) NOT NULL,
            PayrollRunID        BIGINT NOT NULL,
            EmployeeID          INT NOT NULL,
            BasicSalary         DECIMAL(18,4) NOT NULL DEFAULT 0,
            Allowances          DECIMAL(18,4) NOT NULL DEFAULT 0,
            OvertimeAmount      DECIMAL(18,4) NOT NULL DEFAULT 0,
            Deductions          DECIMAL(18,4) NOT NULL DEFAULT 0,
            TaxAmount           DECIMAL(18,4) NOT NULL DEFAULT 0,
            NetSalary           DECIMAL(18,4) NOT NULL,
            CONSTRAINT PK_hr_PayrollLines PRIMARY KEY CLUSTERED (PayrollLineID),
            CONSTRAINT FK_hr_PayrollLines_Run FOREIGN KEY (PayrollRunID) REFERENCES hr.PayrollRuns(PayrollRunID) ON DELETE CASCADE,
            CONSTRAINT UQ_hr_PayrollLines UNIQUE (PayrollRunID, EmployeeID)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Payroll created successfully (hr.Payr*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] payr.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
