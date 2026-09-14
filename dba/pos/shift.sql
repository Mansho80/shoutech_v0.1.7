-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/pos/shift.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: POS Cashier Shifts & Cash Control
-- GRADE: Enterprise Production Standard (Tier-1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'pos')
    EXEC('CREATE SCHEMA [pos] AUTHORIZATION [dbo];');
GO

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building POS Shifts (pos.Shift*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'pos.Shifts', N'U') IS NULL
    BEGIN
        CREATE TABLE pos.Shifts (
            ShiftID             BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            BranchID            INT NOT NULL,
            TerminalID          INT NOT NULL,
            CashierUserID       INT NOT NULL,
            ShiftNo             VARCHAR(30)  NOT NULL,
            OpenedAt            DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            ClosedAt            DATETIME2(7) NULL,
            OpeningCash         DECIMAL(18,4) NOT NULL DEFAULT 0,
            ClosingCashCounted  DECIMAL(18,4) NULL,
            ExpectedCash        DECIMAL(18,4) NULL,
            CashDifference      DECIMAL(18,4) NULL,
            TotalSales          DECIMAL(18,4) NOT NULL DEFAULT 0,
            TotalReturns        DECIMAL(18,4) NOT NULL DEFAULT 0,
            TotalCashIn         DECIMAL(18,4) NOT NULL DEFAULT 0,
            TotalCashOut        DECIMAL(18,4) NOT NULL DEFAULT 0,
            Status              VARCHAR(20) NOT NULL DEFAULT 'OPEN', -- OPEN, CLOSED, SUSPENDED
            Notes               NVARCHAR(500) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_pos_Shifts PRIMARY KEY CLUSTERED (ShiftID),
            CONSTRAINT UQ_pos_Shifts_No UNIQUE (TenantID, CompanyID, ShiftNo),
            CONSTRAINT CK_pos_Shifts_Status CHECK (Status IN ('OPEN','CLOSED','SUSPENDED'))
        );
        CREATE NONCLUSTERED INDEX IX_pos_Shifts_Open
            ON pos.Shifts (TenantID, CompanyID, TerminalID, Status)
            WHERE Status = 'OPEN' AND IsDeleted = 0;
    END;

    IF OBJECT_ID(N'pos.ShiftCashMovements', N'U') IS NULL
    BEGIN
        CREATE TABLE pos.ShiftCashMovements (
            MovementID          BIGINT IDENTITY(1,1) NOT NULL,
            ShiftID             BIGINT NOT NULL,
            MovementType        VARCHAR(20) NOT NULL, -- CASH_IN, CASH_OUT, DROP, PICKUP
            Amount              DECIMAL(18,4) NOT NULL,
            ReasonAR            NVARCHAR(200) NULL,
            ReasonEN            VARCHAR(200) NULL,
            ReferenceNo         VARCHAR(50) NULL,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            CONSTRAINT PK_pos_ShiftCashMovements PRIMARY KEY CLUSTERED (MovementID),
            CONSTRAINT FK_pos_ShiftCashMovements_Shift FOREIGN KEY (ShiftID) REFERENCES pos.Shifts(ShiftID) ON DELETE CASCADE,
            CONSTRAINT CK_pos_ShiftCashMovements_Amount CHECK (Amount > 0)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] POS Shifts created successfully (pos.Shifts*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] shift.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
