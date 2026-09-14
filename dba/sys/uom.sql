-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sys/uom.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Units of Measure (وحدات القياس)
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'sys')
    EXEC('CREATE SCHEMA [sys] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Units of Measure (sys.UOM*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'sys.UnitsOfMeasure', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.UnitsOfMeasure (
            UOMID               INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            UOMCode             VARCHAR(20)  NOT NULL,
            UOMNameAR           NVARCHAR(80) NOT NULL,
            UOMNameEN           VARCHAR(80) NULL,
            UOMType             VARCHAR(20) NOT NULL DEFAULT 'COUNT', -- COUNT, WEIGHT, VOLUME, LENGTH, AREA, TIME
            IsBase              BIT NOT NULL DEFAULT 0,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_UnitsOfMeasure PRIMARY KEY CLUSTERED (UOMID),
            CONSTRAINT UQ_sys_UnitsOfMeasure UNIQUE (TenantID, UOMCode)
        );
    END;

    IF OBJECT_ID(N'sys.UOMConversions', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.UOMConversions (
            ConversionID        INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            ProductID           INT NULL,                       -- NULL = global conversion
            FromUOMID           INT NOT NULL,
            ToUOMID             INT NOT NULL,
            Factor              DECIMAL(18,8) NOT NULL,         -- 1 From = Factor To
            IsActive            BIT NOT NULL DEFAULT 1,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_UOMConversions PRIMARY KEY CLUSTERED (ConversionID),
            CONSTRAINT FK_sys_UOMConversions_From FOREIGN KEY (FromUOMID) REFERENCES sys.UnitsOfMeasure(UOMID),
            CONSTRAINT FK_sys_UOMConversions_To   FOREIGN KEY (ToUOMID)   REFERENCES sys.UnitsOfMeasure(UOMID),
            CONSTRAINT CK_sys_UOMConversions_Factor CHECK (Factor > 0)
        );
    END;

    -- بذور وحدات شائعة
    IF NOT EXISTS (SELECT 1 FROM sys.UnitsOfMeasure WHERE UOMCode = 'PCS')
    BEGIN
        INSERT INTO sys.UnitsOfMeasure (UOMCode, UOMNameAR, UOMNameEN, UOMType, IsBase)
        VALUES
            ('PCS', N'قطعة', 'Piece', 'COUNT', 1),
            ('BOX', N'صندوق', 'Box', 'COUNT', 0),
            ('CTN', N'كرتون', 'Carton', 'COUNT', 0),
            ('KG',  N'كيلوغرام', 'Kilogram', 'WEIGHT', 1),
            ('G',   N'غرام', 'Gram', 'WEIGHT', 0),
            ('L',   N'لتر', 'Liter', 'VOLUME', 1),
            ('ML',  N'ملليلتر', 'Milliliter', 'VOLUME', 0),
            ('M',   N'متر', 'Meter', 'LENGTH', 1),
            ('CM',  N'سنتيمتر', 'Centimeter', 'LENGTH', 0),
            ('M2',  N'متر مربع', 'Square Meter', 'AREA', 1),
            ('HR',  N'ساعة', 'Hour', 'TIME', 1),
            ('DAY', N'يوم', 'Day', 'TIME', 0);
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Units of Measure created (sys.UOM*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] uom.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
