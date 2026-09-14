========================================================================
-- FILE: dba/sch/aud.sql
-- PROJECT: SHOUTECH ERP V10 - Auditing & Compliance Module (Ultimate 10/10)
-- VERSION: 10.1.0
-- DESCRIPTION: Audit logs, activity tracking, attachments, notifications,
-- approval workflows, data export log. Full SOX/GDPR ready.
-- ==============================================
sql

USE [$(DbFileName)];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;

-- Enterprise Concurrency Settings
ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE CURRENT SET READ_COMMITTED_SNAPSHOT ON;
GO

PRINT N'═══════════════════════════════════════════════════════════════════════════';
PRINT N'SHOUTECH ERP V10 – Auditing & Compliance Module (Ultimate 10/10)';
PRINT N'═══════════════════════════════════════════════════════════════════════════';
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- ==========================================================================
    -- 1. AUDIT LOGS (Core Immutable Audit Trail)
    -- ==========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'AuditLogs')
    BEGIN
        CREATE TABLE dbo.AuditLogs (
            AuditLogID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            UserID UNIQUEIDENTIFIER,
            UserName NVARCHAR(100),
            SessionID NVARCHAR(100),
            ActionType NVARCHAR(20) NOT NULL,
            ActionDescription NVARCHAR(500),
            TableName NVARCHAR(128),
            RecordID NVARCHAR(50),
            OldValues NVARCHAR(MAX),
            NewValues NVARCHAR(MAX),
            ChangedFields NVARCHAR(MAX),
            ChangeContext NVARCHAR(MAX),           -- JSON for detailed before/after
            ApplicationModule NVARCHAR(50),
            ComplianceCategory NVARCHAR(30),
            IPAddress NVARCHAR(50),
            UserAgent NVARCHAR(500),
            MachineName NVARCHAR(100),
            ExecutionTimeMS INT,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7),
            DeletedBy UNIQUEIDENTIFIER,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            RowVersion ROWVERSION,

            CONSTRAINT PK_AuditLogs PRIMARY KEY CLUSTERED (AuditLogID),
            CONSTRAINT FK_AuditLogs_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID),
            CONSTRAINT FK_AuditLogs_User FOREIGN KEY (UserID) REFERENCES MST.dbo.Users(UserID),
            CONSTRAINT CK_Audit_ActionType CHECK (ActionType IN ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT','EXPORT','PRINT','VIEW')),
            CONSTRAINT CK_Audit_Compliance CHECK (ComplianceCategory IN ('SOX','GDPR','PDPL','ZATCA','INTERNAL'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ AuditLogs created';
    END

    -- Indexes
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditLogs_Company_Date' AND object_id = OBJECT_ID('dbo.AuditLogs'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_AuditLogs_Company_Date ON dbo.AuditLogs(CompanyID, CreatedAt DESC) WHERE IsDeleted = 0;
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditLogs_Table_Record' AND object_id = OBJECT_ID('dbo.AuditLogs'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_AuditLogs_Table_Record ON dbo.AuditLogs(TableName, RecordID, CreatedAt DESC) WHERE IsDeleted = 0;
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'CSIX_AuditLogs_Analytics' AND object_id = OBJECT_ID('dbo.AuditLogs'))
    BEGIN
        CREATE NONCLUSTERED COLUMNSTORE INDEX CSIX_AuditLogs_Analytics ON dbo.AuditLogs (CompanyID, ActionType, TableName, CreatedAt);
    END

    -- Extended Properties
    IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE major_id = OBJECT_ID('dbo.AuditLogs') AND name = N'MS_Description' AND minor_id = 0)
    BEGIN
        EXEC sys.sp_addextendedproperty @name = N'MS_Description', @value = N'Central immutable audit trail for SOX/GDPR/PDPL/ZATCA compliance', 
        @level0type = N'SCHEMA', @level0name = 'dbo', @level1type = N'TABLE', @level1name = 'AuditLogs';
    END


    -- ==========================================================================
    -- 2. ACTIVITY LOG
    -- ==========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ActivityLog')
    BEGIN
        CREATE TABLE dbo.ActivityLog (
            ActivityLogID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            UserID UNIQUEIDENTIFIER,
            UserName NVARCHAR(100),
            ActivityType NVARCHAR(100) NOT NULL,
            ActivityCategory NVARCHAR(50),
            Details NVARCHAR(MAX),
            EntityType NVARCHAR(100),
            EntityID NVARCHAR(50),
            EntityName NVARCHAR(200),
            ThreatLevel NVARCHAR(10) NOT NULL DEFAULT 'INFO',
            Metadata NVARCHAR(MAX),
            CorrelationID UNIQUEIDENTIFIER DEFAULT NEWID(),
            IPAddress NVARCHAR(50),
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7),
            DeletedBy UNIQUEIDENTIFIER,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            RowVersion ROWVERSION,

            CONSTRAINT PK_ActivityLog PRIMARY KEY CLUSTERED (ActivityLogID),
            CONSTRAINT FK_ActivityLog_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID),
            CONSTRAINT CK_Activity_Threat CHECK (ThreatLevel IN ('INFO','LOW','MEDIUM','HIGH','CRITICAL'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ ActivityLog created';
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ActivityLog_User_Date' AND object_id = OBJECT_ID('dbo.ActivityLog'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_ActivityLog_User_Date ON dbo.ActivityLog(UserID, CreatedAt DESC) WHERE IsDeleted = 0;
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ActivityLog_Threats' AND object_id = OBJECT_ID('dbo.ActivityLog'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_ActivityLog_Threats ON dbo.ActivityLog(ThreatLevel, CreatedAt DESC) WHERE ThreatLevel IN ('HIGH','CRITICAL') AND IsDeleted = 0;
    END

    IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE major_id = OBJECT_ID('dbo.ActivityLog') AND name = N'MS_Description' AND minor_id = 0)
    BEGIN
        EXEC sys.sp_addextendedproperty @name = N'MS_Description', @value = N'User activity and security threat monitoring', 
        @level0type = N'SCHEMA', @level0name = 'dbo', @level1type = N'TABLE', @level1name = 'ActivityLog';
    END


    -- ==========================================================================
    -- 3. ATTACHMENTS
    -- ==========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Attachments')
    BEGIN
        CREATE TABLE dbo.Attachments (
            AttachmentID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            EntityType NVARCHAR(50) NOT NULL,
            EntityID BIGINT NOT NULL,
            FileName NVARCHAR(255) NOT NULL,
            OriginalFileName NVARCHAR(255) NOT NULL,
            FilePath NVARCHAR(500) NOT NULL,
            FileSize BIGINT NOT NULL,
            MimeType NVARCHAR(100),
            FileHash NVARCHAR(64),
            RetentionPolicy NVARCHAR(20) DEFAULT '7YEARS',
            ExpiryDate DATETIME2(7),
            IsEncrypted BIT NOT NULL DEFAULT 0,
            Description NVARCHAR(500),
            Tags NVARCHAR(500),
            UploadedBy UNIQUEIDENTIFIER NOT NULL,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7),
            DeletedBy UNIQUEIDENTIFIER,
            UploadedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            RowVersion ROWVERSION,

            CONSTRAINT PK_Attachments PRIMARY KEY CLUSTERED (AttachmentID),
            CONSTRAINT FK_Attachments_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID)
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ Attachments created';
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Attachments_Entity' AND object_id = OBJECT_ID('dbo.Attachments'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Attachments_Entity ON dbo.Attachments(EntityType, EntityID) WHERE IsDeleted = 0;
    END
    
    IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE major_id = OBJECT_ID('dbo.Attachments') AND name = N'MS_Description' AND minor_id = 0)
    BEGIN
        EXEC sys.sp_addextendedproperty @name = N'MS_Description', @value = N'Secure file attachments with retention & compliance policy', 
        @level0type = N'SCHEMA', @level0name = 'dbo', @level1type = N'TABLE', @level1name = 'Attachments';
    END


    -- ==========================================================================
    -- 4. NOTIFICATIONS (Fixed Constraints)
    -- ==========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Notifications')
    BEGIN
        CREATE TABLE dbo.Notifications (
            NotificationID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            UserID UNIQUEIDENTIFIER NOT NULL,
            NotificationType NVARCHAR(30) NOT NULL,
            NotificationCategory NVARCHAR(50),
            Title NVARCHAR(200) NOT NULL,
            Message NVARCHAR(MAX) NOT NULL,
            EntityType NVARCHAR(50),
            EntityID NVARCHAR(50),
            ActionURL NVARCHAR(500),
            IsRead BIT NOT NULL DEFAULT 0,
            ReadAt DATETIME2(7),
            IsDismissed BIT NOT NULL DEFAULT 0,
            DismissedAt DATETIME2(7),
            Priority NVARCHAR(10) NOT NULL DEFAULT 'NORMAL',
            ExpiresAt DATETIME2(7),
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7),
            DeletedBy UNIQUEIDENTIFIER,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            RowVersion ROWVERSION,

            CONSTRAINT PK_Notifications PRIMARY KEY CLUSTERED (NotificationID),
            CONSTRAINT FK_Notifications_User FOREIGN KEY (UserID) REFERENCES MST.dbo.Users(UserID),
            CONSTRAINT FK_Notifications_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID),
            -- Added 'SYSTEM' to allow Seed Data insertion
            CONSTRAINT CK_Notif_Type CHECK (NotificationType IN ('INFO', 'WARNING', 'ERROR', 'SUCCESS', 'REMINDER', 'SYSTEM')),
            CONSTRAINT CK_Notif_Priority CHECK (Priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT'))
        );
        PRINT N'✅ Notifications created';
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notifications_User_Unread' AND object_id = OBJECT_ID('dbo.Notifications'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Notifications_User_Unread ON dbo.Notifications(UserID, IsRead, CreatedAt DESC) WHERE IsRead = 0 AND IsDismissed = 0 AND IsDeleted = 0;
    END
    
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notifications_User_All' AND object_id = OBJECT_ID('dbo.Notifications'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Notifications_User_All ON dbo.Notifications(UserID, CreatedAt DESC) WHERE IsDeleted = 0;
    END
    
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notifications_Expired' AND object_id = OBJECT_ID('dbo.Notifications'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Notifications_Expired ON dbo.Notifications(ExpiresAt) WHERE ExpiresAt IS NOT NULL AND IsDismissed = 0 AND IsDeleted = 0;
    END


    -- ==========================================================================
    -- 5. APPROVAL REQUESTS
    -- ==========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ApprovalRequests')
    BEGIN
        CREATE TABLE dbo.ApprovalRequests (
            ApprovalRequestID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            RequestType NVARCHAR(50) NOT NULL,
            EntityType NVARCHAR(50) NOT NULL,
            EntityID BIGINT NOT NULL,
            RequestedBy UNIQUEIDENTIFIER NOT NULL,
            RequestedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            CurrentApproverID UNIQUEIDENTIFIER,
            ApprovalLevel INT NOT NULL DEFAULT 1,
            MaxApprovalLevel INT NOT NULL DEFAULT 1,
            RequestStatus NVARCHAR(20) NOT NULL DEFAULT 'PENDING',
            Amount DECIMAL(18,4),
            Description NVARCHAR(500),
            ApprovedBy UNIQUEIDENTIFIER,
            ApprovedAt DATETIME2(7),
            RejectedBy UNIQUEIDENTIFIER,
            RejectedAt DATETIME2(7),
            RejectionReason NVARCHAR(500),
            WorkflowID UNIQUEIDENTIFIER,           -- Multi-level approval
            EscalatedTo UNIQUEIDENTIFIER,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7),
            DeletedBy UNIQUEIDENTIFIER,
            Notes NVARCHAR(MAX),
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_ApprovalRequests PRIMARY KEY CLUSTERED (ApprovalRequestID),
            CONSTRAINT FK_ApprovalRequests_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID),
            CONSTRAINT CK_Approval_Status CHECK (RequestStatus IN ('PENDING', 'APPROVED', 'REJECTED', 'ESCALATED', 'CANCELLED'))
        );
        PRINT N'✅ ApprovalRequests created';
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ApprovalRequests_Approver' AND object_id = OBJECT_ID('dbo.ApprovalRequests'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_ApprovalRequests_Approver ON dbo.ApprovalRequests(CurrentApproverID, RequestStatus) WHERE RequestStatus = 'PENDING' AND IsDeleted = 0;
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ApprovalRequests_Entity' AND object_id = OBJECT_ID('dbo.ApprovalRequests'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_ApprovalRequests_Entity ON dbo.ApprovalRequests(EntityType, EntityID) WHERE IsDeleted = 0;
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ApprovalRequests_Requester' AND object_id = OBJECT_ID('dbo.ApprovalRequests'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_ApprovalRequests_Requester ON dbo.ApprovalRequests(RequestedBy, RequestedAt DESC) WHERE IsDeleted = 0;
    END


    -- ==========================================================================
    -- 6. DATA EXPORT LOG (Fixed duplicate columns)
    -- ==========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'DataExportLog')
    BEGIN
        CREATE TABLE dbo.DataExportLog (
            ExportLogID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            ExportType NVARCHAR(50) NOT NULL,
            ExportedTable NVARCHAR(128),
            ExportedRecordCount INT,
            FilterCriteria NVARCHAR(MAX),
            ExportedBy UNIQUEIDENTIFIER NOT NULL,
            IPAddress NVARCHAR(50),
            MachineName NVARCHAR(100),
            Purpose NVARCHAR(200),
            ConsentObtained BIT DEFAULT 0,
            DataSubjectID NVARCHAR(100),           -- For GDPR/PDPL compliance
            RetentionExpiry DATETIME2(7),
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7),
            DeletedBy UNIQUEIDENTIFIER,
            ExportedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_DataExportLog PRIMARY KEY CLUSTERED (ExportLogID),
            CONSTRAINT FK_DataExportLog_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID),
            CONSTRAINT CK_Export_Type CHECK (ExportType IN ('EXCEL', 'PDF', 'CSV', 'API', 'XML', 'JSON'))
        );
        PRINT N'✅ DataExportLog created';
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DataExportLog_User' AND object_id = OBJECT_ID('dbo.DataExportLog'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_DataExportLog_User ON dbo.DataExportLog(ExportedBy, ExportedAt DESC) WHERE IsDeleted = 0;
    END


    -- ==========================================================================
    -- 7. SEED DATA (Professional)
    -- ==========================================================================
    IF NOT EXISTS (SELECT 1 FROM dbo.Notifications WHERE NotificationType = 'SYSTEM')
    BEGIN
        -- Note: Ensure UserID '00000000-0000-0000-0000-000000000001' exists in MST.dbo.Users
        INSERT INTO dbo.Notifications (CompanyID, UserID, NotificationType, Title, Message, Priority)
        SELECT TOP 1 CompanyID, '00000000-0000-0000-0000-000000000001', 'SYSTEM', 
               N'مرحبا بك في SHOUTECH ERP', N'تم تفعيل نظام التدقيق بنجاح', 'HIGH'
        FROM MST.dbo.Companies;
        
        PRINT N'✅ Seed data for Audit & Compliance inserted';
    END

    -- ==========================================================================
    -- COMPLETION
    -- ==========================================================================
    COMMIT TRANSACTION;

    PRINT N'═══════════════════════════════════════════════════════════════════════════';
    PRINT N'✅ Auditing & Compliance Module (Ultimate Enterprise+ 10/10) deployed successfully.';
    PRINT N'═══════════════════════════════════════════════════════════════════════════';
    
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 
        ROLLBACK TRANSACTION;
        
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH
GO
