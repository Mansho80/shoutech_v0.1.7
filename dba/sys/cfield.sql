-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sys/cfield.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Custom Fields Engine (حقول مخصصة)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Custom Fields (sys.CField*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'sys.CustomFieldDefs', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.CustomFieldDefs (
            FieldDefID          INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            EntityType          VARCHAR(50)  NOT NULL, -- PRODUCT, CUSTOMER, VENDOR, INVOICE, EMPLOYEE, ...
            FieldKey            VARCHAR(50)  NOT NULL,
            FieldLabelAR        NVARCHAR(100) NOT NULL,
            FieldLabelEN        VARCHAR(100) NULL,
            DataType            VARCHAR(20)  NOT NULL DEFAULT 'STRING', -- STRING, INT, DECIMAL, DATE, BOOL, LIST
            ListValuesJSON      NVARCHAR(MAX) NULL,
            DefaultValue        NVARCHAR(200) NULL,
            IsRequired          BIT NOT NULL DEFAULT 0,
            DisplayOrder        INT NOT NULL DEFAULT 0,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_CustomFieldDefs PRIMARY KEY CLUSTERED (FieldDefID),
            CONSTRAINT UQ_sys_CustomFieldDefs UNIQUE (TenantID, CompanyID, EntityType, FieldKey)
        );
    END;

    IF OBJECT_ID(N'sys.CustomFieldValues', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.CustomFieldValues (
            FieldValueID        BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            FieldDefID          INT NOT NULL,
            EntityType          VARCHAR(50)  NOT NULL,
            EntityID            BIGINT NOT NULL,
            ValueString         NVARCHAR(500) NULL,
            ValueNumber         DECIMAL(18,4) NULL,
            ValueDate           DATE NULL,
            ValueBool           BIT NULL,
            UpdatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_CustomFieldValues PRIMARY KEY CLUSTERED (FieldValueID),
            CONSTRAINT FK_sys_CustomFieldValues_Def FOREIGN KEY (FieldDefID) REFERENCES sys.CustomFieldDefs(FieldDefID),
            CONSTRAINT UQ_sys_CustomFieldValues UNIQUE (TenantID, CompanyID, FieldDefID, EntityID)
        );
        CREATE NONCLUSTERED INDEX IX_sys_CustomFieldValues_Entity
            ON sys.CustomFieldValues (TenantID, CompanyID, EntityType, EntityID);
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Custom Fields engine created (sys.CField*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] cfield.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
