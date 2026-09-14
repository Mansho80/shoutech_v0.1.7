-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/fin/pay.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Payments · Receipts · Bank Transfers (سندات القبض والصرف)
-- GRADE: Enterprise Production Standard (Tier-1) — Global Accounting Standards
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'fin')
    EXEC('CREATE SCHEMA [fin] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Payments & Vouchers (fin.Pay*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'fin.PaymentHeaders', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.PaymentHeaders (
            PaymentHeaderID     BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NOT NULL,
            VoucherNo           VARCHAR(40)  NOT NULL,
            VoucherType         VARCHAR(20)  NOT NULL, -- RECEIPT, PAYMENT, TRANSFER
            VoucherDate         DATE NOT NULL,
            PartnerType         VARCHAR(20)  NULL, -- CUSTOMER, SUPPLIER, EMPLOYEE, OTHER
            PartnerID           INT NULL,
            PartnerName         NVARCHAR(150) NULL,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            ExchangeRate        DECIMAL(18,8) NOT NULL DEFAULT 1,
            TotalAmount         DECIMAL(18,4) NOT NULL,
            NarrationAR         NVARCHAR(500) NULL,
            NarrationEN         VARCHAR(500) NULL,
            FiscalYear          INT NOT NULL,
            JournalHeaderID     BIGINT NULL,
            Status              VARCHAR(20) NOT NULL DEFAULT 'POSTED', -- DRAFT, POSTED, VOIDED
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedBy           INT NULL,
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_PaymentHeaders PRIMARY KEY CLUSTERED (PaymentHeaderID),
            CONSTRAINT UQ_fin_PaymentHeaders_No UNIQUE (TenantID, CompanyID, VoucherNo),
            CONSTRAINT CK_fin_PaymentHeaders_Amount CHECK (TotalAmount > 0)
        );
        CREATE NONCLUSTERED INDEX IX_fin_PaymentHeaders_Date
            ON fin.PaymentHeaders (TenantID, CompanyID, VoucherDate DESC)
            WHERE IsDeleted = 0;
    END;

    IF OBJECT_ID(N'fin.PaymentLines', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.PaymentLines (
            PaymentLineID       BIGINT IDENTITY(1,1) NOT NULL,
            PaymentHeaderID     BIGINT NOT NULL,
            LineNumber          INT NOT NULL,
            AccountID           INT NOT NULL,
            Debit               DECIMAL(18,4) NOT NULL DEFAULT 0,
            Credit              DECIMAL(18,4) NOT NULL DEFAULT 0,
            CostCenterID        INT NULL,
            LineNarration       NVARCHAR(300) NULL,
            CONSTRAINT PK_fin_PaymentLines PRIMARY KEY CLUSTERED (PaymentLineID),
            CONSTRAINT FK_fin_PaymentLines_Header FOREIGN KEY (PaymentHeaderID) REFERENCES fin.PaymentHeaders(PaymentHeaderID) ON DELETE CASCADE,
            CONSTRAINT CK_fin_PaymentLines_OneSide CHECK ((Debit > 0 AND Credit = 0) OR (Credit > 0 AND Debit = 0))
        );
    END;

    IF OBJECT_ID(N'fin.BankAccounts', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.BankAccounts (
            BankAccountID       INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            AccountCode         VARCHAR(30)  NOT NULL,
            AccountNameAR       NVARCHAR(150) NOT NULL,
            AccountNameEN       VARCHAR(150) NULL,
            BankNameAR          NVARCHAR(150) NULL,
            BankNameEN          VARCHAR(150) NULL,
            IBAN                VARCHAR(50) NULL,
            SWIFT               VARCHAR(20) NULL,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            GLAccountID         INT NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_BankAccounts PRIMARY KEY CLUSTERED (BankAccountID),
            CONSTRAINT UQ_fin_BankAccounts UNIQUE (TenantID, CompanyID, AccountCode)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Payments & Bank Accounts created successfully (fin.Pay*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] pay.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
