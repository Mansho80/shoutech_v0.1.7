-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/hr/leave.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Leave Management (الإجازات)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Leave Management (hr.Leave*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'hr.LeaveTypes', N'U') IS NULL
    BEGIN
        CREATE TABLE hr.LeaveTypes (
            LeaveTypeID         INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            LeaveTypeCode       VARCHAR(20)  NOT NULL,
            LeaveTypeNameAR     NVARCHAR(80) NOT NULL,
            LeaveTypeNameEN     VARCHAR(80) NULL,
            IsPaid              BIT NOT NULL DEFAULT 1,
            MaxDaysPerYear      DECIMAL(9,2) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_hr_LeaveTypes PRIMARY KEY CLUSTERED (LeaveTypeID),
            CONSTRAINT UQ_hr_LeaveTypes UNIQUE (TenantID, CompanyID, LeaveTypeCode)
        );
    END;

    IF OBJECT_ID(N'hr.LeaveRequests', N'U') IS NULL
    BEGIN
        CREATE TABLE hr.LeaveRequests (
            LeaveRequestID      BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            EmployeeID          INT NOT NULL,
            LeaveTypeID         INT NOT NULL,
            FromDate            DATE NOT NULL,
            ToDate              DATE NOT NULL,
            DaysCount           DECIMAL(9,2) NOT NULL,
            ReasonAR            NVARCHAR(300) NULL,
            Status              VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED, CANCELLED
            ApprovedBy          INT NULL,
            ApprovedAt          DATETIME2(7) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_hr_LeaveRequests PRIMARY KEY CLUSTERED (LeaveRequestID),
            CONSTRAINT FK_hr_LeaveRequests_Type FOREIGN KEY (LeaveTypeID) REFERENCES hr.LeaveTypes(LeaveTypeID),
            CONSTRAINT CK_hr_LeaveRequests_Dates CHECK (ToDate >= FromDate)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Leave Management created successfully (hr.Leave*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] leave.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
