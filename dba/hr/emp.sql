-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/hr/emp.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Employees Master (الموظفين)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Employees (hr.Emp*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'hr.Employees', N'U') IS NULL
    BEGIN
        CREATE TABLE hr.Employees (
            EmployeeID          INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NULL,
            EmployeeCode        VARCHAR(30)  NOT NULL,
            FullNameAR          NVARCHAR(150) NOT NULL,
            FullNameEN          VARCHAR(150) NULL,
            NationalID          VARCHAR(30) NULL,
            BirthDate           DATE NULL,
            Gender              CHAR(1) NULL, -- M, F
            HireDate            DATE NOT NULL,
            TerminationDate     DATE NULL,
            DepartmentID        INT NULL,
            JobTitleID          INT NULL,
            ManagerID           INT NULL,
            BasicSalary         DECIMAL(18,4) NOT NULL DEFAULT 0,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            BankAccountIBAN     VARCHAR(50) NULL,
            Email               VARCHAR(120) NULL,
            Mobile              VARCHAR(30) NULL,
            Status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, ONLEAVE, TERMINATED
            UserID              INT NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_hr_Employees PRIMARY KEY CLUSTERED (EmployeeID),
            CONSTRAINT UQ_hr_Employees_Code UNIQUE (TenantID, CompanyID, EmployeeCode)
        );
        CREATE NONCLUSTERED INDEX IX_hr_Employees_Status
            ON hr.Employees (TenantID, CompanyID, Status) WHERE IsDeleted = 0;
    END;

    IF OBJECT_ID(N'hr.Departments', N'U') IS NULL
    BEGIN
        CREATE TABLE hr.Departments (
            DepartmentID        INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            DeptCode            VARCHAR(20)  NOT NULL,
            DeptNameAR          NVARCHAR(100) NOT NULL,
            DeptNameEN          VARCHAR(100) NULL,
            ParentDeptID        INT NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_hr_Departments PRIMARY KEY CLUSTERED (DepartmentID),
            CONSTRAINT UQ_hr_Departments UNIQUE (TenantID, CompanyID, DeptCode)
        );
    END;

    IF OBJECT_ID(N'hr.JobTitles', N'U') IS NULL
    BEGIN
        CREATE TABLE hr.JobTitles (
            JobTitleID          INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            TitleCode           VARCHAR(20)  NOT NULL,
            TitleNameAR         NVARCHAR(100) NOT NULL,
            TitleNameEN         VARCHAR(100) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_hr_JobTitles PRIMARY KEY CLUSTERED (JobTitleID),
            CONSTRAINT UQ_hr_JobTitles UNIQUE (TenantID, CompanyID, TitleCode)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Employees master created successfully (hr.Emp*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] emp.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
