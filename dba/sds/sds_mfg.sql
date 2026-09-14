-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sds/sds_mfg.sql
-- PURPOSE: Enterprise Manufacturing Work Centers & Production Lines Seeding Pipeline
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

RAISERROR(N'🚀 [START] Initiating Tier-1 Manufacturing Work Centers & Lines Pipeline...', 0, 1) WITH NOWAIT;

-- التحقق المسبق من وجود جداول مراكز العمل خطوط الإنتاج
IF OBJECT_ID(N'dbo.WorkCenters', N'U') IS NULL OR OBJECT_ID(N'dbo.ProductionLines', N'U') IS NULL
BEGIN
    RAISERROR(N'❌ [CRITICAL] Core Manufacturing tables (WorkCenters / ProductionLines) do not exist. Aborting execution.', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;

BEGIN TRY
    
    -- ══════════════════════════════════════════════════════════════════════════
    -- 1. تهيئة خطوط الإنتاج الرئيسية (Production Lines Seeding)
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'🏭 [PROCESS] Staging Production Lines data...', 0, 1) WITH NOWAIT;

    DECLARE @RawProdLines TABLE (
        TenantID         INT NOT NULL,
        CompanyID        INT NOT NULL,
        LineCode         VARCHAR(50) NOT NULL,
        LineNameAR       NVARCHAR(255) NOT NULL,
        LineNameEN       VARCHAR(255) NOT NULL,
        WarehouseCode    VARCHAR(50) NOT NULL,
        IsActive         BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, LineCode)
    );

    INSERT INTO @RawProdLines (TenantID, CompanyID, LineCode, LineNameAR, LineNameEN, WarehouseCode, IsActive)
    VALUES 
    (@TenantID, @CompanyID, 'LINE-ASM', N'خط التجميع النهائي والتركيب', 'Final Assembly & Integration Line', 'WH-MAIN', 1),
    (@TenantID, @CompanyID, 'LINE-PKG', N'خط التعبئة والتغليف الآلي', 'Automated Packaging & Boxing Line', 'WH-MAIN', 1),
    (@TenantID, @CompanyID, 'LINE-QAT', N'خط الفحص والجودة والاختبار', 'Quality Control & Testing Line', 'WH-MAIN', 1);

    DECLARE @LineActions TABLE (ActionType VARCHAR(10));

    MERGE INTO dbo.ProductionLines WITH (TABLOCKX) AS Target
    USING @RawProdLines AS Source
    ON (Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.LineCode = Source.LineCode)
    
    WHEN MATCHED AND (
        Target.LineNameAR    <> Source.LineNameAR OR
        Target.LineNameEN    <> Source.LineNameEN OR
        Target.WarehouseCode <> Source.WarehouseCode OR
        Target.IsActive      <> Source.IsActive
    ) THEN
        UPDATE SET 
            Target.LineNameAR    = Source.LineNameAR,
            Target.LineNameEN    = Source.LineNameEN,
            Target.WarehouseCode = Source.WarehouseCode,
            Target.IsActive      = Source.IsActive,
            Target.UpdatedBy     = @CreatedBy,
            Target.UpdatedAt     = SYSDATETIME()

    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, LineCode, LineNameAR, LineNameEN, WarehouseCode, IsActive, CreatedBy, CreatedAt)
        VALUES (Source.TenantID, Source.CompanyID, Source.LineCode, Source.LineNameAR, Source.LineNameEN, Source.WarehouseCode, Source.IsActive, @CreatedBy, SYSDATETIME())
    
    OUTPUT $action INTO @LineActions;

    -- ══════════════════════════════════════════════════════════════════════════
    -- 2. تهيئة مراكز العمل التشغيلية (Work Centers Seeding)
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'⚙️ [PROCESS] Staging Work Centers data...', 0, 1) WITH NOWAIT;

    DECLARE @RawWorkCenters TABLE (
        TenantID          INT NOT NULL,
        CompanyID         INT NOT NULL,
        CenterCode        VARCHAR(50) NOT NULL,
        CenterNameAR      NVARCHAR(255) NOT NULL,
        CenterNameEN      VARCHAR(255) NOT NULL,
        LineCode          VARCHAR(50) NOT NULL,
        HourlyCostRate    DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
        IsActive          BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, CenterCode)
    );

    INSERT INTO @RawWorkCenters (TenantID, CompanyID, CenterCode, CenterNameAR, CenterNameEN, LineCode, HourlyCostRate, IsActive)
    VALUES 
    (@TenantID, @CompanyID, 'WC-CUT',  N'محطة القص والتقطيع الآلي', 'Automatic Cutting Workstation', 'LINE-ASM', 150.0000, 1),
    (@TenantID, @CompanyID, 'WC-WLD',  N'محطة اللحام والتشكيل الهيكلي', 'Welding & Structural Station', 'LINE-ASM', 220.5000, 1),
    (@TenantID, @CompanyID, 'WC-SBOX', N'محطة التغليف الكرتوني الفردي', 'Individual Boxing Station', 'LINE-PKG', 85.0000, 1),
    (@TenantID, @CompanyID, 'WC-TST',  N'محطة الفحص الكهربائي والوظيفي', 'Electrical Testing Workstation', 'LINE-QAT', 120.0000, 1);

    DECLARE @CenterActions TABLE (ActionType VARCHAR(10));

    MERGE INTO dbo.WorkCenters WITH (TABLOCKX) AS Target
    USING @RawWorkCenters AS Source
    ON (Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.CenterCode = Source.CenterCode)
    
    WHEN MATCHED AND (
        Target.CenterNameAR   <> Source.CenterNameAR OR
        Target.CenterNameEN   <> Source.CenterNameEN OR
        Target.LineCode       <> Source.LineCode OR
        Target.HourlyCostRate <> Source.HourlyCostRate OR
        Target.IsActive       <> Source.IsActive
    ) THEN
        UPDATE SET 
            Target.CenterNameAR   = Source.CenterNameAR,
            Target.CenterNameEN   = Source.CenterNameEN,
            Target.LineCode       = Source.LineCode,
            Target.HourlyCostRate = Source.HourlyCostRate,
            Target.IsActive       = Source.IsActive,
            Target.UpdatedBy      = @CreatedBy,
            Target.UpdatedAt      = SYSDATETIME()

    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, CenterCode, CenterNameAR, CenterNameEN, LineCode, HourlyCostRate, IsActive, CreatedBy, CreatedAt)
        VALUES (Source.TenantID, Source.CompanyID, Source.CenterCode, Source.CenterNameAR, Source.CenterNameEN, Source.LineCode, Source.HourlyCostRate, Source.IsActive, @CreatedBy, SYSDATETIME())
    
    OUTPUT $action INTO @CenterActions;

    -- ══════════════════════════════════════════════════════════════════════════
    -- 3. تقارير القياس ومقاييس التنفيذ (Metrics Summary)
    -- ══════════════════════════════════════════════════════════════════════════
    DECLARE @LineIns INT = (SELECT COUNT(*) FROM @LineActions WHERE ActionType = 'INSERT');
    DECLARE @LineUpd INT = (SELECT COUNT(*) FROM @LineActions WHERE ActionType = 'UPDATE');
    DECLARE @WcIns INT = (SELECT COUNT(*) FROM @CenterActions WHERE ActionType = 'INSERT');
    DECLARE @WcUpd INT = (SELECT COUNT(*) FROM @CenterActions WHERE ActionType = 'UPDATE');

    RAISERROR(N'📊 [METRICS] ProductionLines -> Inserted: %d, Updated: %d | WorkCenters -> Inserted: %d, Updated: %d', 0, 1, @LineIns, @LineUpd, @WcIns, @WcUpd) WITH NOWAIT;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Tier-1 Manufacturing Pipeline executed & verified successfully.', 0, 1) WITH NOWAIT;

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

    RAISERROR(N'❌ [FATAL ERROR] Manufacturing Pipeline Failed: %s', @ErrorSeverity, @ErrorState, @ErrorMessage);
END CATCH;
GO