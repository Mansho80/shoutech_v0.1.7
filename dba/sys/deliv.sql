-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sys/deliv.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Delivery · Drivers · Routes (التوصيل والسائقين)
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Delivery (sys.Deliv*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'sys.Drivers', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.Drivers (
            DriverID            INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            DriverCode          VARCHAR(30)  NOT NULL,
            FullNameAR          NVARCHAR(150) NOT NULL,
            FullNameEN          VARCHAR(150) NULL,
            Mobile              VARCHAR(30) NULL,
            LicenseNo           VARCHAR(40) NULL,
            VehicleNo           VARCHAR(30) NULL,
            VehicleType         NVARCHAR(50) NULL,
            EmployeeID          INT NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_Drivers PRIMARY KEY CLUSTERED (DriverID),
            CONSTRAINT UQ_sys_Drivers UNIQUE (TenantID, CompanyID, DriverCode)
        );
    END;

    IF OBJECT_ID(N'sys.DeliveryRates', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.DeliveryRates (
            DeliveryRateID      INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            ZoneNameAR          NVARCHAR(100) NOT NULL,
            ZoneNameEN          VARCHAR(100) NULL,
            RateAmount          DECIMAL(18,4) NOT NULL,
            CurrencyCode        CHAR(3) NOT NULL DEFAULT 'SAR',
            MinOrderAmount      DECIMAL(18,4) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_DeliveryRates PRIMARY KEY CLUSTERED (DeliveryRateID)
        );
    END;

    IF OBJECT_ID(N'sys.DeliveryOrders', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.DeliveryOrders (
            DeliveryOrderID     BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NOT NULL,
            DeliveryNo          VARCHAR(40)  NOT NULL,
            SourceDocType       VARCHAR(30)  NOT NULL, -- SALES_INVOICE, SALES_ORDER
            SourceDocID         BIGINT NOT NULL,
            CustomerID          INT NOT NULL,
            DriverID            INT NULL,
            DeliveryRateID      INT NULL,
            DeliveryAddress     NVARCHAR(400) NULL,
            ScheduledDate       DATE NULL,
            DeliveredAt         DATETIME2(7) NULL,
            DeliveryFee         DECIMAL(18,4) NOT NULL DEFAULT 0,
            CODAmount           DECIMAL(18,4) NOT NULL DEFAULT 0,
            Status              VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, ASSIGNED, OUT, DELIVERED, FAILED, CANCELLED
            FailureReason       NVARCHAR(200) NULL,
            Notes               NVARCHAR(300) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_DeliveryOrders PRIMARY KEY CLUSTERED (DeliveryOrderID),
            CONSTRAINT UQ_sys_DeliveryOrders UNIQUE (TenantID, CompanyID, DeliveryNo),
            CONSTRAINT FK_sys_DeliveryOrders_Driver FOREIGN KEY (DriverID) REFERENCES sys.Drivers(DriverID)
        );
        CREATE NONCLUSTERED INDEX IX_sys_DeliveryOrders_Status
            ON sys.DeliveryOrders (TenantID, CompanyID, Status, ScheduledDate) WHERE IsDeleted = 0;
    END;

    IF OBJECT_ID(N'sys.DriverCashClosings', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.DriverCashClosings (
            ClosingID           BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            DriverID            INT NOT NULL,
            ClosingDate         DATE NOT NULL,
            ExpectedCOD         DECIMAL(18,4) NOT NULL DEFAULT 0,
            ActualCash          DECIMAL(18,4) NOT NULL DEFAULT 0,
            Difference          AS (ActualCash - ExpectedCOD),
            Status              VARCHAR(20) NOT NULL DEFAULT 'OPEN',
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_DriverCashClosings PRIMARY KEY CLUSTERED (ClosingID),
            CONSTRAINT FK_sys_DriverCashClosings_Driver FOREIGN KEY (DriverID) REFERENCES sys.Drivers(DriverID)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Delivery module created (sys.Deliv*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] deliv.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
