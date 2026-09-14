-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/hr/att.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Attendance (الحضور والانصراف)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Attendance (hr.Att*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'hr.Attendance', N'U') IS NULL
    BEGIN
        CREATE TABLE hr.Attendance (
            AttendanceID        BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            EmployeeID          INT NOT NULL,
            AttendanceDate      DATE NOT NULL,
            CheckIn             DATETIME2(7) NULL,
            CheckOut            DATETIME2(7) NULL,
            WorkMinutes         INT NULL,
            OvertimeMinutes     INT NOT NULL DEFAULT 0,
            Status              VARCHAR(20) NOT NULL DEFAULT 'PRESENT', -- PRESENT, ABSENT, LATE, HALFDAY, HOLIDAY
            Source              VARCHAR(20) NOT NULL DEFAULT 'MANUAL', -- MANUAL, DEVICE, IMPORT
            Notes               NVARCHAR(300) NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_hr_Attendance PRIMARY KEY CLUSTERED (AttendanceID),
            CONSTRAINT UQ_hr_Attendance UNIQUE (TenantID, CompanyID, EmployeeID, AttendanceDate)
        );
        CREATE NONCLUSTERED INDEX IX_hr_Attendance_Date
            ON hr.Attendance (TenantID, CompanyID, AttendanceDate DESC);
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Attendance created successfully (hr.Att*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] att.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
