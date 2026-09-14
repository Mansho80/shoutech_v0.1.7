-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/crm/ord.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Sales Orders · Purchase Orders · Quotations (طلبيات + عروض سعر)
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'crm')
    EXEC('CREATE SCHEMA [crm] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Orders & Quotations (crm.Ord*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    -- عروض السعر
    IF OBJECT_ID(N'crm.Quotations', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.Quotations (
            QuotationID         BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NOT NULL,
            QuotationNo         VARCHAR(40)  NOT NULL,
            CustomerID          INT NOT NULL,
            SalesRepID          INT NULL,
            QuotationDate       DATE NOT NULL,
            ValidUntil          DATE NULL,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            ExchangeRate        DECIMAL(18,8) NOT NULL DEFAULT 1,
            SubTotal            DECIMAL(18,4) NOT NULL DEFAULT 0,
            DiscountAmount      DECIMAL(18,4) NOT NULL DEFAULT 0,
            TaxAmount           DECIMAL(18,4) NOT NULL DEFAULT 0,
            GrandTotal          DECIMAL(18,4) NOT NULL DEFAULT 0,
            Status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT', -- DRAFT, SENT, ACCEPTED, REJECTED, EXPIRED, CONVERTED
            ConvertedOrderID    BIGINT NULL,
            Notes               NVARCHAR(500) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_crm_Quotations PRIMARY KEY CLUSTERED (QuotationID),
            CONSTRAINT UQ_crm_Quotations UNIQUE (TenantID, CompanyID, QuotationNo)
        );
        CREATE NONCLUSTERED INDEX IX_crm_Quotations_Customer
            ON crm.Quotations (TenantID, CompanyID, CustomerID, QuotationDate DESC) WHERE IsDeleted = 0;
    END;

    IF OBJECT_ID(N'crm.QuotationLines', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.QuotationLines (
            QuotationLineID     BIGINT IDENTITY(1,1) NOT NULL,
            QuotationID         BIGINT NOT NULL,
            LineNumber          INT NOT NULL,
            ProductID           INT NOT NULL,
            Qty                 DECIMAL(18,4) NOT NULL,
            UnitPrice           DECIMAL(18,4) NOT NULL,
            DiscountPercent     DECIMAL(9,4) NOT NULL DEFAULT 0,
            TaxPercent          DECIMAL(9,4) NOT NULL DEFAULT 0,
            LineTotal           DECIMAL(18,4) NOT NULL,
            CONSTRAINT PK_crm_QuotationLines PRIMARY KEY CLUSTERED (QuotationLineID),
            CONSTRAINT FK_crm_QuotationLines_Hdr FOREIGN KEY (QuotationID) REFERENCES crm.Quotations(QuotationID) ON DELETE CASCADE
        );
    END;

    -- طلبيات البيع
    IF OBJECT_ID(N'crm.SalesOrders', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.SalesOrders (
            SalesOrderID        BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NOT NULL,
            OrderNo             VARCHAR(40)  NOT NULL,
            CustomerID          INT NOT NULL,
            SalesRepID          INT NULL,
            QuotationID         BIGINT NULL,
            OrderDate           DATE NOT NULL,
            RequiredDate        DATE NULL,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            ExchangeRate        DECIMAL(18,8) NOT NULL DEFAULT 1,
            SubTotal            DECIMAL(18,4) NOT NULL DEFAULT 0,
            DiscountAmount      DECIMAL(18,4) NOT NULL DEFAULT 0,
            TaxAmount           DECIMAL(18,4) NOT NULL DEFAULT 0,
            GrandTotal          DECIMAL(18,4) NOT NULL DEFAULT 0,
            DeliveredAmount     DECIMAL(18,4) NOT NULL DEFAULT 0,
            InvoicedAmount      DECIMAL(18,4) NOT NULL DEFAULT 0,
            Status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT', -- DRAFT, CONFIRMED, PARTIAL, DELIVERED, INVOICED, CANCELLED
            WarehouseID         INT NULL,
            Notes               NVARCHAR(500) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_crm_SalesOrders PRIMARY KEY CLUSTERED (SalesOrderID),
            CONSTRAINT UQ_crm_SalesOrders UNIQUE (TenantID, CompanyID, OrderNo)
        );
        CREATE NONCLUSTERED INDEX IX_crm_SalesOrders_Status
            ON crm.SalesOrders (TenantID, CompanyID, Status, OrderDate DESC) WHERE IsDeleted = 0;
    END;

    IF OBJECT_ID(N'crm.SalesOrderLines', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.SalesOrderLines (
            SalesOrderLineID    BIGINT IDENTITY(1,1) NOT NULL,
            SalesOrderID        BIGINT NOT NULL,
            LineNumber          INT NOT NULL,
            ProductID           INT NOT NULL,
            Qty                 DECIMAL(18,4) NOT NULL,
            DeliveredQty        DECIMAL(18,4) NOT NULL DEFAULT 0,
            InvoicedQty         DECIMAL(18,4) NOT NULL DEFAULT 0,
            UnitPrice           DECIMAL(18,4) NOT NULL,
            DiscountPercent     DECIMAL(9,4) NOT NULL DEFAULT 0,
            TaxPercent          DECIMAL(9,4) NOT NULL DEFAULT 0,
            LineTotal           DECIMAL(18,4) NOT NULL,
            WarehouseID         INT NULL,
            CONSTRAINT PK_crm_SalesOrderLines PRIMARY KEY CLUSTERED (SalesOrderLineID),
            CONSTRAINT FK_crm_SalesOrderLines_Hdr FOREIGN KEY (SalesOrderID) REFERENCES crm.SalesOrders(SalesOrderID) ON DELETE CASCADE,
            CONSTRAINT CK_crm_SalesOrderLines_Qty CHECK (Qty > 0)
        );
    END;

    -- دفعات الطلبيات
    IF OBJECT_ID(N'crm.OrderPayments', N'U') IS NULL
    BEGIN
        CREATE TABLE crm.OrderPayments (
            OrderPaymentID      BIGINT IDENTITY(1,1) NOT NULL,
            SalesOrderID        BIGINT NOT NULL,
            PaymentDate         DATE NOT NULL,
            Amount              DECIMAL(18,4) NOT NULL,
            PaymentMethodCode   VARCHAR(30) NULL,
            ReferenceNo         VARCHAR(50) NULL,
            Notes               NVARCHAR(200) NULL,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            CONSTRAINT PK_crm_OrderPayments PRIMARY KEY CLUSTERED (OrderPaymentID),
            CONSTRAINT FK_crm_OrderPayments_SO FOREIGN KEY (SalesOrderID) REFERENCES crm.SalesOrders(SalesOrderID) ON DELETE CASCADE
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Orders & Quotations created (crm.Ord*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] ord.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
