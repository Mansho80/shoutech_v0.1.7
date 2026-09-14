-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/mst/lic.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Licensing & Activation (الترخيص والتفعيل)
-- GRADE: Enterprise Production Standard (Tier-1) — Max Security
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'mst')
    EXEC('CREATE SCHEMA [mst] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Licensing (mst.Lic*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'mst.Licenses', N'U') IS NULL
    BEGIN
        CREATE TABLE mst.Licenses (
            LicenseID           INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            LicenseKeyHash      VARCHAR(128) NOT NULL,           -- never store plain key
            ProductEdition      VARCHAR(30)  NOT NULL DEFAULT 'ENTERPRISE', -- DEMO, STANDARD, ENTERPRISE
            MaxUsers            INT NOT NULL DEFAULT 1,
            MaxCompanies        INT NOT NULL DEFAULT 1,
            MaxBranches         INT NOT NULL DEFAULT 1,
            FeaturesJSON        NVARCHAR(MAX) NULL,             -- feature flags
            IssuedAt            DATETIME2(7) NOT NULL,
            ExpiresAt           DATETIME2(7) NULL,
            LastValidatedAt     DATETIME2(7) NULL,
            HardwareFingerprint VARCHAR(128) NULL,
            Status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, EXPIRED, REVOKED, GRACE
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_mst_Licenses PRIMARY KEY CLUSTERED (LicenseID),
            CONSTRAINT UQ_mst_Licenses_Hash UNIQUE (LicenseKeyHash)
        );
    END;

    IF OBJECT_ID(N'mst.LicenseAudit', N'U') IS NULL
    BEGIN
        CREATE TABLE mst.LicenseAudit (
            LicenseAuditID      BIGINT IDENTITY(1,1) NOT NULL,
            LicenseID           INT NULL,
            ActionType          VARCHAR(30)  NOT NULL, -- VALIDATE, ACTIVATE, DEACTIVATE, RENEW, FAIL
            Result              VARCHAR(20)  NOT NULL,
            MachineInfo         NVARCHAR(500) NULL,
            IPAddress           VARCHAR(45) NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            CONSTRAINT PK_mst_LicenseAudit PRIMARY KEY CLUSTERED (LicenseAuditID)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Licensing module created successfully (mst.Lic*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] lic.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
