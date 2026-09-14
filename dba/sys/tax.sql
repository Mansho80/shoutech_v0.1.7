-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sys/tax.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Multi-Country Tax Engine (GCC · North Africa · Levant · Europe)
-- GRADE: Enterprise Production Standard (Tier-1) — ZATCA / FTA / e-Invoicing Ready
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'sys')
    EXEC('CREATE SCHEMA [sys] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Multi-Country Tax Engine (sys.Tax*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'sys.TaxRegions', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.TaxRegions (
            TaxRegionID         INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            RegionCode          VARCHAR(20)  NOT NULL,
            RegionNameAR        NVARCHAR(100) NOT NULL,
            RegionNameEN        VARCHAR(100)  NOT NULL,
            CurrencyCode        CHAR(3)      NOT NULL DEFAULT 'SAR',
            TaxAuthority        NVARCHAR(150) NULL,
            EInvoiceScheme      VARCHAR(30)  NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            DisplayOrder        INT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_TaxRegions PRIMARY KEY CLUSTERED (TaxRegionID),
            CONSTRAINT UQ_sys_TaxRegions_Code UNIQUE (TenantID, RegionCode)
        );
    END;

    IF OBJECT_ID(N'sys.TaxTypes', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.TaxTypes (
            TaxTypeID           INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            TaxTypeCode         VARCHAR(30)  NOT NULL,
            TaxTypeNameAR       NVARCHAR(100) NOT NULL,
            TaxTypeNameEN       VARCHAR(100)  NOT NULL,
            IsRecoverable       BIT NOT NULL DEFAULT 1,
            IsCompound          BIT NOT NULL DEFAULT 0,
            IsActive            BIT NOT NULL DEFAULT 1,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_TaxTypes PRIMARY KEY CLUSTERED (TaxTypeID),
            CONSTRAINT UQ_sys_TaxTypes_Code UNIQUE (TenantID, TaxTypeCode)
        );
    END;

    IF OBJECT_ID(N'sys.TaxRates', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.TaxRates (
            TaxRateID           INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            TaxRegionID         INT NOT NULL,
            TaxTypeID           INT NOT NULL,
            RateCode            VARCHAR(40)  NOT NULL,
            RateNameAR          NVARCHAR(120) NOT NULL,
            RateNameEN          VARCHAR(120)  NOT NULL,
            RatePercent         DECIMAL(9,4) NOT NULL,
            EffectiveFrom       DATE NOT NULL,
            EffectiveTo         DATE NULL,
            IsDefault           BIT NOT NULL DEFAULT 0,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedBy           INT NULL,
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_TaxRates PRIMARY KEY CLUSTERED (TaxRateID),
            CONSTRAINT UQ_sys_TaxRates_Code UNIQUE (TenantID, CompanyID, RateCode, EffectiveFrom),
            CONSTRAINT FK_sys_TaxRates_Region FOREIGN KEY (TaxRegionID) REFERENCES sys.TaxRegions(TaxRegionID),
            CONSTRAINT FK_sys_TaxRates_Type   FOREIGN KEY (TaxTypeID)   REFERENCES sys.TaxTypes(TaxTypeID),
            CONSTRAINT CK_sys_TaxRates_Percent CHECK (RatePercent >= 0 AND RatePercent <= 100)
        );
        CREATE NONCLUSTERED INDEX IX_sys_TaxRates_Active
            ON sys.TaxRates (TenantID, CompanyID, TaxRegionID, EffectiveFrom)
            INCLUDE (RateCode, RatePercent, IsDefault)
            WHERE IsActive = 1 AND IsDeleted = 0;
    END;

    IF OBJECT_ID(N'sys.TaxAccountMap', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.TaxAccountMap (
            TaxAccountMapID     INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            TaxRateID           INT NOT NULL,
            OutputTaxAccountID  INT NULL,
            InputTaxAccountID   INT NULL,
            PayableAccountID    INT NULL,
            ReceivableAccountID INT NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_TaxAccountMap PRIMARY KEY CLUSTERED (TaxAccountMapID),
            CONSTRAINT UQ_sys_TaxAccountMap UNIQUE (TenantID, CompanyID, TaxRateID),
            CONSTRAINT FK_sys_TaxAccountMap_Rate FOREIGN KEY (TaxRateID) REFERENCES sys.TaxRates(TaxRateID)
        );
    END;

    IF OBJECT_ID(N'sys.EInvoiceConfig', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.EInvoiceConfig (
            EInvoiceConfigID    INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            TaxRegionID         INT NOT NULL,
            Scheme              VARCHAR(30)  NOT NULL,
            Environment         VARCHAR(20)  NOT NULL DEFAULT 'PROD',
            CSID                NVARCHAR(500) NULL,
            Secret              NVARCHAR(500) NULL,
            CertificatePath     NVARCHAR(500) NULL,
            PrivateKeyPath      NVARCHAR(500) NULL,
            APIEndpoint         NVARCHAR(500) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            LastSyncAt          DATETIME2(7) NULL,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_EInvoiceConfig PRIMARY KEY CLUSTERED (EInvoiceConfigID),
            CONSTRAINT UQ_sys_EInvoiceConfig UNIQUE (TenantID, CompanyID, TaxRegionID, Scheme),
            CONSTRAINT FK_sys_EInvoiceConfig_Region FOREIGN KEY (TaxRegionID) REFERENCES sys.TaxRegions(TaxRegionID)
        );
    END;

    IF OBJECT_ID(N'sys.EInvoiceLog', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.EInvoiceLog (
            EInvoiceLogID       BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            DocumentType        VARCHAR(30)  NOT NULL,
            DocumentID          BIGINT NOT NULL,
            DocumentNo          VARCHAR(50)  NOT NULL,
            UUID                UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
            InvoiceHash         VARCHAR(128) NULL,
            QRCode              NVARCHAR(MAX) NULL,
            Status              VARCHAR(30)  NOT NULL DEFAULT 'PENDING',
            AuthorityResponse   NVARCHAR(MAX) NULL,
            SubmittedAt         DATETIME2(7) NULL,
            ClearedAt           DATETIME2(7) NULL,
            ErrorMessage        NVARCHAR(1000) NULL,
            RetryCount          INT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_EInvoiceLog PRIMARY KEY CLUSTERED (EInvoiceLogID)
        );
        CREATE NONCLUSTERED INDEX IX_sys_EInvoiceLog_Doc
            ON sys.EInvoiceLog (TenantID, CompanyID, DocumentType, DocumentID);
        CREATE NONCLUSTERED INDEX IX_sys_EInvoiceLog_Status
            ON sys.EInvoiceLog (Status, SubmittedAt) WHERE Status IN ('PENDING','REJECTED');
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.TaxRegions WHERE RegionCode = 'SA')
    BEGIN
        INSERT INTO sys.TaxRegions (RegionCode, RegionNameAR, RegionNameEN, CurrencyCode, TaxAuthority, EInvoiceScheme, DisplayOrder)
        VALUES
            ('SA', N'المملكة العربية السعودية', 'Saudi Arabia', 'SAR', N'هيئة الزكاة والضريبة والجمارك (ZATCA)', 'ZATCA_PHASE2', 1),
            ('AE', N'الإمارات العربية المتحدة', 'United Arab Emirates', 'AED', N'الهيئة الاتحادية للضرائب (FTA)', 'FTA_EINVOICE', 2),
            ('KW', N'الكويت', 'Kuwait', 'KWD', N'وزارة المالية', 'NONE', 3),
            ('BH', N'البحرين', 'Bahrain', 'BHD', N'الجهاز الوطني للإيرادات', 'NONE', 4),
            ('OM', N'عُمان', 'Oman', 'OMR', N'هيئة الضرائب', 'NONE', 5),
            ('QA', N'قطر', 'Qatar', 'QAR', N'الهيئة العامة للضرائب', 'NONE', 6),
            ('EG', N'مصر', 'Egypt', 'EGP', N'مصلحة الضرائب المصرية', 'NONE', 7),
            ('JO', N'الأردن', 'Jordan', 'JOD', N'دائرة ضريبة الدخل والمبيعات', 'NONE', 8),
            ('LB', N'لبنان', 'Lebanon', 'LBP', N'وزارة المالية', 'NONE', 9),
            ('EU', N'الاتحاد الأوروبي', 'European Union', 'EUR', N'EU VAT', 'PEPPOL', 10);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.TaxTypes WHERE TaxTypeCode = 'VAT')
    BEGIN
        INSERT INTO sys.TaxTypes (TaxTypeCode, TaxTypeNameAR, TaxTypeNameEN, IsRecoverable)
        VALUES
            ('VAT',   N'ضريبة القيمة المضافة', 'Value Added Tax', 1),
            ('EXCISE',N'ضريبة السلع الانتقائية', 'Excise Tax', 0),
            ('WHT',   N'ضريبة الاستقطاع', 'Withholding Tax', 0),
            ('ZERO',  N'نسبة صفر', 'Zero Rate', 1),
            ('EXEMPT',N'معفى', 'Exempt', 0);
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Multi-Country Tax Engine created successfully (sys.Tax*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] tax.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
