-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/fin/bank.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Banks · Statements · Reconciliation (البنوك والتسوية البنكية)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Banks & Reconciliation (fin.Bank*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'fin.Banks', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.Banks (
            BankID              INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BankCode            VARCHAR(20)  NOT NULL,
            BankNameAR          NVARCHAR(150) NOT NULL,
            BankNameEN          VARCHAR(150) NULL,
            SWIFT               VARCHAR(20) NULL,
            CountryCode         CHAR(2) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_Banks PRIMARY KEY CLUSTERED (BankID),
            CONSTRAINT UQ_fin_Banks UNIQUE (TenantID, CompanyID, BankCode)
        );
    END;

    IF OBJECT_ID(N'fin.BankAccounts', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.BankAccounts (
            BankAccountID       INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BankID              INT NOT NULL,
            AccountCode         VARCHAR(30)  NOT NULL,
            AccountNameAR       NVARCHAR(150) NOT NULL,
            AccountNameEN       VARCHAR(150) NULL,
            AccountNumber       VARCHAR(50) NULL,
            IBAN                VARCHAR(50) NULL,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            GLAccountID         INT NULL,
            OpeningBalance      DECIMAL(18,4) NOT NULL DEFAULT 0,
            CurrentBalance      DECIMAL(18,4) NOT NULL DEFAULT 0,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_BankAccounts PRIMARY KEY CLUSTERED (BankAccountID),
            CONSTRAINT UQ_fin_BankAccounts UNIQUE (TenantID, CompanyID, AccountCode),
            CONSTRAINT FK_fin_BankAccounts_Bank FOREIGN KEY (BankID) REFERENCES fin.Banks(BankID)
        );
    END;

    IF OBJECT_ID(N'fin.BankStatements', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.BankStatements (
            StatementID         BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BankAccountID       INT NOT NULL,
            StatementDate       DATE NOT NULL,
            OpeningBalance      DECIMAL(18,4) NOT NULL,
            ClosingBalance      DECIMAL(18,4) NOT NULL,
            Status              VARCHAR(20) NOT NULL DEFAULT 'IMPORTED', -- IMPORTED, RECONCILED, CLOSED
            ImportedAt          DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            ReconciledAt        DATETIME2(7) NULL,
            ReconciledBy        INT NULL,
            Notes               NVARCHAR(300) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_BankStatements PRIMARY KEY CLUSTERED (StatementID),
            CONSTRAINT FK_fin_BankStatements_Acct FOREIGN KEY (BankAccountID) REFERENCES fin.BankAccounts(BankAccountID)
        );
    END;

    IF OBJECT_ID(N'fin.BankStatementLines', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.BankStatementLines (
            StatementLineID     BIGINT IDENTITY(1,1) NOT NULL,
            StatementID         BIGINT NOT NULL,
            LineDate            DATE NOT NULL,
            Description         NVARCHAR(300) NULL,
            ReferenceNo         VARCHAR(50) NULL,
            Debit               DECIMAL(18,4) NOT NULL DEFAULT 0,
            Credit              DECIMAL(18,4) NOT NULL DEFAULT 0,
            IsMatched           BIT NOT NULL DEFAULT 0,
            MatchedPaymentID    BIGINT NULL,
            MatchedJournalID    BIGINT NULL,
            CONSTRAINT PK_fin_BankStatementLines PRIMARY KEY CLUSTERED (StatementLineID),
            CONSTRAINT FK_fin_BankStatementLines_Stmt FOREIGN KEY (StatementID) REFERENCES fin.BankStatements(StatementID) ON DELETE CASCADE
        );
    END;

    IF OBJECT_ID(N'fin.BankReconciliations', N'U') IS NULL
    BEGIN
        CREATE TABLE fin.BankReconciliations (
            ReconciliationID    BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BankAccountID       INT NOT NULL,
            ReconciliationDate  DATE NOT NULL,
            StatementBalance    DECIMAL(18,4) NOT NULL,
            BookBalance         DECIMAL(18,4) NOT NULL,
            Difference          AS (StatementBalance - BookBalance),
            Status              VARCHAR(20) NOT NULL DEFAULT 'OPEN',
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_fin_BankReconciliations PRIMARY KEY CLUSTERED (ReconciliationID),
            CONSTRAINT FK_fin_BankReconciliations_Acct FOREIGN KEY (BankAccountID) REFERENCES fin.BankAccounts(BankAccountID)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Banks & Reconciliation created (fin.Bank*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] bank.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
