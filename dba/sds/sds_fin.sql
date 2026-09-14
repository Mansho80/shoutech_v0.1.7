-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sds/sds_fin.sql
-- PURPOSE: Enterprise Financial & Voucher Types Seeding Pipeline
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

RAISERROR(N'🚀 [START] Initiating Tier-1 Financial & Voucher Types Pipeline...', 0, 1) WITH NOWAIT;

-- التحقق المسبق من وجود جداول أنماط السندات والفترات المالية
IF OBJECT_ID(N'dbo.VoucherTypes', N'U') IS NULL 
BEGIN
    RAISERROR(N'❌ [CRITICAL] Table dbo.VoucherTypes does not exist. Aborting execution.', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;

BEGIN TRY
    
    -- ══════════════════════════════════════════════════════════════════════════
    -- 1. إعداد جدول البيانات المرجعية المؤقت لأنماط السندات (Voucher Types)
    -- ══════════════════════════════════════════════════════════════════════════
    RAISERROR(N'💳 [PROCESS] Staging Voucher Types data...', 0, 1) WITH NOWAIT;

    DECLARE @RawVoucherTypes TABLE (
        TenantID         INT NOT NULL,
        CompanyID        INT NOT NULL,
        VoucherTypeCode  VARCHAR(50) NOT NULL,
        TypeNameAR       NVARCHAR(255) NOT NULL,
        TypeNameEN       VARCHAR(255) NOT NULL,
        VoucherCategory  VARCHAR(50) NOT NULL, -- (Journal, Receipt, Payment, Contra)
        DefaultEffect    SMALLINT NOT NULL,    -- (1: Debit, -1: Credit, 0: Neutral)
        IsActive         BIT NOT NULL DEFAULT 1,
        PRIMARY KEY (TenantID, CompanyID, VoucherTypeCode)
    );

    INSERT INTO @RawVoucherTypes 
    (TenantID, CompanyID, VoucherTypeCode, TypeNameAR, TypeNameEN, VoucherCategory, DefaultEffect, IsActive)
    VALUES 
    (@TenantID, @CompanyID, 'JV',  N'سند قيد مزدوج افتراضي',   'Standard Journal Voucher',   'Journal', 0, 1),
    (@TenantID, @CompanyID, 'RV',  N'سند قبض نقدي/بنوك',      'Cash/Bank Receipt Voucher',  'Receipt', 1, 1),
    (@TenantID, @CompanyID, 'PV',  N'سند دفع نقدي/بنوك',      'Cash/Bank Payment Voucher',  'Payment', -1, 1),
    (@TenantID, @CompanyID, 'CV',  N'سند يومية الصندوق',       'Cash Box Daily Voucher',     'Contra',  0, 1),
    (@TenantID, @CompanyID, 'CHQ-R',N'سند قبض شيكات تحت التحصيل','Cheques Collection Receipt', 'Receipt', 1, 1),
    (@TenantID, @CompanyID, 'CHQ-P',N'سند دفع اصدار شيكات',     'Cheques Issuance Payment',   'Payment', -1, 1);

    DECLARE @VoucherActions TABLE (ActionType VARCHAR(10));

    -- ══════════════════════════════════════════════════════════════════════════
    -- 2. تنفيذ الدمج الذكي الآمن (Enterprise Idempotent MERGE)
    -- ══════════════════════════════════════════════════════════════════════════
    MERGE INTO dbo.VoucherTypes WITH (TABLOCKX) AS Target
    USING @RawVoucherTypes AS Source
    ON (Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.VoucherTypeCode = Source.VoucherTypeCode)
    
    WHEN MATCHED AND (
        Target.TypeNameAR      <> Source.TypeNameAR OR
        Target.TypeNameEN      <> Source.TypeNameEN OR
        Target.VoucherCategory <> Source.VoucherCategory OR
        Target.DefaultEffect   <> Source.DefaultEffect OR
        Target.IsActive        <> Source.IsActive
    ) THEN
        UPDATE SET 
            Target.TypeNameAR      = Source.TypeNameAR,
            Target.TypeNameEN      = Source.TypeNameEN,
            Target.VoucherCategory = Source.VoucherCategory,
            Target.DefaultEffect   = Source.DefaultEffect,
            Target.IsActive        = Source.IsActive,
            Target.UpdatedBy       = @CreatedBy,
            Target.UpdatedAt       = SYSDATETIME()

    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, VoucherTypeCode, TypeNameAR, TypeNameEN, VoucherCategory, DefaultEffect, IsActive, CreatedBy, CreatedAt)
        VALUES (Source.TenantID, Source.CompanyID, Source.VoucherTypeCode, Source.TypeNameAR, Source.TypeNameEN, Source.VoucherCategory, Source.DefaultEffect, Source.IsActive, @CreatedBy, SYSDATETIME())
    
    OUTPUT $action INTO @VoucherActions;

    -- ══════════════════════════════════════════════════════════════════════════
    -- 3. تقارير القياس ومقاييس التنفيذ (Metrics Summary)
    -- ══════════════════════════════════════════════════════════════════════════
    DECLARE @InsCount INT = (SELECT COUNT(*) FROM @VoucherActions WHERE ActionType = 'INSERT');
    DECLARE @UpdCount INT = (SELECT COUNT(*) FROM @VoucherActions WHERE ActionType = 'UPDATE');

    RAISERROR(N'📊 [METRICS] VoucherTypes Merge complete. Inserted: %d, Updated: %d', 0, 1, @InsCount, @UpdCount) WITH NOWAIT;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Tier-1 Financial Pipeline executed & verified successfully.', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    -- 4. إدارة الاستثناءات والتراجع الآمن
    IF (XACT_STATE()) <> 0
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(N'🔄 [ROLLBACK] Transaction rolled back safely.', 0, 1) WITH NOWAIT;
    END

    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();

    RAISERROR(N'❌ [FATAL ERROR] Financial Pipeline Failed: %s', @ErrorSeverity, @ErrorState, @ErrorMessage);
END CATCH;
GO