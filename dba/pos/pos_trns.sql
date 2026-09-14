-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/pos/pos_trns.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: POS Transactions (Sales · Returns · Payments) — Offline-First
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'pos')
    EXEC('CREATE SCHEMA [pos] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building POS Transactions (pos.Trn*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'pos.SalesHeaders', N'U') IS NULL
    BEGIN
        CREATE TABLE pos.SalesHeaders (
            SalesHeaderID       BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NOT NULL,
            TerminalID          INT NOT NULL,
            ShiftID             BIGINT NULL,
            InvoiceNo           VARCHAR(40)  NOT NULL,
            InvoiceType         VARCHAR(20)  NOT NULL DEFAULT 'SALE', -- SALE, RETURN, HOLD
            CustomerID          INT NULL,
            CustomerName        NVARCHAR(150) NULL,
            SalesRepID          INT NULL,
            InvoiceDate         DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            SubTotal            DECIMAL(18,4) NOT NULL DEFAULT 0,
            DiscountAmount      DECIMAL(18,4) NOT NULL DEFAULT 0,
            TaxAmount           DECIMAL(18,4) NOT NULL DEFAULT 0,
            NetTotal            DECIMAL(18,4) NOT NULL DEFAULT 0,
            PaidAmount          DECIMAL(18,4) NOT NULL DEFAULT 0,
            ChangeAmount        DECIMAL(18,4) NOT NULL DEFAULT 0,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            ExchangeRate        DECIMAL(18,8) NOT NULL DEFAULT 1,
            Status              VARCHAR(20) NOT NULL DEFAULT 'COMPLETED', -- DRAFT, HOLD, COMPLETED, VOIDED
            FiscalYear          INT NOT NULL,
            TaxRegionID         INT NULL,
            EInvoiceUUID        UNIQUEIDENTIFIER NULL,
            Notes               NVARCHAR(500) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedBy           INT NULL,
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_pos_SalesHeaders PRIMARY KEY CLUSTERED (SalesHeaderID),
            CONSTRAINT UQ_pos_SalesHeaders_No UNIQUE (TenantID, CompanyID, InvoiceNo),
            CONSTRAINT CK_pos_SalesHeaders_Totals CHECK (NetTotal >= 0)
        );
        CREATE NONCLUSTERED INDEX IX_pos_SalesHeaders_Date
            ON pos.SalesHeaders (TenantID, CompanyID, InvoiceDate DESC)
            INCLUDE (InvoiceNo, NetTotal, Status) WHERE IsDeleted = 0;
        CREATE NONCLUSTERED INDEX IX_pos_SalesHeaders_Terminal
            ON pos.SalesHeaders (TerminalID, ShiftID) WHERE IsDeleted = 0;
    END;

    IF OBJECT_ID(N'pos.SalesLines', N'U') IS NULL
    BEGIN
        CREATE TABLE pos.SalesLines (
            SalesLineID         BIGINT IDENTITY(1,1) NOT NULL,
            SalesHeaderID       BIGINT NOT NULL,
            LineNumber          INT NOT NULL,
            ProductID           INT NOT NULL,
            ProductCode         VARCHAR(50) NULL,
            ProductNameAR       NVARCHAR(200) NOT NULL,
            Qty                 DECIMAL(18,4) NOT NULL,
            UnitPrice           DECIMAL(18,4) NOT NULL,
            DiscountPercent     DECIMAL(9,4) NOT NULL DEFAULT 0,
            DiscountAmount      DECIMAL(18,4) NOT NULL DEFAULT 0,
            TaxRateID           INT NULL,
            TaxPercent          DECIMAL(9,4) NOT NULL DEFAULT 0,
            TaxAmount           DECIMAL(18,4) NOT NULL DEFAULT 0,
            LineTotal           DECIMAL(18,4) NOT NULL,
            WarehouseID         INT NULL,
            CostCenterID        INT NULL,
            CONSTRAINT PK_pos_SalesLines PRIMARY KEY CLUSTERED (SalesLineID),
            CONSTRAINT FK_pos_SalesLines_Header FOREIGN KEY (SalesHeaderID) REFERENCES pos.SalesHeaders(SalesHeaderID) ON DELETE CASCADE,
            CONSTRAINT CK_pos_SalesLines_Qty CHECK (Qty <> 0)
        );
        CREATE NONCLUSTERED INDEX IX_pos_SalesLines_Header
            ON pos.SalesLines (SalesHeaderID) INCLUDE (ProductID, Qty, LineTotal);
    END;

    IF OBJECT_ID(N'pos.SalesPayments', N'U') IS NULL
    BEGIN
        CREATE TABLE pos.SalesPayments (
            SalesPaymentID      BIGINT IDENTITY(1,1) NOT NULL,
            SalesHeaderID       BIGINT NOT NULL,
            PaymentMethodID     INT NOT NULL,
            Amount              DECIMAL(18,4) NOT NULL,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            ReferenceNo         VARCHAR(80) NULL,
            CardLast4           CHAR(4) NULL,
            AuthCode            VARCHAR(40) NULL,
            PaidAt              DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            CONSTRAINT PK_pos_SalesPayments PRIMARY KEY CLUSTERED (SalesPaymentID),
            CONSTRAINT FK_pos_SalesPayments_Header FOREIGN KEY (SalesHeaderID) REFERENCES pos.SalesHeaders(SalesHeaderID) ON DELETE CASCADE,
            CONSTRAINT CK_pos_SalesPayments_Amount CHECK (Amount > 0)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] POS Transactions created successfully (pos.Sales*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] pos_trns.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
