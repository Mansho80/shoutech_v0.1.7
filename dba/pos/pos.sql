-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/pos/pos.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Point of Sale Core (Terminals · Devices · Config)
-- GRADE: Enterprise Production Standard (Tier-1) — Offline-First POS
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'pos')
    EXEC('CREATE SCHEMA [pos] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building POS Core (pos.*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'pos.Terminals', N'U') IS NULL
    BEGIN
        CREATE TABLE pos.Terminals (
            TerminalID          INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NOT NULL,
            TerminalCode        VARCHAR(30)  NOT NULL,
            TerminalNameAR      NVARCHAR(120) NOT NULL,
            TerminalNameEN      VARCHAR(120)  NULL,
            DeviceFingerprint   VARCHAR(128) NULL,
            WarehouseID         INT NULL,
            DefaultCashAccountID INT NULL,
            DefaultBankAccountID INT NULL,
            ReceiptPrinterName  NVARCHAR(150) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedBy           INT NULL,
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_pos_Terminals PRIMARY KEY CLUSTERED (TerminalID),
            CONSTRAINT UQ_pos_Terminals_Code UNIQUE (TenantID, CompanyID, TerminalCode)
        );
        CREATE NONCLUSTERED INDEX IX_pos_Terminals_Branch
            ON pos.Terminals (TenantID, CompanyID, BranchID) WHERE IsDeleted = 0 AND IsActive = 1;
    END;

    IF OBJECT_ID(N'pos.POSConfig', N'U') IS NULL
    BEGIN
        CREATE TABLE pos.POSConfig (
            POSConfigID         INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            TerminalID          INT NULL,
            ConfigKey           VARCHAR(80)  NOT NULL,
            ConfigValue         NVARCHAR(MAX) NULL,
            DataType            VARCHAR(20)  NOT NULL DEFAULT 'STRING',
            DescriptionAR       NVARCHAR(200) NULL,
            UpdatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_pos_POSConfig PRIMARY KEY CLUSTERED (POSConfigID),
            CONSTRAINT UQ_pos_POSConfig UNIQUE (TenantID, CompanyID, TerminalID, ConfigKey),
            CONSTRAINT FK_pos_POSConfig_Terminal FOREIGN KEY (TerminalID) REFERENCES pos.Terminals(TerminalID)
        );
    END;

    IF OBJECT_ID(N'pos.PaymentMethods', N'U') IS NULL
    BEGIN
        CREATE TABLE pos.PaymentMethods (
            PaymentMethodID     INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            MethodCode          VARCHAR(30)  NOT NULL,
            MethodNameAR        NVARCHAR(80) NOT NULL,
            MethodNameEN        VARCHAR(80)  NULL,
            MethodType          VARCHAR(20)  NOT NULL, -- CASH, CARD, BANK, LOYALTY, CREDIT, OTHER
            GLAccountID         INT NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            DisplayOrder        INT NOT NULL DEFAULT 0,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_pos_PaymentMethods PRIMARY KEY CLUSTERED (PaymentMethodID),
            CONSTRAINT UQ_pos_PaymentMethods UNIQUE (TenantID, CompanyID, MethodCode)
        );
    END;

    IF OBJECT_ID(N'pos.QuickKeys', N'U') IS NULL
    BEGIN
        CREATE TABLE pos.QuickKeys (
            QuickKeyID          INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            TerminalID          INT NULL,
            KeyCode             VARCHAR(20)  NOT NULL,
            ProductID           INT NULL,
            CategoryID          INT NULL,
            DisplayLabelAR      NVARCHAR(80) NULL,
            DisplayOrder        INT NOT NULL DEFAULT 0,
            IsActive            BIT NOT NULL DEFAULT 1,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_pos_QuickKeys PRIMARY KEY CLUSTERED (QuickKeyID),
            CONSTRAINT FK_pos_QuickKeys_Terminal FOREIGN KEY (TerminalID) REFERENCES pos.Terminals(TerminalID)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] POS Core created successfully (pos.Terminals / Config / PaymentMethods).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] pos.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
