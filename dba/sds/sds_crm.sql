-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sds/sds_crm.sql
-- PURPOSE: Unified Business Partner (Customer & Vendor) & Sales Channels Seeding Pipeline
-- SYSTEM GRADE: Tier-1 Enterprise ERP Standard (10/10 Production-Grade)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @TenantID INT = 1;
DECLARE @CompanyID INT = 1;
DECLARE @CreatedBy INT = 1;

RAISERROR(N'🚀 [START] Initiating Unified Partner & CRM Seeding Pipeline...', 0, 1) WITH NOWAIT;

-- التحقق المسبق من وجود جداول مجموعات الشركاء وقنوات المبيعات
IF OBJECT_ID(N'dbo.CustomerCategories', N'U') IS NULL OR OBJECT_ID(N'dbo.SalesChannels', N'U') IS NULL
BEGIN
    RAISERROR(N'❌ [CRITICAL] Core CRM tables (CustomerCategories / SalesChannels) do not exist. Aborting execution.', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;

BEGIN TRY
    
    -- ══════════════════════════════════════════════════════════════════════════
    -- 1. تهيئة مجموعات المتعاملين (عملاء وموردين) - Partner Categories Seeding
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'👥 [PROCESS] Staging Business Partner Categories (Customers & Vendors)...', 0, 1) WITH NOWAIT;

    DECLARE @RawPartnerCats TABLE (
        TenantID               INT NOT NULL,
        CompanyID              INT NOT NULL,
        CategoryCode           VARCHAR(50) NOT NULL,
        CategoryNameAR         NVARCHAR(255) NOT NULL,
        CategoryNameEN         VARCHAR(255) NOT NULL,
        IsCustomerCategory     BIT NOT NULL DEFAULT 1,
        IsVendorCategory       BIT NOT NULL DEFAULT 0,
        DefaultCreditLimit     DECIMAL(18,4) NOT NULL DEFAULT 0,
        DefaultPaymentTermDays INT NOT NULL DEFAULT 0,
        IsActive               BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, CategoryCode)
    );

    INSERT INTO @RawPartnerCats 
    (TenantID, CompanyID, CategoryCode, CategoryNameAR, CategoryNameEN, IsCustomerCategory, IsVendorCategory, DefaultCreditLimit, DefaultPaymentTermDays, IsActive)
    VALUES 
    -- ── تصنيفات العملاء ──
    (@TenantID, @CompanyID, 'CUST-VIP', N'عملاء كبار الشخصيات (VIP)', 'VIP Key Accounts',           1, 0, 100000.0000, 60, 1),
    (@TenantID, @CompanyID, 'CUST-RET', N'العملاء الأفراد (تجزيئة)',    'Retail Cash Customers',      1, 0, 5000.0000,   0,  1),
    (@TenantID, @CompanyID, 'CUST-WHS', N'العملاء الجملة والموزعون',   'Wholesale & Distributors',   1, 0, 50000.0000,  30, 1),
    (@TenantID, @CompanyID, 'CUST-GOV', N'القطاع الحكومي والمؤسسات',   'Government & Institutions',  1, 0, 250000.0000, 90, 1),
    
    -- ── تصنيفات الموردين ──
    (@TenantID, @CompanyID, 'VND-KEY',  N'الموردون الاستراتيجيون',     'Key Strategic Suppliers',    0, 1, 0.0000,      90, 1),
    (@TenantID, @CompanyID, 'VND-LOC',  N'الموردون المحاليون (بضاعة)', 'Local Trade Vendors',        0, 1, 0.0000,      30, 1),
    (@TenantID, @CompanyID, 'VND-INT',  N'الموردون الخارجيون (استيراد)','International Overseas Vendors', 0, 1, 0.0000,  60, 1),
    (@TenantID, @CompanyID, 'VND-SRV',  N'موردو الخدمات والمصاريف',    'Service & Expense Vendors',  0, 1, 0.0000,      15, 1);

    DECLARE @CustCatActions TABLE (ActionType VARCHAR(10));

    MERGE INTO dbo.CustomerCategories WITH (TABLOCKX) AS Target
    USING @RawPartnerCats AS Source
    ON (Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.CategoryCode = Source.CategoryCode)
    
    WHEN MATCHED AND (
        Target.CategoryNameAR         <> Source.CategoryNameAR OR
        Target.CategoryNameEN         <> Source.CategoryNameEN OR
        Target.DefaultCreditLimit     <> Source.DefaultCreditLimit OR
        Target.DefaultPaymentTermDays <> Source.DefaultPaymentTermDays OR
        Target.IsActive               <> Source.IsActive
    ) THEN
        UPDATE SET 
            Target.CategoryNameAR         = Source.CategoryNameAR,
            Target.CategoryNameEN         = Source.CategoryNameEN,
            Target.DefaultCreditLimit     = Source.DefaultCreditLimit,
            Target.DefaultPaymentTermDays = Source.DefaultPaymentTermDays,
            Target.IsActive               = Source.IsActive,
            Target.UpdatedBy              = @CreatedBy,
            Target.UpdatedAt              = SYSDATETIME()

    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, CategoryCode, CategoryNameAR, CategoryNameEN, DefaultCreditLimit, DefaultPaymentTermDays, IsActive, CreatedBy, CreatedAt)
        VALUES (Source.TenantID, Source.CompanyID, Source.CategoryCode, Source.CategoryNameAR, Source.CategoryNameEN, Source.DefaultCreditLimit, Source.DefaultPaymentTermDays, Source.IsActive, @CreatedBy, SYSDATETIME())
    
    OUTPUT $action INTO @CustCatActions;

    -- ══════════════════════════════════════════════════════════════════════════
    -- 2. تهيئة قنوات المبيعات والتوزيع (Sales Channels Seeding)
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'📈 [PROCESS] Staging Sales Channels data...', 0, 1) WITH NOWAIT;

    DECLARE @RawChannels TABLE (
        TenantID      INT NOT NULL,
        CompanyID     INT NOT NULL,
        ChannelCode   VARCHAR(50) NOT NULL,
        ChannelNameAR NVARCHAR(255) NOT NULL,
        ChannelNameEN VARCHAR(255) NOT NULL,
        IsActive      BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, ChannelCode)
    );

    INSERT INTO @RawChannels (TenantID, CompanyID, ChannelCode, ChannelNameAR, ChannelNameEN, IsActive)
    VALUES 
    (@TenantID, @CompanyID, 'CH-DIR', N'مبيعات مباشرة (المعرض الرئيسي)', 'Direct Showroom Sales', 1),
    (@TenantID, @CompanyID, 'CH-FLD', N'المندوبين الميدانيين (الجوال)', 'Field Sales Representatives', 1),
    (@TenantID, @CompanyID, 'CH-WEB', N'المتجر الإلكتروني والمنصة', 'E-Commerce Online Portal', 1),
    (@TenantID, @CompanyID, 'CH-B2B', N'عقود الشركات والمناقصات B2B', 'Corporate B2B Contracts', 1);

    DECLARE @ChannelActions TABLE (ActionType VARCHAR(10));

    MERGE INTO dbo.SalesChannels WITH (TABLOCKX) AS Target
    USING @RawChannels AS Source
    ON (Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.ChannelCode = Source.ChannelCode)
    
    WHEN MATCHED AND (
        Target.ChannelNameAR <> Source.ChannelNameAR OR
        Target.ChannelNameEN <> Source.ChannelNameEN OR
        Target.IsActive      <> Source.IsActive
    ) THEN
        UPDATE SET 
            Target.ChannelNameAR = Source.ChannelNameAR,
            Target.ChannelNameEN = Source.ChannelNameEN,
            Target.IsActive      = Source.IsActive,
            Target.UpdatedBy     = @CreatedBy,
            Target.UpdatedAt     = SYSDATETIME()

    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, ChannelCode, ChannelNameAR, ChannelNameEN, IsActive, CreatedBy, CreatedAt)
        VALUES (Source.TenantID, Source.CompanyID, Source.ChannelCode, Source.ChannelNameAR, Source.ChannelNameEN, Source.IsActive, @CreatedBy, SYSDATETIME())
    
    OUTPUT $action INTO @ChannelActions;

    -- ══════════════════════════════════════════════════════════════════════════
    -- 3. تقارير القياس ومقاييس التنفيذ (Metrics Summary)
    -- ══════════════════════════════════════════════════════════════════════════
    DECLARE @CatIns INT = (SELECT COUNT(*) FROM @CustCatActions WHERE ActionType = 'INSERT');
    DECLARE @CatUpd INT = (SELECT COUNT(*) FROM @CustCatActions WHERE ActionType = 'UPDATE');
    DECLARE @ChnIns INT = (SELECT COUNT(*) FROM @ChannelActions WHERE ActionType = 'INSERT');
    DECLARE @ChnUpd INT = (SELECT COUNT(*) FROM @ChannelActions WHERE ActionType = 'UPDATE');

    RAISERROR(N'📊 [METRICS] PartnerCategories -> Inserted: %d, Updated: %d | SalesChannels -> Inserted: %d, Updated: %d', 0, 1, @CatIns, @CatUpd, @ChnIns, @ChnUpd) WITH NOWAIT;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Unified Partner & CRM Pipeline executed successfully.', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(N'🔄 [ROLLBACK] Transaction rolled back safely.', 0, 1) WITH NOWAIT;
    END

    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();

    RAISERROR(N'❌ [FATAL ERROR] CRM Pipeline Failed: %s', @ErrorSeverity, @ErrorState, @ErrorMessage);
END CATCH;
GO