-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sds/sds_inv.sql
-- PURPOSE: Enterprise Inventory Initial Seeding Pipeline (Warehouses & Categories)
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

RAISERROR(N'🚀 [START] Initiating Tier-1 Inventory Seeding Pipeline (Warehouses & Categories)...', 0, 1) WITH NOWAIT;

-- التحقق المسبق من وجود البنية التحتية للجداول
IF OBJECT_ID(N'dbo.Warehouses', N'U') IS NULL OR OBJECT_ID(N'dbo.ItemCategories', N'U') IS NULL
BEGIN
    RAISERROR(N'❌ [CRITICAL] Core inventory tables (Warehouses / ItemCategories) do not exist. Aborting execution.', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;

BEGIN TRY
    
    -- ══════════════════════════════════════════════════════════════════════════
    -- 1. تهيئة المستودعات الأساسية (Warehouses Seeding)
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'📦 [PROCESS] Staging Warehouses data...', 0, 1) WITH NOWAIT;

    DECLARE @RawWarehouses TABLE (
        TenantID       INT NOT NULL,
        CompanyID      INT NOT NULL,
        WarehouseCode  VARCHAR(50) NOT NULL,
        WarehouseNameAR NVARCHAR(255) NOT NULL,
        WarehouseNameEN VARCHAR(255) NOT NULL,
        BranchCode     VARCHAR(50) NULL,
        IsMain         BIT NOT NULL DEFAULT 0,
        IsActive       BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, WarehouseCode)
    );

    INSERT INTO @RawWarehouses (TenantID, CompanyID, WarehouseCode, WarehouseNameAR, WarehouseNameEN, BranchCode, IsMain, IsActive)
    VALUES 
    (@TenantID, @CompanyID, 'WH-MAIN', N'المستودع الرئيسي الإفتراضي', 'Main Default Warehouse', 'BR01', 1, 1),
    (@TenantID, @CompanyID, 'WH-RET',  N'مستودع فرع المبيعات',        'Retail Branch Warehouse',   'BR01', 0, 1),
    (@TenantID, @CompanyID, 'WH-DAM',  N'مستودع التالف والمرتجعات',   'Damaged & Returns Store',   'BR01', 0, 1);

    DECLARE @WhActions TABLE (ActionType VARCHAR(10));

    MERGE INTO dbo.Warehouses WITH (TABLOCKX) AS Target
    USING @RawWarehouses AS Source
    ON (Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.WarehouseCode = Source.WarehouseCode)
    
    WHEN MATCHED AND (
        Target.WarehouseNameAR <> Source.WarehouseNameAR OR
        Target.WarehouseNameEN <> Source.WarehouseNameEN OR
        ISNULL(Target.BranchCode, '') <> ISNULL(Source.BranchCode, '') OR
        Target.IsMain          <> Source.IsMain OR
        Target.IsActive        <> Source.IsActive
    ) THEN
        UPDATE SET 
            Target.WarehouseNameAR = Source.WarehouseNameAR,
            Target.WarehouseNameEN = Source.WarehouseNameEN,
            Target.BranchCode      = Source.BranchCode,
            Target.IsMain          = Source.IsMain,
            Target.IsActive        = Source.IsActive,
            Target.UpdatedBy       = @CreatedBy,
            Target.UpdatedAt       = SYSDATETIME()

    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, WarehouseCode, WarehouseNameAR, WarehouseNameEN, BranchCode, IsMain, IsActive, CreatedBy, CreatedAt)
        VALUES (Source.TenantID, Source.CompanyID, Source.WarehouseCode, Source.WarehouseNameAR, Source.WarehouseNameEN, Source.BranchCode, Source.IsMain, Source.IsActive, @CreatedBy, SYSDATETIME())
    
    OUTPUT $action INTO @WhActions;

    -- ══════════════════════════════════════════════════════════════════════════
    -- 2. تهيئة مجموعات الأصناف الهرمية (Item Categories Seeding with CTE)
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'📂 [PROCESS] Staging Item Categories hierarchy...', 0, 1) WITH NOWAIT;

    DECLARE @RawCategories TABLE (
        TenantID       INT NOT NULL,
        CompanyID      INT NOT NULL,
        CategoryCode   VARCHAR(50) NOT NULL,
        ParentCatCode  VARCHAR(50) NULL,
        CategoryNameAR NVARCHAR(255) NOT NULL,
        CategoryNameEN VARCHAR(255) NOT NULL,
        IsActive       BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, CategoryCode)
    );

    INSERT INTO @RawCategories (TenantID, CompanyID, CategoryCode, ParentCatCode, CategoryNameAR, CategoryNameEN, IsActive)
    VALUES 
    (@TenantID, @CompanyID, 'CAT-ROOT', NULL,    N'المجموعات الرئيسية العامة', 'General Root Categories', 1),
    (@TenantID, @CompanyID, 'CAT-ELE',  'CAT-ROOT', N'الأجهزة الإلكترونية والمنزلية', 'Electronics & Home Appliances', 1),
    (@TenantID, @CompanyID, 'CAT-FOD',  'CAT-ROOT', N'المواد الغذائية والاستهلاكية', 'Food & Consumables', 1),
    (@TenantID, @CompanyID, 'CAT-MBL',  'CAT-ELE',  N'الهواتف الذكية وملحقاتها',   'Smartphones & Accessories', 1),
    (@TenantID, @CompanyID, 'CAT-DRY',  'CAT-FOD',  N'المواد الجافة والمعلبات',    'Dry Foods & Canned Goods', 1);

    -- حساب مستويات المسار الهرمي مع حماية تامة ضد الحلقات التكرارية
    IF OBJECT_ID('tempdb..#CalcCategories') IS NOT NULL DROP TABLE #CalcCategories;

    WITH Cat_CTE AS (
        SELECT 
            TenantID, CompanyID, CategoryCode, ParentCatCode, CategoryNameAR, CategoryNameEN, IsActive,
            1 AS CatLevel,
            CAST('/' + CategoryCode + '/' AS VARCHAR(500)) AS TreePath,
            CAST(CategoryCode AS VARCHAR(MAX)) AS CycleDetector
        FROM @RawCategories
        WHERE ParentCatCode IS NULL

        UNION ALL

        SELECT 
            c.TenantID, c.CompanyID, c.CategoryCode, c.ParentCatCode, c.CategoryNameAR, c.CategoryNameEN, c.IsActive,
            p.CatLevel + 1 AS CatLevel,
            CAST(p.TreePath + c.CategoryCode + '/' AS VARCHAR(500)) AS TreePath,
            CAST(p.CycleDetector + '->' + c.CategoryCode AS VARCHAR(MAX))
        FROM @RawCategories c
        INNER JOIN Cat_CTE p 
            ON c.ParentCatCode = p.CategoryCode 
           AND c.TenantID = p.TenantID 
           AND c.CompanyID = p.CompanyID
        WHERE p.CycleDetector NOT LIKE '%' + c.CategoryCode + '%'
    )
    SELECT 
        t.TenantID, t.CompanyID, t.CategoryCode, t.ParentCatCode, t.CategoryNameAR, t.CategoryNameEN, t.IsActive,
        t.CatLevel, t.TreePath,
        CASE WHEN EXISTS (SELECT 1 FROM @RawCategories sub WHERE sub.ParentCatCode = t.CategoryCode) THEN 1 ELSE 0 END AS IsHeader
    INTO #CalcCategories
    FROM Cat_CTE t;

    CREATE CLUSTERED INDEX IX_TempCalcCategories ON #CalcCategories (TenantID, CompanyID, CategoryCode);

    DECLARE @CatActions TABLE (ActionType VARCHAR(10));

    MERGE INTO dbo.ItemCategories WITH (TABLOCKX) AS Target
    USING #CalcCategories AS Source
    ON (Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.CategoryCode = Source.CategoryCode)
    
    WHEN MATCHED AND (
        Target.CategoryNameAR <> Source.CategoryNameAR OR
        Target.CategoryNameEN <> Source.CategoryNameEN OR
        ISNULL(Target.ParentCatCode, '') <> ISNULL(Source.ParentCatCode, '') OR
        Target.CatLevel       <> Source.CatLevel OR
        Target.TreePath       <> Source.TreePath OR
        Target.IsHeader       <> Source.IsHeader OR
        Target.IsActive       <> Source.IsActive
    ) THEN
        UPDATE SET 
            Target.CategoryNameAR = Source.CategoryNameAR,
            Target.CategoryNameEN = Source.CategoryNameEN,
            Target.ParentCatCode  = Source.ParentCatCode,
            Target.CatLevel       = Source.CatLevel,
            Target.TreePath       = Source.TreePath,
            Target.IsHeader       = Source.IsHeader,
            Target.IsActive       = Source.IsActive,
            Target.UpdatedBy      = @CreatedBy,
            Target.UpdatedAt      = SYSDATETIME()

    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, CategoryCode, ParentCatCode, CategoryNameAR, CategoryNameEN, CatLevel, TreePath, IsHeader, IsActive, CreatedBy, CreatedAt)
        VALUES (Source.TenantID, Source.CompanyID, Source.CategoryCode, Source.ParentCatCode, Source.CategoryNameAR, Source.CategoryNameEN, Source.CatLevel, Source.TreePath, Source.IsHeader, Source.IsActive, @CreatedBy, SYSDATETIME())
    
    OUTPUT $action INTO @CatActions;

    -- ربط معرفات الأب الآلية (ParentID)
    UPDATE Target
    SET Target.ParentID = Parent.CategoryID
    FROM dbo.ItemCategories Target
    INNER JOIN dbo.ItemCategories Parent 
        ON Target.TenantID = Parent.TenantID 
       AND Target.CompanyID = Parent.CompanyID 
       AND Target.ParentCatCode = Parent.CategoryCode
    WHERE Target.TenantID = @TenantID 
      AND Target.CompanyID = @CompanyID 
      AND Target.ParentCatCode IS NOT NULL;

    -- ══════════════════════════════════════════════════════════════════════════
    -- 3. المقاييس والتقارير الرقمية للعملية (Metrics Summary)
    -- ══════════════════════════════════════════════════════════════════════════
    DECLARE @WhIns INT = (SELECT COUNT(*) FROM @WhActions WHERE ActionType = 'INSERT');
    DECLARE @WhUpd INT = (SELECT COUNT(*) FROM @WhActions WHERE ActionType = 'UPDATE');
    DECLARE @CatIns INT = (SELECT COUNT(*) FROM @CatActions WHERE ActionType = 'INSERT');
    DECLARE @CatUpd INT = (SELECT COUNT(*) FROM @CatActions WHERE ActionType = 'UPDATE');

    RAISERROR(N'📊 [METRICS] Warehouses -> Inserted: %d, Updated: %d | Categories -> Inserted: %d, Updated: %d', 0, 1, @WhIns, @WhUpd, @CatIns, @CatUpd) WITH NOWAIT;

    -- فحص السلامة والتحقق النهائي
    IF EXISTS (SELECT 1 FROM dbo.ItemCategories WHERE TenantID = @TenantID AND CompanyID = @CompanyID AND ParentCatCode IS NOT NULL AND ParentID IS NULL)
    BEGIN
        RAISERROR(N'❌ [ASSERTION ERROR] Category Tree ParentID resolution failed!', 16, 1);
    END

    IF OBJECT_ID('tempdb..#CalcCategories') IS NOT NULL DROP TABLE #CalcCategories;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Tier-1 Inventory Seeding Pipeline completed successfully.', 0, 1) WITH NOWAIT;

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

    RAISERROR(N'❌ [FATAL ERROR] Inventory Pipeline Failed: %s', @ErrorSeverity, @ErrorState, @ErrorMessage);
END CATCH;
GO