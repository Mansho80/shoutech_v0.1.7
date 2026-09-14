-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/mst/proc.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Shared Stored Procedures & Helpers (إجراءات مشتركة)
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'mst')
    EXEC('CREATE SCHEMA [mst] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building shared procedures (mst.Proc*)...', 0, 1) WITH NOWAIT;

-- ── Soft-delete helper pattern (example procedure) ──
IF OBJECT_ID(N'mst.sp_SoftDelete', N'P') IS NOT NULL
    DROP PROCEDURE mst.sp_SoftDelete;
GO

CREATE PROCEDURE mst.sp_SoftDelete
    @SchemaName     SYSNAME,
    @TableName      SYSNAME,
    @PKColumn       SYSNAME,
    @PKValue        BIGINT,
    @DeletedBy      INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N'
        SET IsDeleted = 1,
            UpdatedAt = SYSDATETIME()
        WHERE ' + QUOTENAME(@PKColumn) + N' = @PKValue
          AND IsDeleted = 0;';
    EXEC sp_executesql @sql, N'@PKValue BIGINT', @PKValue = @PKValue;
END;
GO

-- ── Next sequence value (wrapper if sys.sp_GetNextSequenceValue not present) ──
IF OBJECT_ID(N'mst.sp_GetNextDocNo', N'P') IS NOT NULL
    DROP PROCEDURE mst.sp_GetNextDocNo;
GO

CREATE PROCEDURE mst.sp_GetNextDocNo
    @TenantID       INT,
    @CompanyID      INT,
    @SequenceCode   VARCHAR(50),
    @NextValue      BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;
    BEGIN TRY
        IF OBJECT_ID(N'sys.NumberSequences', N'U') IS NOT NULL
        BEGIN
            UPDATE sys.NumberSequences
            SET CurrentValue = CurrentValue + 1,
                @NextValue = CurrentValue + 1
            WHERE TenantID = @TenantID
              AND CompanyID = @CompanyID
              AND SequenceCode = @SequenceCode;

            IF @@ROWCOUNT = 0
            BEGIN
                INSERT INTO sys.NumberSequences (TenantID, CompanyID, SequenceCode, CurrentValue, Prefix, Padding)
                VALUES (@TenantID, @CompanyID, @SequenceCode, 1, '', 6);
                SET @NextValue = 1;
            END
        END
        ELSE
        BEGIN
            SET @NextValue = 1;
        END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

RAISERROR(N'✅ [SUCCESS] Shared procedures created successfully (mst.sp_*).', 0, 1) WITH NOWAIT;
GO
