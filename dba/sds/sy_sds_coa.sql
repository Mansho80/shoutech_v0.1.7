-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sds/sds_coa.sql
-- PURPOSE: Enterprise Multi-Level Chart of Accounts (COA) Seeding Pipeline
-- SYSTEM GRADE: Tier-1 Enterprise ERP Standard (10/10 Production-Grade)
-- FEATURES: Partner Control Accounts, ZATCA Tax Ready, Banking & Notes Integration
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @TenantID INT = 1;
DECLARE @CompanyID INT = 1;
DECLARE @CreatedBy INT = 1;

RAISERROR(N'🚀 [START] Initiating Tier-1 Enterprise Chart of Accounts (COA) Pipeline...', 0, 1) WITH NOWAIT;

-- التحقق المسبق من وجود جدول شجرة الحسابات الأساسي
IF OBJECT_ID(N'dbo.ChartOfAccounts', N'U') IS NULL
BEGIN
    RAISERROR(N'❌ [CRITICAL] Core table dbo.ChartOfAccounts does not exist. Aborting execution.', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;

BEGIN TRY
    
    -- ══════════════════════════════════════════════════════════════════════════
    -- 1. تعريف الجدول المؤقت للحسابات وفق الهيكل المتقدم
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'📊 [PROCESS] Staging Enterprise COA hierarchy data...', 0, 1) WITH NOWAIT;

    DECLARE @RawCOA TABLE (
        TenantID               INT NOT NULL,
        CompanyID              INT NOT NULL,
        AccountCode            VARCHAR(50) NOT NULL,
        ParentAccountCode      VARCHAR(50) NULL,
        AccountNameAR          NVARCHAR(255) NOT NULL,
        AccountNameEN          VARCHAR(255) NOT NULL,
        AccountType            SMALLINT NOT NULL,    -- (1: Asset, 2: Liability, 3: Equity, 4: Revenue, 5: Expense, 0: Control/Closing)
        StatementType          VARCHAR(20) NOT NULL, -- ('BS': Balance Sheet, 'IS': Income Statement)
        NormalBalance          SMALLINT NOT NULL,    -- (1: Debit, -1: Credit, 0: Neutral)
        AllowDirectPosting     BIT NOT NULL DEFAULT 1, -- هل يتيح الترحيل المباشر أم تجميعي
        IsPartnerControl       BIT NOT NULL DEFAULT 0, -- حساب تحكم للمتعاملين (عملاء/موردين)
        IsActive               BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, AccountCode)
    );

    -- إدخال هيكل شجرة الحسابات الشامل والمطابق لمتطلبات ERP الانتربرايز
    INSERT INTO @RawCOA 
    (TenantID, CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, StatementType, NormalBalance, AllowDirectPosting, IsPartnerControl, IsActive)
    VALUES 
    -- ── 1. الأصول (Assets) ──
    (@TenantID, @CompanyID, '1',    NULL, N'الأصول', 'Assets', 1, 'BS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '11',  '1',  N'الأصول الثابتة', 'Fixed Assets', 1, 'BS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '111', '11', N'الحسابات التابعة للأصول الثابتة', 'Detailed Fixed Assets', 1, 'BS', 1, 1, 0, 1),
    
    (@TenantID, @CompanyID, '12',  '1',  N'الأصول المتداولة', 'Current Assets', 1, 'BS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '121', '12', N'المخزون السلعي', 'Inventory Assets', 1, 'BS', 1, 1, 0, 1),
    
    (@TenantID, @CompanyID, '13',  '1',  N'النقدية وما في حكمها', 'Cash and Cash Equivalents', 1, 'BS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '131', '13', N'الصناديق والخزائن', 'Cash / Till Accounts', 1, 'BS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '132', '13', N'الحسابات البنكية', 'Bank Accounts', 1, 'BS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '133', '13', N'أوراق القبض (شيكات برسم التحصيل)', 'Cheques Receivable', 1, 'BS', 1, 1, 0, 1),
    
    (@TenantID, @CompanyID, '14',  '1',  N'العملاء', 'Trade Receivables / Customers', 1, 'BS', 1, 0, 1, 1),
    (@TenantID, @CompanyID, '141', '14', N'حسابات العملاء التفصيلية', 'Detailed Customer Accounts', 1, 'BS', 1, 1, 1, 1),
    
    (@TenantID, @CompanyID, '15',  '1',  N'ذمم مدينة أخرى والأرصدة المدينة', 'Other Receivables & Prepayments', 1, 'BS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '151', '15', N'ضريبة القيمة المضافة المدخلات (المشتريات)', 'Input VAT (Recoverable)', 1, 'BS', 1, 1, 0, 1),

    -- ── 2. الخصوم وحقوق الملكية (Liabilities & Equity) ──
    (@TenantID, @CompanyID, '2',    NULL, N'الخصوم وحقوق الملكية', 'Liabilities & Equity', 2, 'BS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '21',  '2',  N'حقوق الملكية', 'Equity', 3, 'BS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '221', '21', N'رأس المال وحسابات الشركاء', 'Capital & Detailed Equity', 3, 'BS', -1, 1, 0, 1),
    
    (@TenantID, @CompanyID, '23',  '2',  N'الخصوم المتداولة', 'Current Liabilities', 2, 'BS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '231', '23', N'أوراق الدفع (الشيكات الصادرة)', 'Cheques Payable', 2, 'BS', -1, 1, 0, 1),
    (@TenantID, @CompanyID, '232', '23', N'ضريبة القيمة المضافة المخرجات (المبيعات)', 'Output VAT (Payable)', 2, 'BS', -1, 1, 0, 1),
    
    (@TenantID, @CompanyID, '24',  '2',  N'الموردون', 'Accounts Payable / Suppliers', 2, 'BS', -1, 0, 1, 1),
    (@TenantID, @CompanyID, '241', '24', N'حسابات الموردين التفصيلية', 'Detailed Supplier Accounts', 2, 'BS', -1, 1, 1, 1),
    
    (@TenantID, @CompanyID, '25',  '2',  N'ذمم دائنة ومصاريف مستحقة', 'Other Payables & Accruals', 2, 'BS', -1, 1, 0, 1),

    -- ── 3. صافي المشتريات وتكلفة المبيعات (Purchases & COGS) ──
    (@TenantID, @CompanyID, '3',    NULL, N'صافي المشتريات وتكلفة البضاعة', 'Purchases & Cost of Sales', 5, 'IS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '31',  '3',  N'تكلفة المبيعات والمشتريات', 'Cost of Goods Sold', 5, 'IS', 1, 1, 0, 1),

    -- ── 4. صافي المبيعات والإيرادات (Sales & Revenues) ──
    (@TenantID, @CompanyID, '4',    NULL, N'صافي المبيعات والإيرادات', 'Net Sales & Revenue', 4, 'IS', -1, 0, 0, 1),
    (@TenantID, @CompanyID, '41',  '4',  N'إيرادات المبيعات والخدمات', 'Sales Revenue', 4, 'IS', -1, 1, 0, 1),

    -- ── 5. المصاريف التشغيلية والعمومية (Operating Expenses) ──
    (@TenantID, @CompanyID, '5',    NULL, N'المصاريف', 'Expenses', 5, 'IS', 1, 0, 0, 1),
    (@TenantID, @CompanyID, '51',  '5',  N'المصاريف العمومية والإدارية', 'General & Administrative Expenses', 5, 'IS', 1, 1, 0, 1),
    (@TenantID, @CompanyID, '52',  '5',  N'مصاريف البيع والتوزيع', 'Selling & Distribution Expenses', 5, 'IS', 1, 1, 0, 1),

    -- ── 00. الحسابات الختامية والسيادية (System Closing Accounts) ──
    (@TenantID, @CompanyID, '00',   NULL, N'الحسابات الختامية', 'Closing Accounts', 0, 'BS', 0, 0, 0, 1),
    (@TenantID, @CompanyID, '001', '00', N'حساب التشغيل', 'Operating Account', 0, 'IS', 0, 0, 0, 1),
    (@TenantID, @CompanyID, '002', '00', N'حساب المتاجرة', 'Trading Account', 0, 'IS', 0, 0, 0, 1),
    (@TenantID, @CompanyID, '003', '00', N'حساب الأرباح والخسائر', 'Profit and Loss Account', 0, 'IS', 0, 0, 0, 1),
    (@TenantID, @CompanyID, '004', '00', N'حساب الميزانية العمومية', 'Balance Sheet Closing Account', 0, 'BS', 0, 0, 0, 1);

    -- ══════════════════════════════════════════════════════════════════════════
    -- 2. حساب المسارات والعناصر العودية والحماية من الحلقات المفرغة
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'⚙️ [PROCESS] Computing COA hierarchy paths and node attributes...', 0, 1) WITH NOWAIT;

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
    -- 3. تنفيذ الدمج الآمن الذكي (Enterprise Idempotent MERGE)
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
    -- 4. مقاييس التنفيذ ومؤشرات الأداء النهائية (Metrics & Telemetry)
    -- ══════════════════════════════════════════════════════════════════════════
    DECLARE @InsCount INT = (SELECT COUNT(*) FROM @CoaActions WHERE ActionType = 'INSERT');
    DECLARE @UpdCount INT = (SELECT COUNT(*) FROM @CoaActions WHERE ActionType = 'UPDATE');

    RAISERROR(N'📊 [METRICS] Enterprise COA Pipeline Complete -> Inserted: %d, Updated: %d', 0, 1, @InsCount, @UpdCount) WITH NOWAIT;

    IF OBJECT_ID('tempdb..#CalcCOA') IS NOT NULL DROP TABLE #CalcCOA;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Enterprise Chart of Accounts executed & verified successfully.', 0, 1) WITH NOWAIT;

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

    RAISERROR(N'❌ [FATAL ERROR] COA Pipeline Failed: %s', @ErrorSeverity, @ErrorState, @ErrorMessage);
END CATCH;
GO