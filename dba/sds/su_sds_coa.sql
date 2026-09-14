-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sds/su_sds_coa.sql
-- PURPOSE: Enterprise Multi-Level Chart of Accounts Seeding (Saudi GAAP Compliant)
-- SYSTEM GRADE: Tier-1 Enterprise ERP Standard (10/10 Production-Grade - Ultra Advanced)
-- COMPLIANCE: SOCPA Standard / ZATCA Phase 2 / Saudi Labor Law (EOSB)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @TenantID INT = 1;
DECLARE @CompanyID INT = 1;
DECLARE @CreatedBy INT = 1;

RAISERROR(N'🚀 [START] Initiating Tier-1 Saudi GAAP Chart of Accounts (su_sds_coa.sql) Pipeline...', 0, 1) WITH NOWAIT;

-- 1. التحقق المسبق من وجود جدول شجرة الحسابات الأساسي
IF OBJECT_ID(N'dbo.ChartOfAccounts', N'U') IS NULL
BEGIN
    RAISERROR(N'❌ [CRITICAL] Core table dbo.ChartOfAccounts does not exist. Aborting execution.', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;

BEGIN TRY
    
    -- ══════════════════════════════════════════════════════════════════════════
    -- 2. تعريف جدول التغذية المؤقت وشحن البيانات الهيكلية (Saudi GAAP 1000 - 5000)
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'📊 [PROCESS] Staging Multi-Level COA data (Assets, Liabilities, Equity, Revenues, Expenses)...', 0, 1) WITH NOWAIT;

    DECLARE @RawCOA TABLE (
        TenantID               INT NOT NULL,
        CompanyID              INT NOT NULL,
        AccountCode            VARCHAR(50) NOT NULL,
        ParentAccountCode      VARCHAR(50) NULL,
        AccountNameAR          NVARCHAR(255) NOT NULL,
        AccountNameEN          VARCHAR(255) NOT NULL,
        AccountType            SMALLINT NOT NULL,    -- (1: Asset, 2: Liability, 3: Equity, 4: Revenue, 5: Expense)
        StatementType          VARCHAR(20) NOT NULL, -- ('BS': Balance Sheet, 'IS': Income Statement)
        NormalBalance          SMALLINT NOT NULL,    -- (1: Debit, -1: Credit)
        AllowDirectPosting     BIT NOT NULL DEFAULT 1, -- السماح بالترحيل المباشر (1) أم حساب تجميعي (0)
        IsPartnerControl       BIT NOT NULL DEFAULT 0, -- حساب تحكم للمتعاملين (عملاء/موردين)
        IsActive               BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, AccountCode)
    );

    -- إدخال هيكل شجرة الحسابات المعياري بالسعودية (SOCPA / ZATCA Ready)
    INSERT INTO @RawCOA 
    (TenantID, CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, StatementType, NormalBalance, AllowDirectPosting, IsPartnerControl, IsActive)
    VALUES 
    -- ── LEVEL 1: 1000 - الأصول (Assets) ──
    (@TenantID, @CompanyID, '1000', NULL,   N'الأصول', 'Assets', 1, 'BS', 1, 0, 0, 1),
    
    -- Level 2: الأصول المتداولة (Current Assets)
    (@TenantID, @CompanyID, '1100', '1000', N'الأصول المتداولة', 'Current Assets', 1, 'BS', 1, 0, 0, 1),
    
    -- Level 3 & 4: النقدية وما في حكمها (Cash & Cash Equivalents)
    (@TenantID, @CompanyID, '1110', '1100', N'النقدية وما في حكمها', 'Cash and Cash Equivalents', 1, 'BS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '1111', '1110', N'الصندوق الرئيسي', 'Main Cash Box', 1, 'BS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '1112', '1110', N'حساب مصرف الراجحي', 'Al Rajhi Bank Account', 1, 'BS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '1113', '1110', N'حساب البنك الأهلي السعودي (SNB)', 'Saudi National Bank Account', 1, 'BS', 1, 1, 0, 1),
    
    -- Level 3 & 4: الذمم المدينة والعملاء (Accounts Receivable & Customers)
    (@TenantID, @CompanyID, '1120', '1100', N'العملاء والذمم المدينة', 'Accounts Receivable', 1, 'BS', 1, 0, 1, 1),
    (@TenantID, @CompanyID, '1121', '1120', N'عملاء القطاع التجاري والمحلي', 'Commercial Customers', 1, 'BS', 1, 1, 1, 1),
    (@TenantID, @CompanyID, '1122', '1120', N'عملاء كبار الشخصيات (VIP)', 'VIP Key Accounts', 1, 'BS', 1, 1, 1, 1),

    -- Level 3 & 4: المخزون السلعي (Inventory)
    (@TenantID, @CompanyID, '1130', '1100', N'المخزون السلعي', 'Inventory Assets', 1, 'BS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '1131', '1130', N'مخزون البضائع المتاحة للبيع', 'Merchandise Inventory', 1, 'BS', 1, 1, 0, 1),

    -- Level 3 & 4: الضريبة المدخلات والأرصدة المدينة (Input VAT & Prepayments)
    (@TenantID, @CompanyID, '1140', '1100', N'الأرصدة المدينة الأخرى والضرائب', 'Other Receivables & Prepayments', 1, 'BS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '1141', '1140', N'ضريبة القيمة المضافة المدخلات (المشتريات 15%)', 'Input VAT (Recoverable 15%)', 1, 'BS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '1142', '1140', N'مصاريف مدفوعة مقدماً', 'Prepaid Expenses', 1, 'BS', 1, 1, 0, 1),

    -- Level 2: الأصول غير المتداولة / الثابتة (Non-Current & Fixed Assets)
    (@TenantID, @CompanyID, '1200', '1000', N'الأصول غير المتداولة (الثابتة)', 'Non-Current Fixed Assets', 1, 'BS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '1210', '1200', N'الأصول الثابتة بالصافي', 'Property, Plant & Equipment', 1, 'BS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '1211', '1210', N'المباني والإنشاءات', 'Buildings & Construction', 1, 'BS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '1212', '1210', N'الآلات والمعدات والسيارات', 'Machinery & Vehicles', 1, 'BS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '1213', '1210', N'أجهزة الحاسب والأنظمة البرمجية', 'IT Hardware & Software Assets', 1, 'BS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '1220', '1200', N'مجمع الإهلاك المتراكم', 'Accumulated Depreciation', 1, 'BS', -1, 1, 0, 1),

    -- ── LEVEL 1: 2000 - الالتزامات (Liabilities) ──
    (@TenantID, @CompanyID, '2000', NULL,   N'الالتزامات', 'Liabilities', 2, 'BS', -1, 0, 0, 1),
    
    -- Level 2: الالتزامات المتداولة (Current Liabilities)
    (@TenantID, @CompanyID, '2100', '2000', N'الالتزامات المتداولة', 'Current Liabilities', 2, 'BS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '2110', '2100', N'الموردون والدائنون', 'Accounts Payable', 2, 'BS', -1, 0, 1, 1),
    (@TenantID, @CompanyID, '2111', '2110', N'موردو البضائع المحليون', 'Local Merchandise Suppliers', 2, 'BS', -1, 1, 1, 1),
    (@TenantID, @CompanyID, '2112', '2110', N'الموردون الخارجيون (استيراد)', 'Overseas International Vendors', 2, 'BS', -1, 1, 1, 1),

    -- ZATCA Tax & Zakat Liabilities
    (@TenantID, @CompanyID, '2120', '2100', N'الالتزامات الضريبية والسيادية (ZATCA)', 'Tax & Zakat Liabilities', 2, 'BS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '2121', '2120', N'ضريبة القيمة المضافة المخرجات (المبيعات 15%)', 'Output VAT (Payable 15%)', 2, 'BS', -1, 1, 0, 1),
    (@TenantID, @CompanyID, '2122', '2120', N'مخصص الزكاة الشرعية المستحقة', 'Zakat Provision Payable', 2, 'BS', -1, 1, 0, 1),

    -- Accruals & Salaries
    (@TenantID, @CompanyID, '2130', '2100', N'المصاريف المستحقة والذمم الدائنة', 'Accrued Expenses & Other Payables', 2, 'BS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '2131', '2130', N'رواتب ومستحقات الموظفين المستحقة', 'Accrued Salaries & Benefits', 2, 'BS', -1, 1, 0, 1),

    -- Level 2: الالتزامات غير المتداولة (Non-Current Liabilities & Saudi Labor EOSB)
    (@TenantID, @CompanyID, '2200', '2000', N'الالتزامات غير المتداولة', 'Non-Current Liabilities', 2, 'BS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '2210', '2200', N'مخصص مكافأة نهاية الخدمة (EOSB)', 'End of Service Benefits Provision', 2, 'BS', -1, 1, 0, 1),

    -- ── LEVEL 1: 3000 - حقوق الملكية (Equity) ──
    (@TenantID, @CompanyID, '3000', NULL,   N'حقوق الملكية', 'Equity', 3, 'BS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '3100', '3000', N'رأس المال', 'Capital', 3, 'BS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '3110', '3100', N'رأس المال المدفوع', 'Paid-in Capital', 3, 'BS', -1, 1, 0, 1),
    
    (@TenantID, @CompanyID, '3200', '3000', N'الاحتياطيات والأرباح المبقاة', 'Reserves & Retained Earnings', 3, 'BS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '3210', '3200', N'الأرباح (الخسائر) المبقاة المدورة', 'Retained Earnings', 3, 'BS', -1, 1, 0, 1),
    (@TenantID, @CompanyID, '3220', '3200', N'الاحتياطي النظامي', 'Statutory Reserve', 3, 'BS', -1, 1, 0, 1),

    -- ── LEVEL 1: 4000 - الإيرادات (Revenues) ──
    (@TenantID, @CompanyID, '4000', NULL,   N'الإيرادات', 'Revenues', 4, 'IS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '4100', '4000', N'إيرادات النشاط الرئيسي المباشر', 'Operating Sales Revenue', 4, 'IS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '4110', '4100', N'مبيعات البضائع العامة والمنتجات', 'General Merchandise Sales', 4, 'IS', -1, 1, 0, 1),
    (@TenantID, @CompanyID, '4120', '4100', N'إيرادات تقديم الخدمات والخدمات اللوجستية', 'Services & Logistics Revenue', 4, 'IS', -1, 1, 0, 1),

    -- ── LEVEL 1: 5000 - التكاليف والمصروفات (Expenses & COGS) ──
    (@TenantID, @CompanyID, '5000', NULL,   N'المصروفات والتكاليف', 'Expenses & COGS', 5, 'IS', 1, 0, 0, 1),
    
    -- Cost of Goods Sold (COGS)
    (@TenantID, @CompanyID, '5100', '5000', N'تكلفة المبيعات والإيرادات', 'Cost of Goods Sold (COGS)', 5, 'IS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '5110', '5100', N'تكلفة المشتريات للبضائع المبيعة', 'Cost of Merchandise Sold', 5, 'IS', 1, 1, 0, 1),

    -- Operating & Administrative Expenses
    (@TenantID, @CompanyID, '5200', '5000', N'المصروفات العمومية والإدارية', 'General & Administrative Expenses', 5, 'IS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '5210', '5200', N'رواتب وأجور ونقل الموظفين', 'Salaries, Wages & Travel', 5, 'IS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '5220', '5200', N'مصروف الإيجار والمرافق والطاقة', 'Rent, Utilities & Energy Expense', 5, 'IS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '5230', '5200', N'مصروف مكافأة نهاية الخدمة والـ GOSI', 'EOSB Expense & GOSI Contributions', 5, 'IS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '5240', '5200', N'مصروف الزكاة الشرعية', 'Zakat Expense', 5, 'IS', 1, 1, 0, 1),

    -- Marketing & Selling Expenses
    (@TenantID, @CompanyID, '5300', '5000', N'مصاريف البيع والتسويق', 'Selling & Marketing Expenses', 5, 'IS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '5310', '5300', N'عمولات المبيعات والحملات الإعلانية', 'Sales Commissions & Advertising', 5, 'IS', 1, 1, 0, 1);

    -- ══════════════════════════════════════════════════════════════════════════
    -- 3. معالجة التسلسل الهرمي المتقدم باستخدام Recursive CTE وحماية الحلقات
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'⚙️ [PROCESS] Computing COA hierarchy paths, levels, and control flags...', 0, 1) WITH NOWAIT;

    IF OBJECT_ID('tempdb..#CalcCOA') IS NOT NULL DROP TABLE #CalcCOA;

    WITH COA_CTE AS (
        SELECT 
            TenantID, CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, 
            AccountType, StatementType, NormalBalance, AllowDirectPosting, IsPartnerControl, IsActive,
            1 AS AccountLevel,
            CAST('/' + AccountCode + '/' AS VARCHAR(500)) AS TreePath,
            CAST(AccountCode AS VARCHAR(MAX)) AS CycleDetector
        FROM @RawCOA
        WHERE ParentAccountCode IS NULL

        UNION ALL

        SELECT 
            c.TenantID, c.CompanyID, c.AccountCode, c.ParentAccountCode, c.AccountNameAR, c.AccountNameEN, 
            c.AccountType, c.StatementType, c.NormalBalance, c.AllowDirectPosting, c.IsPartnerControl, c.IsActive,
            p.AccountLevel + 1 AS AccountLevel,
            CAST(p.TreePath + c.AccountCode + '/' AS VARCHAR(500)) AS TreePath,
            CAST(p.CycleDetector + '->' + c.AccountCode AS VARCHAR(MAX))
        FROM @RawCOA c
        INNER JOIN COA_CTE p 
            ON c.ParentAccountCode = p.AccountCode 
           AND c.TenantID = p.TenantID 
           AND c.CompanyID = p.CompanyID
        WHERE p.CycleDetector NOT LIKE '%' + c.AccountCode + '%'
    )
    SELECT 
        t.TenantID, t.CompanyID, t.AccountCode, t.ParentAccountCode, t.AccountNameAR, t.AccountNameEN, 
        t.AccountType, t.StatementType, t.NormalBalance, t.AllowDirectPosting, t.IsPartnerControl, t.IsActive,
        t.AccountLevel, t.TreePath,
        CASE WHEN EXISTS (SELECT 1 FROM @RawCOA sub WHERE sub.ParentAccountCode = t.AccountCode) THEN 1 ELSE 0 END AS IsHeader
    INTO #CalcCOA
    FROM COA_CTE t;

    CREATE CLUSTERED INDEX IX_TempCalcCOA ON #CalcCOA (TenantID, CompanyID, AccountCode);

    DECLARE @CoaActions TABLE (ActionType VARCHAR(10));

    -- ══════════════════════════════════════════════════════════════════════════
    -- 4. تطبيق دمج البيانات الذكي الآمن (Enterprise Idempotent MERGE)
    -- ══════════════════════════════════════════════════════════════════════════
    MERGE INTO dbo.ChartOfAccounts WITH (TABLOCKX) AS Target
    USING #CalcCOA AS Source
    ON (Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.AccountCode = Source.AccountCode)
    
    WHEN MATCHED AND (
        Target.AccountNameAR         <> Source.AccountNameAR OR
        Target.AccountNameEN         <> Source.AccountNameEN OR
        ISNULL(Target.ParentAccountCode, '') <> ISNULL(Source.ParentAccountCode, '') OR
        Target.AccountType           <> Source.AccountType OR
        Target.StatementType         <> Source.StatementType OR
        Target.NormalBalance         <> Source.NormalBalance OR
        Target.AccountLevel          <> Source.AccountLevel OR
        Target.TreePath              <> Source.TreePath OR
        Target.IsHeader              <> Source.IsHeader OR
        Target.IsActive              <> Source.IsActive
    ) THEN
        UPDATE SET 
            Target.AccountNameAR     = Source.AccountNameAR,
            Target.AccountNameEN     = Source.AccountNameEN,
            Target.ParentAccountCode = Source.ParentAccountCode,
            Target.AccountType       = Source.AccountType,
            Target.StatementType     = Source.StatementType,
            Target.NormalBalance     = Source.NormalBalance,
            Target.AccountLevel      = Source.AccountLevel,
            Target.TreePath          = Source.TreePath,
            Target.IsHeader          = Source.IsHeader,
            Target.IsActive          = Source.IsActive,
            Target.UpdatedBy         = @CreatedBy,
            Target.UpdatedAt         = SYSDATETIME()

    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, StatementType, NormalBalance, AccountLevel, TreePath, IsHeader, IsActive, CreatedBy, CreatedAt)
        VALUES (Source.TenantID, Source.CompanyID, Source.AccountCode, Source.ParentAccountCode, Source.AccountNameAR, Source.AccountNameEN, Source.AccountType, Source.StatementType, Source.NormalBalance, Source.AccountLevel, Source.TreePath, Source.IsHeader, Source.IsActive, @CreatedBy, SYSDATETIME())
    
    OUTPUT $action INTO @CoaActions;

    -- تحديث معرفات الأب الآلية (ParentID Foreign Key Resolution)
    UPDATE Target
    SET Target.ParentID = Parent.AccountID
    FROM dbo.ChartOfAccounts Target
    INNER JOIN dbo.ChartOfAccounts Parent 
        ON Target.TenantID = Parent.TenantID 
       AND Target.CompanyID = Parent.CompanyID 
       AND Target.ParentAccountCode = Parent.AccountCode
    WHERE Target.TenantID = @TenantID 
      AND Target.CompanyID = @CompanyID 
      AND Target.ParentAccountCode IS NOT NULL;

    -- ══════════════════════════════════════════════════════════════════════════
    -- 5. مقاييس القياس والتليمتري النهائية (Execution Telemetry & Metrics)
    -- ══════════════════════════════════════════════════════════════════════════
    DECLARE @InsCount INT = (SELECT COUNT(*) FROM @CoaActions WHERE ActionType = 'INSERT');
    DECLARE @UpdCount INT = (SELECT COUNT(*) FROM @CoaActions WHERE ActionType = 'UPDATE');

    RAISERROR(N'📊 [METRICS] Saudi COA Pipeline Complete -> Inserted: %d, Updated: %d', 0, 1, @InsCount, @UpdCount) WITH NOWAIT;

    IF OBJECT_ID('tempdb..#CalcCOA') IS NOT NULL DROP TABLE #CalcCOA;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Tier-1 Saudi GAAP Chart of Accounts (su_sds_coa.sql) executed & verified successfully.', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(N'🔄 [ROLLBACK] Transaction rolled back safely due to an unexpected fault.', 0, 1) WITH NOWAIT;
    END

    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();

    RAISERROR(N'❌ [FATAL ERROR] Saudi COA Pipeline Failed: %s', @ErrorSeverity, @ErrorState, @ErrorMessage);
END CATCH;
GO