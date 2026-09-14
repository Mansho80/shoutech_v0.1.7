-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/fin/chq.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Checks & Notes (الأوراق المالية — شيكات قبض/دفع)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Checks & Notes (fin.Chq*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'fin.CheckBooks', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.CheckBooks (
            CheckBookID         INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BankAccountID       INT NOT NULL,
            BookCode            VARCHAR(30)  NOT NULL,
            StartNumber         BIGINT NOT NULL,
            EndNumber           BIGINT NOT NULL,
            NextNumber          BIGINT NOT NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_CheckBooks PRIMARY KEY CLUSTERED (CheckBookID),
            CONSTRAINT UQ_fin_CheckBooks UNIQUE (TenantID, CompanyID, BookCode)
        );
    END;

    IF OBJECT_ID(N'fin.Checks', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.Checks (
            CheckID             BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NOT NULL,
            CheckType           VARCHAR(20)  NOT NULL, -- RECEIVABLE, PAYABLE
            CheckNumber         VARCHAR(40)  NOT NULL,
            CheckBookID         INT NULL,
            BankAccountID       INT NULL,
            PartnerType         VARCHAR(20)  NULL, -- CUSTOMER, SUPPLIER, OTHER
            PartnerID           INT NULL,
            PartnerName         NVARCHAR(150) NULL,
            Amount              DECIMAL(18,4) NOT NULL,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            IssueDate           DATE NOT NULL,
            DueDate             DATE NOT NULL,
            Status              VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, DEPOSITED, CLEARED, BOUNCED, CANCELLED, ENDORSED
            DepositDate         DATE NULL,
            ClearDate           DATE NULL,
            BounceReason        NVARCHAR(200) NULL,
            JournalHeaderID     BIGINT NULL,
            Notes               NVARCHAR(300) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_Checks PRIMARY KEY CLUSTERED (CheckID),
            CONSTRAINT UQ_fin_Checks UNIQUE (TenantID, CompanyID, CheckType, CheckNumber),
            CONSTRAINT CK_fin_Checks_Amount CHECK (Amount > 0)
        );
        CREATE NONCLUSTERED INDEX IX_fin_Checks_Due
            ON fin.Checks (TenantID, CompanyID, DueDate, Status) WHERE IsDeleted = 0 AND Status = 'PENDING';
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Checks & Notes created (fin.Chq*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] chq.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
