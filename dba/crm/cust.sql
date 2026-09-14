-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/crm/cust.sql
-- PURPOSE: Tier-1 Enterprise Business Partner Schema (Customers & Vendors)
-- ENGINE: SQL Server 2019+ / Azure SQL / Enterprise Edition
-- FEATURES: System-Versioned Temporal Auditing, ZATCA Compliance, Multi-Tenancy RLS
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. إنشاء جدول المتعاملين الموحد مع التتبع الزمني التلقائي (Temporal Table)
IF OBJECT_ID(N'dbo.BusinessPartners', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BusinessPartners
    (
        -- ── المعرفات المفتوحة والمتعددة للشركات ──
        PartnerID               BIGINT IDENTITY(1,1) NOT NULL,
        PartnerGUID             UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
        TenantID                INT NOT NULL,
        CompanyID               INT NOT NULL,
        PartnerCode             VARCHAR(50) NOT NULL,
        
        -- ── التوجيه المحاسبي المباشر (الربط مع شجرة الحسابات COA) ──
        AccountID               BIGINT NULL,               -- الحساب المرتبط بدفتر الأستاذ (GL Account)
        CurrencyID              INT NOT NULL DEFAULT 1,    -- العملة الافتراضية
        
        -- ── بيانات الهوية والتصنيف ──
        PartnerType             TINYINT NOT NULL DEFAULT 1, -- 1: شركة/مؤسسة (Organization), 2: فرد (Person)
        IsCustomer              BIT NOT NULL DEFAULT 1,     -- صفة عميل
        IsVendor                BIT NOT NULL DEFAULT 0,     -- صفة مورد
        IsEmployee              BIT NOT NULL DEFAULT 0,     -- صفة موظف/مندوب
        CategoryID              INT NULL,                   -- FK -> CustomerCategories
        SalesChannelID          INT NULL,                   -- FK -> SalesChannels
        SalesRepresentativeID  BIGINT NULL,                -- مندوب المبيعات المخصص
        
        -- ── الأسماء والمعلومات الأساسية ──
        NameAR                  NVARCHAR(255) NOT NULL,
        NameEN                  VARCHAR(255) NULL,
        TradeName               NVARCHAR(255) NULL,         -- الاسم التجاري / اسم المعرض
        
        -- ── بيانات الضريبة والامتثال المحلي (Saudi ZATCA / GCC VAT) ──
        TaxNumber               VARCHAR(15) NULL,           -- الرقم الضريبي (15 رقم)
        CRNumber                VARCHAR(50) NULL,           -- السجل التجاري
        NationalID              VARCHAR(10) NULL,           -- الهوية الوطنية / الإقامة
        
        -- ── العنوان الوطني المعياري (National Address Standard) ──
        BuildingNo              VARCHAR(10) NULL,
        StreetName              NVARCHAR(150) NULL,
        District                NVARCHAR(150) NULL,
        City                    NVARCHAR(100) NULL,
        CountryCode             CHAR(2) NOT NULL DEFAULT 'SA', -- ISO-2 Code
        PostalCode              VARCHAR(10) NULL,
        AdditionalNo            VARCHAR(10) NULL,
        
        -- ── الشروط الائتمانية والمالية ──
        CreditLimit             DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
        CreditDays              INT NOT NULL DEFAULT 0,     -- فترة الاستحقاق بالايام
        StopOnCreditLimitExceed BIT NOT NULL DEFAULT 1,     -- إيقاف البيع عند تجاوز الائتمان
        DiscountPercentage      DECIMAL(5,2) NOT NULL DEFAULT 0.00,
        
        -- ── الاتصال والتواصل ──
        Phone                   VARCHAR(20) NULL,
        Mobile                  VARCHAR(20) NULL,
        Email                   VARCHAR(150) NULL,
        Website                 VARCHAR(150) NULL,
        
        -- ── الحالة والقيود ──
        IsActive                BIT NOT NULL DEFAULT 1,
        IsBlacklisted           BIT NOT NULL DEFAULT 0,     -- القائمة السوداء
        BlacklistReason         NVARCHAR(500) NULL,
        
        -- ── بيانات التدقيق الحسابي والزماني ──
        CreatedBy               INT NOT NULL,
        CreatedAt               DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedBy               INT NULL,
        UpdatedAt               DATETIME2(7) NULL,
        
        -- ── أعمدة النظام للتتبع التاريخي (Temporal Period Columns) ──
        SysStartTime            DATETIME2(7) GENERATED ALWAYS AS ROW START NOT NULL,
        SysEndTime              DATETIME2(7) GENERATED ALWAYS AS ROW END NOT NULL,
        PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime),

        -- ── القيود الأساسية (Primary & Candidate Keys) ──
        CONSTRAINT PK_BusinessPartners PRIMARY KEY CLUSTERED (PartnerID ASC),
        CONSTRAINT UQ_BusinessPartners_Code UNIQUE NONCLUSTERED (TenantID, CompanyID, PartnerCode)
    )
    WITH
    (
        -- تفعيل الأرشفة والتتبع التاريخي التلقائي للجداول
        SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.BusinessPartnersHistory)
    );

    RAISERROR(N'✅ [SUCCESS] BusinessPartners System-Versioned Table Created.', 0, 1) WITH NOWAIT;
END
GO

-- ═════════════════════════════════════════════════════════════════════════════════
-- 2. قيود التحقق البرمجية للامتثال والضبط (CHECK CONSTRAINTS)
-- ═════════════════════════════════════════════════════════════════════════════════

-- ── قيد التحقق من صيغة الرقم الضريبي السعودي (ZATCA VAT Format: 15 أرقام يبدأ وينتهي بـ 3) ──
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE name = 'CK_BusinessPartners_ZATCA_VAT')
BEGIN
    ALTER TABLE dbo.BusinessPartners ADD CONSTRAINT CK_BusinessPartners_ZATCA_VAT
    CHECK (TaxNumber IS NULL OR TaxNumber LIKE '3[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]3');
END
GO

-- ── قيد التحقق من أن الكيان يملك صفة واحدة على الأقل ──
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE name = 'CK_BusinessPartners_Role')
BEGIN
    ALTER TABLE dbo.BusinessPartners ADD CONSTRAINT CK_BusinessPartners_Role
    CHECK (IsCustomer = 1 OR IsVendor = 1 OR IsEmployee = 1);
END
GO

-- ═════════════════════════════════════════════════════════════════════════════════
-- 3. الفهارس المتقدمة لتحسين الأداء (HIGH-PERFORMANCE INDEXES)
-- ═════════════════════════════════════════════════════════════════════════════════

-- ── فهرس ربط الحسابات المالي بسرعة (للاستخدام مع زر الماوس الأيمن في شجرة الحسابات) ──
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_BusinessPartners_AccountID')
BEGIN
    CREATE NONCLUSTERED INDEX IX_BusinessPartners_AccountID
    ON dbo.BusinessPartners (TenantID, CompanyID, AccountID)
    INCLUDE (PartnerCode, NameAR, IsCustomer, IsVendor, CreditLimit)
    WHERE AccountID IS NOT NULL;
END
GO

-- ── فهرس الفلترة السريعة للموردين ──
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_BusinessPartners_Vendors')
BEGIN
    CREATE NONCLUSTERED INDEX IX_BusinessPartners_Vendors
    ON dbo.BusinessPartners (TenantID, CompanyID, IsVendor, IsActive)
    INCLUDE (PartnerID, PartnerCode, NameAR, TaxNumber, CreditDays)
    WHERE IsVendor = 1;
END
GO

-- ── فهرس الفلترة السريعة للعملاء ──
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_BusinessPartners_Customers')
BEGIN
    CREATE NONCLUSTERED INDEX IX_BusinessPartners_Customers
    ON dbo.BusinessPartners (TenantID, CompanyID, IsCustomer, IsActive)
    INCLUDE (PartnerID, PartnerCode, NameAR, TaxNumber, CreditLimit, CreditDays)
    WHERE IsCustomer = 1;
END
GO

-- ═════════════════════════════════════════════════════════════════════════════════
-- 4. ربط العلاقات المباشرة (FOREIGN KEYS)
-- ═════════════════════════════════════════════════════════════════════════════════

IF OBJECT_ID(N'dbo.CustomerCategories', N'U') IS NOT NULL 
   AND NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_BusinessPartners_CustomerCategories')
BEGIN
    ALTER TABLE dbo.BusinessPartners ADD CONSTRAINT FK_BusinessPartners_CustomerCategories
    FOREIGN KEY (CategoryID) REFERENCES dbo.CustomerCategories(CategoryID);
END
GO