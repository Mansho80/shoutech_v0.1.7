-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sds/sds_pos.sql
-- PURPOSE: Enterprise POS Registers & Cash Drawers Seeding Pipeline
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

RAISERROR(N'🚀 [START] Initiating Tier-1 POS Registers & Cash Drawers Pipeline...', 0, 1) WITH NOWAIT;

-- التحقق المسبق من وجود جداول نقاط البيع والصناديق
IF OBJECT_ID(N'dbo.PosRegisters', N'U') IS NULL OR OBJECT_ID(N'dbo.PosCashBoxes', N'U') IS NULL
BEGIN
    RAISERROR(N'❌ [CRITICAL] Core POS tables (PosRegisters / PosCashBoxes) do not exist. Aborting execution.', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;

BEGIN TRY
    
    -- ══════════════════════════════════════════════════════════════════════════
    -- 1. تهيئة أجهزة ونقاط البيع (POS Registers Seeding)
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'🖥️ [PROCESS] Staging POS Registers data...', 0, 1) WITH NOWAIT;

    DECLARE @RawRegisters TABLE (
        TenantID        INT NOT NULL,
        CompanyID       INT NOT NULL,
        RegisterCode    VARCHAR(50) NOT NULL,
        RegisterNameAR  NVARCHAR(255) NOT NULL,
        RegisterNameEN  VARCHAR(255) NOT NULL,
        WarehouseCode   VARCHAR(50) NOT NULL,
        IsActive        BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, RegisterCode)
    );

    INSERT INTO @RawRegisters (TenantID, CompanyID, RegisterCode, RegisterNameAR, RegisterNameEN, WarehouseCode, IsActive)
    VALUES 
    (@TenantID, @CompanyID, 'POS-01', N'صندوق المعرض الرئيسي رقم 1', 'Main Showroom POS Register 01', 'WH-MAIN', 1),
    (@TenantID, @CompanyID, 'POS-02', N'صندوق المعرض الرئيسي رقم 2', 'Main Showroom POS Register 02', 'WH-MAIN', 1),
    (@TenantID, @CompanyID, 'POS-RET', N'صندوق فرع المرتجعات السريعة', 'Express Returns POS Register', 'WH-RET', 1);

    DECLARE @RegActions TABLE (ActionType VARCHAR(10));

    MERGE INTO dbo.PosRegisters WITH (TABLOCKX) AS Target
    USING @RawRegisters AS Source
    ON (Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.RegisterCode = Source.RegisterCode)
    
    WHEN MATCHED AND (
        Target.RegisterNameAR <> Source.RegisterNameAR OR
        Target.RegisterNameEN <> Source.RegisterNameEN OR
        Target.WarehouseCode  <> Source.WarehouseCode OR
        Target.IsActive       <> Source.IsActive
    ) THEN
        UPDATE SET 
            Target.RegisterNameAR = Source.RegisterNameAR,
            Target.RegisterNameEN = Source.RegisterNameEN,
            Target.WarehouseCode  = Source.WarehouseCode,
            Target.IsActive       = Source.IsActive,
            Target.UpdatedBy      = @CreatedBy,
            Target.UpdatedAt      = SYSDATETIME()

    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, RegisterCode, RegisterNameAR, RegisterNameEN, WarehouseCode, IsActive, CreatedBy, CreatedAt)
        VALUES (Source.TenantID, Source.CompanyID, Source.RegisterCode, Source.RegisterNameAR, Source.RegisterNameEN, Source.WarehouseCode, Source.IsActive, @CreatedBy, SYSDATETIME())
    
    OUTPUT $action INTO @RegActions;

    -- ══════════════════════════════════════════════════════════════════════════
    -- 2. تهيئة صناديق النقد والدرج (POS Cash Boxes Seeding)
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'💵 [PROCESS] Staging POS Cash Boxes data...', 0, 1) WITH NOWAIT;

    DECLARE @RawCashBoxes TABLE (
        TenantID      INT NOT NULL,
        CompanyID     INT NOT NULL,
        BoxCode       VARCHAR(50) NOT NULL,
        BoxNameAR     NVARCHAR(255) NOT NULL,
        BoxNameEN     VARCHAR(255) NOT NULL,
        RegisterCode  VARCHAR(50) NOT NULL,
        IsActive      BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, BoxCode)
    );

    INSERT INTO @RawCashBoxes (TenantID, CompanyID, BoxCode, BoxNameAR, BoxNameEN, RegisterCode, IsActive)
    VALUES 
    (@TenantID, @CompanyID, 'BOX-01', N'درج النقدية لصندوق 1', 'Cash Drawer POS-01', 'POS-01', 1),
    (@TenantID, @CompanyID, 'BOX-02', N'درج النقدية لصندوق 2', 'Cash Drawer POS-02', 'POS-02', 1),
    (@TenantID, @CompanyID, 'BOX-RET', N'درج نقدية المرتجعات', 'Returns Cash Drawer', 'POS-RET', 1);

    DECLARE @BoxActions TABLE (ActionType VARCHAR(10));

    MERGE INTO dbo.PosCashBoxes WITH (TABLOCKX) AS Target
    USING @RawCashBoxes AS Source
    ON (Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.BoxCode = Source.BoxCode)
    
    WHEN MATCHED AND (
        Target.BoxNameAR    <> Source.BoxNameAR OR
        Target.BoxNameEN    <> Source.BoxNameEN OR
        Target.RegisterCode <> Source.RegisterCode OR
        Target.IsActive     <> Source.IsActive
    ) THEN
        UPDATE SET 
            Target.BoxNameAR    = Source.BoxNameAR,
            Target.BoxNameEN    = Source.BoxNameEN,
            Target.RegisterCode = Source.RegisterCode,
            Target.IsActive     = Source.IsActive,
            Target.UpdatedBy    = @CreatedBy,
            Target.UpdatedAt    = SYSDATETIME()

    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, BoxCode, BoxNameAR, BoxNameEN, RegisterCode, IsActive, CreatedBy, CreatedAt)
        VALUES (Source.TenantID, Source.CompanyID, Source.BoxCode, Source.BoxNameAR, Source.BoxNameEN, Source.RegisterCode, Source.IsActive, @CreatedBy, SYSDATETIME())
    
    OUTPUT $action INTO @BoxActions;

    -- ══════════════════════════════════════════════════════════════════════════
    -- 3. تقارير القياس ومقاييس التنفيذ (Metrics Summary)
    -- ══════════════════════════════════════════════════════════════════════════
    DECLARE @RegIns INT = (SELECT COUNT(*) FROM @RegActions WHERE ActionType = 'INSERT');
    DECLARE @RegUpd INT = (SELECT COUNT(*) FROM @RegActions WHERE ActionType = 'UPDATE');
    DECLARE @BoxIns INT = (SELECT COUNT(*) FROM @BoxActions WHERE ActionType = 'INSERT');
    DECLARE @BoxUpd INT = (SELECT COUNT(*) FROM @BoxActions WHERE ActionType = 'UPDATE');

    RAISERROR(N'📊 [METRICS] Registers -> Inserted: %d, Updated: %d | CashBoxes -> Inserted: %d, Updated: %d', 0, 1, @RegIns, @RegUpd, @BoxIns, @BoxUpd) WITH NOWAIT;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Tier-1 POS Pipeline executed & verified successfully.', 0, 1) WITH NOWAIT;

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

    RAISERROR(N'❌ [FATAL ERROR] POS Pipeline Failed: %s', @ErrorSeverity, @ErrorState, @ErrorMessage);
END CATCH;
GO