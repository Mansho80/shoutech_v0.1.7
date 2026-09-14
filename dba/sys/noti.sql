-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sys/noti.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Enterprise Notification & Alert Engine
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

RAISERROR(N'🚀 [ENTERPRISE BUILD] Building Notification Engine (sys.Noti*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

    IF OBJECT_ID(N'sys.NotificationTemplates', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.NotificationTemplates (
            TemplateID          INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            TemplateCode        VARCHAR(50)  NOT NULL,
            Channel             VARCHAR(20)  NOT NULL DEFAULT 'INAPP', -- INAPP, EMAIL, SMS, PUSH
            SubjectAR           NVARCHAR(200) NULL,
            SubjectEN           VARCHAR(200)  NULL,
            BodyAR              NVARCHAR(MAX) NULL,
            BodyEN              VARCHAR(MAX)  NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_NotificationTemplates PRIMARY KEY CLUSTERED (TemplateID),
            CONSTRAINT UQ_sys_NotificationTemplates UNIQUE (TenantID, TemplateCode, Channel)
        );
    END;

    IF OBJECT_ID(N'sys.Notifications', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.Notifications (
            NotificationID      BIGINT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            UserID              INT NULL,
            RoleID              INT NULL,
            TemplateID          INT NULL,
            TitleAR             NVARCHAR(200) NOT NULL,
            TitleEN             VARCHAR(200)  NULL,
            BodyAR              NVARCHAR(1000) NULL,
            BodyEN              VARCHAR(1000)  NULL,
            Severity            VARCHAR(20)  NOT NULL DEFAULT 'INFO', -- INFO, WARN, ERROR, CRITICAL
            Category            VARCHAR(40)  NOT NULL DEFAULT 'SYSTEM',
            RelatedEntityType   VARCHAR(50)  NULL,
            RelatedEntityID     BIGINT NULL,
            IsRead              BIT NOT NULL DEFAULT 0,
            ReadAt              DATETIME2(7) NULL,
            ExpiresAt           DATETIME2(7) NULL,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_Notifications PRIMARY KEY CLUSTERED (NotificationID),
            CONSTRAINT FK_sys_Notifications_Template FOREIGN KEY (TemplateID) REFERENCES sys.NotificationTemplates(TemplateID)
        );
        CREATE NONCLUSTERED INDEX IX_sys_Notifications_UserUnread
            ON sys.Notifications (TenantID, CompanyID, UserID, IsRead, CreatedAt DESC)
            WHERE IsDeleted = 0 AND IsRead = 0;
    END;

    IF OBJECT_ID(N'sys.AlertRules', N'U') IS NULL
    BEGIN
        CREATE TABLE sys.AlertRules (
            AlertRuleID         INT IDENTITY(1,1) NOT NULL,
            TenantID            INT NOT NULL DEFAULT 1,
            CompanyID           INT NOT NULL DEFAULT 1,
            RuleCode            VARCHAR(50)  NOT NULL,
            RuleNameAR          NVARCHAR(150) NOT NULL,
            RuleNameEN          VARCHAR(150)  NULL,
            ModuleCode          VARCHAR(40)  NOT NULL,
            ConditionJSON       NVARCHAR(MAX) NOT NULL,
            Severity            VARCHAR(20)  NOT NULL DEFAULT 'WARN',
            NotifyRoles         VARCHAR(200) NULL,
            IsActive            BIT NOT NULL DEFAULT 1,
            IsDeleted           BIT NOT NULL DEFAULT 0,
            CreatedBy           INT NOT NULL,
            CreatedAt           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
            UpdatedAt           DATETIME2(7) NULL,
            RowVersion          ROWVERSION NOT NULL,
            CONSTRAINT PK_sys_AlertRules PRIMARY KEY CLUSTERED (AlertRuleID),
            CONSTRAINT UQ_sys_AlertRules UNIQUE (TenantID, CompanyID, RuleCode)
        );
    END;

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Notification Engine created successfully (sys.Noti*).', 0, 1) WITH NOWAIT;

END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] noti.sql failed: %s', 16, 1, @Err);
END CATCH;
GO
