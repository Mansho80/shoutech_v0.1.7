-- ========================================================================
-- FILE: dba/aud/log_ultimate.sql
-- PROJECT: SHOUTECH ERP V10 - ULTIMATE AUDIT & LOGGING SYSTEM (10.10.0)
-- DESCRIPTION: 
--   نظام تدقيق متكامل مع دعم توقيع البيانات، سلسلة الحفظ، التحليل الأمني،
--   الإشعارات متعددة القنوات، وإدارة المرفقات.

USE [$(DbFileName)];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

PRINT N'═══════════════════════════════════════════════════════════════════════';
PRINT N'SHOUTECH ERP V10 – ULTIMATE AUDIT & LOGGING SYSTEM (10.10.0)';
PRINT N'═══════════════════════════════════════════════════════════════════════';
GO

BEGIN TRY
    BEGIN TRANSACTION;

-- ========================================================================
-- القسم 1: سجل التدقيق الأساسي (AuditLog) – النسخة العملاقة
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'AuditLog')
    BEGIN
        CREATE TABLE dbo.AuditLog (
            AuditID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIET NOT NULL,
            
            -- معلومات الجلسة والمستخدم
            UserID UNIQUEIDENTIFIER NOT NULL,
            UserName NVARCHAR(100) NULL,
            SessionID UNIQUEIDENTIFIER NULL,             -- FK إلى UserSession
            
            -- معلومات الجهاز والموقع
            IPAddress NVARCHAR(45) NULL,
            Hostname NVARCHAR(100) NULL,
            UserAgent NVARCHAR(500) NULL,
            BrowserInfo NVARCHAR(200) NULL,
            DeviceInfo NVARCHAR(200) NULL,
            Geolocation NVARCHAR(100) NULL,              -- البلد/المدينة
            
            -- الكيان المتأثر
            DatabaseName NVARCHAR(128) NOT NULL DEFAULT DB_NAME(),
            SchemaName NVARCHAR(128) NOT NULL DEFAULT 'dbo',
            TableName NVARCHAR(128) NOT NULL,
            RecordID NVARCHAR(100) NOT NULL,
            RecordCode NVARCHAR(100) NULL,
            
            -- العملية
            ActionType NVARCHAR(20) NOT NULL,
            ActionDescription NVARCHAR(500) NULL,
            
            -- 🔥 البيانات قبل وبعد (JSON)
            OldData NVARCHAR(MAX) NULL,
            NewData NVARCHAR(MAX) NULL,
            ChangedFields NVARCHAR(MAX) NULL,            -- قائمة الحقول المتغيرة (مفصولة بـ ;)
            
            -- 🔥 توقيع البيانات (للتحقق من السلامة)
            DataHash NVARCHAR(64) NULL,                  -- SHA-256
            PreviousAuditID BIGINT NULL,                 -- سلسلة الحفظ (Chain of Custody)
            
            -- 🔥 مقاييس الأداء
            ExecutionTimeMS INT NULL,
            AffectedRows INT NULL,
            
            -- 🔥 تحليل الأمان
            ThreatLevel NVARCHAR(10) NOT NULL DEFAULT 'INFO',
            ThreatScore DECIMAL(5,2) NULL,               -- 0-100 درجة التهديد
            AnomalyDetected BIT NOT NULL DEFAULT 0,
            AnomalyReason NVARCHAR(200) NULL,
            
            -- التواريخ
            ActionDate DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            
            -- الحذف المنطقي
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (AuditID),
            CONSTRAINT FK_AuditLog_Previous FOREIGN KEY (PreviousAuditID) REFERENCES dbo.AuditLog(AuditID),
            CONSTRAINT CK_AuditLog_ActionType CHECK (ActionType IN 
                ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'EXPORT', 
                 'PRINT', 'VIEW', 'IMPORT', 'SYNC', 'CONFIG_CHANGE', 'SECURITY')),
            CONSTRAINT CK_AuditLog_ThreatLevel CHECK (ThreatLevel IN ('INFO', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [1] AuditLog table created (Enhanced with chain of custody).';
    END

    -- 🔥 فهارس الأداء
    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_AuditLog_Table_Record 
        ON dbo.AuditLog(TableName, RecordID, ActionDate DESC) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_AuditLog_User 
        ON dbo.AuditLog(UserID, ActionDate DESC) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_AuditLog_Session 
        ON dbo.AuditLog(SessionID, ActionDate DESC) WHERE SessionID IS NOT NULL AND IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_AuditLog_ActionDate 
        ON dbo.AuditLog(ActionDate DESC) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_AuditLog_Threat 
        ON dbo.AuditLog(ThreatLevel, AnomalyDetected) WHERE ThreatLevel IN ('HIGH', 'CRITICAL') AND IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_AuditLog_Previous 
        ON dbo.AuditLog(PreviousAuditID) WHERE PreviousAuditID IS NOT NULL AND IsDeleted = 0;

    -- Columnstore للتحليلات
    CREATE NONCLUSTERED COLUMNSTORE INDEX IF NOT EXISTS CSIX_AuditLog_Analytics 
        ON dbo.AuditLog (CompanyID, TableName, ActionType, ActionDate, UserID, ThreatLevel);
    GO

-- ========================================================================
-- القسم 2: تتبع الجلسات (UserSession) – ميزة تنافسية جديدة
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'UserSession')
    BEGIN
        CREATE TABLE dbo.UserSession (
            SessionID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            UserID UNIQUEIDENTIFIER NOT NULL,
            UserName NVARCHAR(100) NULL,
            
            -- معلومات الجلسة
            LoginTime DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            LogoutTime DATETIME2(7) NULL,
            LastActivityTime DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            SessionDuration AS DATEDIFF(SECOND, LoginTime, ISNULL(LogoutTime, GETDATE())) PERSISTED,
            
            -- معلومات الجهاز
            IPAddress NVARCHAR(45) NULL,
            Hostname NVARCHAR(100) NULL,
            UserAgent NVARCHAR(500) NULL,
            DeviceType NVARCHAR(20) NULL,               -- Desktop, Mobile, Tablet
            BrowserName NVARCHAR(50) NULL,
            
            -- معلومات الموقع
            Country NVARCHAR(50) NULL,
            City NVARCHAR(50) NULL,
            Latitude DECIMAL(10,7) NULL,
            Longitude DECIMAL(10,7) NULL,
            
            -- حالة الجلسة
            SessionStatus NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
            TerminationReason NVARCHAR(200) NULL,
            
            -- الأمان
            IsSuspicious BIT NOT NULL DEFAULT 0,
            SuspiciousReason NVARCHAR(200) NULL,
            MFAVerified BIT NOT NULL DEFAULT 0,
            
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_UserSession PRIMARY KEY CLUSTERED (SessionID),
            CONSTRAINT FK_UserSession_User FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID),
            CONSTRAINT CK_UserSession_Status CHECK (SessionStatus IN ('ACTIVE', 'IDLE', 'EXPIRED', 'LOGGED_OUT', 'TERMINATED')),
            CONSTRAINT CK_UserSession_Device CHECK (DeviceType IN ('Desktop', 'Mobile', 'Tablet', 'Other', NULL))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [2] UserSession table created (Session tracking).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_UserSession_User_Active 
        ON dbo.UserSession(UserID, SessionStatus) WHERE SessionStatus = 'ACTIVE' AND IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_UserSession_IP 
        ON dbo.UserSession(IPAddress) WHERE IsSuspicious = 1 AND IsDeleted = 0;
    GO

-- ========================================================================
-- القسم 3: سجل النشاط (ActivityLog) – النسخة المحسّنة
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ActivityLog')
    BEGIN
        CREATE TABLE dbo.ActivityLog (
            ActivityLogID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            UserID UNIQUEIDENTIFIER NULL,
            UserName NVARCHAR(100) NULL,
            SessionID UNIQUEIDENTIFIER NULL,             -- FK إلى UserSession
            
            -- النشاط
            ActivityType NVARCHAR(100) NOT NULL,
            ActivityCategory NVARCHAR(50) NULL,
            ActivityDescription NVARCHAR(500) NULL,
            
            -- الكيان المستهدف
            EntityType NVARCHAR(100) NULL,
            EntityID NVARCHAR(50) NULL,
            EntityName NVARCHAR(200) NULL,
            
            -- 🔥 مقاييس الأداء
            ActivityDurationMS INT NULL,
            ResponseTimeMS INT NULL,
            RecordsAffected INT NULL,
            
            -- البيانات
            Details NVARCHAR(MAX) NULL,
            Metadata NVARCHAR(MAX) NULL,
            
            -- معلومات الجهاز
            IPAddress NVARCHAR(45) NULL,
            BrowserInfo NVARCHAR(200) NULL,
            DeviceInfo NVARCHAR(200) NULL,
            
            -- 🔥 تحليل الأمان
            ThreatLevel NVARCHAR(10) NOT NULL DEFAULT 'INFO',
            ThreatScore DECIMAL(5,2) NULL,
            AnomalyDetected BIT NOT NULL DEFAULT 0,
            
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_ActivityLog PRIMARY KEY CLUSTERED (ActivityLogID),
            CONSTRAINT FK_ActivityLog_Session FOREIGN KEY (SessionID) REFERENCES dbo.UserSession(SessionID),
            CONSTRAINT CK_Activity_Threat CHECK (ThreatLevel IN ('INFO', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [3] ActivityLog table created (Enhanced with security analysis).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_ActivityLog_User_Date 
        ON dbo.ActivityLog(UserID, CreatedAt DESC) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_ActivityLog_Entity 
        ON dbo.ActivityLog(EntityType, EntityID) WHERE EntityType IS NOT NULL AND IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_ActivityLog_Session 
        ON dbo.ActivityLog(SessionID, CreatedAt DESC) WHERE SessionID IS NOT NULL AND IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_ActivityLog_Threats 
        ON dbo.ActivityLog(ThreatLevel, CreatedAt DESC) WHERE ThreatLevel IN ('HIGH', 'CRITICAL') AND IsDeleted = 0;

    -- Columnstore للتحليلات
    CREATE NONCLUSTERED COLUMNSTORE INDEX IF NOT EXISTS CSIX_ActivityLog_Analytics 
        ON dbo.ActivityLog (CompanyID, ActivityCategory, ActivityType, CreatedAt, UserID, ThreatLevel);
    GO

-- ========================================================================
-- القسم 4: إدارة المرفقات (Attachments) – النسخة المحسّنة
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Attachments')
    BEGIN
        CREATE TABLE dbo.Attachments (
            AttachmentID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            
            -- الكيان المرتبط
            EntityType NVARCHAR(50) NOT NULL,
            EntityID BIGINT NOT NULL,
            EntityFieldName NVARCHAR(50) NULL,           -- الحقل المرتبط (مثل الصورة الرئيسية)
            
            -- معلومات الملف
            FileName NVARCHAR(255) NOT NULL,
            OriginalFileName NVARCHAR(255) NOT NULL,
            FilePath NVARCHAR(1000) NOT NULL,
            FileSize BIGINT NOT NULL,
            MimeType NVARCHAR(100) NULL,
            FileExtension NVARCHAR(10) NULL,
            FileHash NVARCHAR(64) NULL,                  -- SHA-256
            
            -- 🔥 التشفير والأمان
            IsEncrypted BIT NOT NULL DEFAULT 0,
            EncryptionKeyID UNIQUEIDENTIFIER NULL,
            IsPublic BIT NOT NULL DEFAULT 0,
            
            -- 🔥 إدارة الإصدارات
            VersionNumber INT NOT NULL DEFAULT 1,
            ParentAttachmentID BIGINT NULL,              -- الإصدار السابق
            
            -- 🔥 مقاييس الاستخدام
            DownloadCount INT NOT NULL DEFAULT 0,
            LastAccessedAt DATETIME2(7) NULL,
            LastAccessedBy UNIQUEIDENTIFIER NULL,
            
            -- المعلومات الوصفية
            Description NVARCHAR(500) NULL,
            Tags NVARCHAR(500) NULL,
            
            -- الحذف المنطقي
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            UploadedBy UNIQUEIDENTIFIER NOT NULL,
            UploadedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_Attachments PRIMARY KEY CLUSTERED (AttachmentID),
            CONSTRAINT FK_Attachments_Parent FOREIGN KEY (ParentAttachmentID) REFERENCES dbo.Attachments(AttachmentID)
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [4] Attachments table created (Version control & encryption).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Attachments_Entity 
        ON dbo.Attachments(EntityType, EntityID) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Attachments_Company_Date 
        ON dbo.Attachments(CompanyID, UploadedAt DESC) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Attachments_Hash 
        ON dbo.Attachments(FileHash) WHERE FileHash IS NOT NULL AND IsDeleted = 0;
    GO

-- ========================================================================
-- القسم 5: نظام الإشعارات (Notifications) – النسخة المحسّنة
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Notifications')
    BEGIN
        CREATE TABLE dbo.Notifications (
            NotificationID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            UserID UNIQUEIDENTIFIER NOT NULL,
            
            -- نوع الإشعار
            NotificationType NVARCHAR(30) NOT NULL,
            NotificationCategory NVARCHAR(50) NULL,
            Priority NVARCHAR(10) NOT NULL DEFAULT 'NORMAL',
            
            -- المحتوى
            Title NVARCHAR(200) NOT NULL,
            Message NVARCHAR(MAX) NOT NULL,
            ActionURL NVARCHAR(500) NULL,
            ActionButtonText NVARCHAR(50) NULL,
            
            -- الكيان المرتبط
            EntityType NVARCHAR(50) NULL,
            EntityID NVARCHAR(50) NULL,
            
            -- 🔥 وسائل الإرسال المتعددة
            DeliveryMethod NVARCHAR(50) NOT NULL DEFAULT 'IN_APP', -- IN_APP, EMAIL, SMS, PUSH, ALL
            SentAt DATETIME2(7) NULL,
            DeliveredAt DATETIME2(7) NULL,
            
            -- حالة الإشعار
            IsRead BIT NOT NULL DEFAULT 0,
            ReadAt DATETIME2(7) NULL,
            IsDismissed BIT NOT NULL DEFAULT 0,
            DismissedAt DATETIME2(7) NULL,
            
            -- 🔥 تفاعل المستخدم
            ReadCount INT NOT NULL DEFAULT 0,
            ClickCount INT NOT NULL DEFAULT 0,
            LastClickAt DATETIME2(7) NULL,
            
            -- صلاحية الإشعار
            ExpiresAt DATETIME2(7) NULL,
            ExpiredAt DATETIME2(7) NULL,
            
            -- الإشعارات المتعلقة (للمحادثات/التنبيهات)
            ParentNotificationID BIGINT NULL,
            
            -- الحذف المنطقي
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_Notifications PRIMARY KEY CLUSTERED (NotificationID),
            CONSTRAINT FK_Notifications_User FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID),
            CONSTRAINT FK_Notifications_Parent FOREIGN KEY (ParentNotificationID) REFERENCES dbo.Notifications(NotificationID),
            CONSTRAINT CK_Notif_Type CHECK (NotificationType IN ('INFO', 'WARNING', 'ERROR', 'SUCCESS', 'REMINDER', 'ALERT')),
            CONSTRAINT CK_Notif_Priority CHECK (Priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [5] Notifications table created (Multi-channel).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Notifications_User_Unread 
        ON dbo.Notifications(UserID, IsRead, CreatedAt DESC) 
        WHERE IsRead = 0 AND IsDismissed = 0 AND IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Notifications_User_All 
        ON dbo.Notifications(UserID, CreatedAt DESC) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Notifications_Expired 
        ON dbo.Notifications(ExpiresAt) WHERE ExpiresAt IS NOT NULL AND IsDismissed = 0 AND IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Notifications_Delivery 
        ON dbo.Notifications(DeliveryMethod, SentAt) WHERE SentAt IS NULL AND IsDeleted = 0;
    GO

-- ========================================================================
-- القسم 6: سجل تصدير البيانات (DataExportLog) – النسخة المحسّنة
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'DataExportLog')
    BEGIN
        CREATE TABLE dbo.DataExportLog (
            ExportLogID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            
            -- معلومات التصدير
            ExportType NVARCHAR(50) NOT NULL,
            ExportFormat NVARCHAR(20) NOT NULL,
            ExportStatus NVARCHAR(20) NOT NULL DEFAULT 'PROCESSING',
            
            -- البيانات المصدرة
            ExportedTable NVARCHAR(128) NULL,
            ExportedRecordCount INT NULL,
            FilterCriteria NVARCHAR(MAX) NULL,
            DataRange NVARCHAR(20) NOT NULL DEFAULT 'ALL', -- ALL, FILTERED, SAMPLE
            
            -- مقاييس التصدير
            ExportDurationMS INT NULL,
            FileSize BIGINT NULL,
            
            -- تشفير الملف المصدر
            IsEncrypted BIT NOT NULL DEFAULT 0,
            EncryptionKeyID UNIQUEIDENTIFIER NULL,
            
            -- معلومات التصدير
            ExportedBy UNIQUEIDENTIFIER NOT NULL,
            IPAddress NVARCHAR(45) NULL,
            MachineName NVARCHAR(100) NULL,
            Purpose NVARCHAR(200) NULL,
            FilePath NVARCHAR(500) NULL,
            FileName NVARCHAR(255) NULL,
            
            -- الحذف المنطقي
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            ExportedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            CompletedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_DataExportLog PRIMARY KEY CLUSTERED (ExportLogID),
            CONSTRAINT CK_Export_Type CHECK (ExportType IN ('USER_DATA', 'FINANCIAL', 'INVENTORY', 'CRM', 'CUSTOM', 'REPORT')),
            CONSTRAINT CK_Export_Format CHECK (ExportFormat IN ('EXCEL', 'PDF', 'CSV', 'API', 'XML', 'JSON', 'XLSX', 'HTML')),
            CONSTRAINT CK_Export_Status CHECK (ExportStatus IN ('PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [6] DataExportLog table created (Enhanced).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_DataExportLog_User 
        ON dbo.DataExportLog(ExportedBy, ExportedAt DESC) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_DataExportLog_Status 
        ON dbo.DataExportLog(ExportStatus, ExportedAt) WHERE ExportStatus = 'PROCESSING' AND IsDeleted = 0;
    GO

-- ========================================================================
-- القسم 7: سياسات التدقيق (AuditPolicy) – متكامل مع retn.sql
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'AuditPolicy')
    BEGIN
        CREATE TABLE dbo.AuditPolicy (
            PolicyID INT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            TableName NVARCHAR(128) NOT NULL,
            
            -- ما الذي يتم تدقيقه
            AuditInsert BIT NOT NULL DEFAULT 1,
            AuditUpdate BIT NOT NULL DEFAULT 1,
            AuditDelete BIT NOT NULL DEFAULT 1,
            AuditView BIT NOT NULL DEFAULT 0,
            AuditExport BIT NOT NULL DEFAULT 0,
            
            -- 🔥 الحقول المستثناة من التدقيق (للمعلومات الحساسة)
            ExcludedFields NVARCHAR(MAX) NULL,            -- مفصولة بـ ;
            
            -- 🔥 مستوى التفاصيل
            LogLevel NVARCHAR(20) NOT NULL DEFAULT 'FULL', -- FULL, CHANGES_ONLY, SUMMMARY
            LogOldData BIT NOT NULL DEFAULT 1,
            LogNewData BIT NOT NULL DEFAULT 1,
            
            IsActive BIT NOT NULL DEFAULT 1,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_AuditPolicy PRIMARY KEY CLUSTERED (PolicyID),
            CONSTRAINT UQ_AuditPolicy_Table UNIQUE (CompanyID, TableName),
            CONSTRAINT CK_AuditPolicy_LogLevel CHECK (LogLevel IN ('FULL', 'CHANGES_ONLY', 'SUMMARY'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [7] AuditPolicy table created (Granular control).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_AuditPolicy_Company_Active 
        ON dbo.AuditPolicy(CompanyID, IsActive) WHERE IsDeleted = 0;
    GO

-- ========================================================================
-- القسم 8: كشف الشذوذ الأمني (AuditAnomaly) – AI Ready
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'AuditAnomaly')
    BEGIN
        CREATE TABLE dbo.AuditAnomaly (
            AnomalyID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            
            -- المرجع
            AuditID BIGINT NULL,                         -- FK إلى AuditLog
            ActivityLogID BIGINT NULL,                   -- FK إلى ActivityLog
            UserSessionID UNIQUEIDENTIFIER NULL,         -- FK إلى UserSession
            
            -- نوع الشذوذ
            AnomalyType NVARCHAR(50) NOT NULL,
            AnomalySeverity NVARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
            AnomalyScore DECIMAL(5,2) NOT NULL,           -- 0-100
            
            -- التفاصيل
            DetectionMethod NVARCHAR(50) NOT NULL,        -- RULE_BASED, ML_MODEL, HEURISTIC
            DetectionDescription NVARCHAR(500) NULL,
            DetectionData NVARCHAR(MAX) NULL,             -- JSON للمزيد من التفاصيل
            
            -- الحالة
            Status NVARCHAR(20) NOT NULL DEFAULT 'OPEN',
            InvestigationNotes NVARCHAR(MAX) NULL,
            ResolvedAt DATETIME2(7) NULL,
            ResolvedBy UNIQUEIDENTIFIER NULL,
            
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            DetectedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_AuditAnomaly PRIMARY KEY CLUSTERED (AnomalyID),
            CONSTRAINT FK_AuditAnomaly_Audit FOREIGN KEY (AuditID) REFERENCES dbo.AuditLog(AuditID),
            CONSTRAINT FK_AuditAnomaly_Activity FOREIGN KEY (ActivityLogID) REFERENCES dbo.ActivityLog(ActivityLogID),
            CONSTRAINT CK_AuditAnomaly_Type CHECK (AnomalyType IN ('UNUSUAL_TIME', 'UNUSUAL_IP', 'BULK_OPERATION', 'FAILED_LOGIN', 'UNUSUAL_ACCESS', 'DATA_EXFILTRATION')),
            CONSTRAINT CK_AuditAnomaly_Severity CHECK (AnomalySeverity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
            CONSTRAINT CK_AuditAnomaly_Status CHECK (Status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'FALSE_POSITIVE'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [8] AuditAnomaly table created (AI-ready).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_AuditAnomaly_Status_Score 
        ON dbo.AuditAnomaly(Status, AnomalyScore DESC) WHERE Status IN ('OPEN', 'INVESTIGATING') AND IsDeleted = 0;

    CREATE NONCLUSTERED COLUMNSTORE INDEX IF NOT EXISTS CSIX_AuditAnomaly_Analytics 
        ON dbo.AuditAnomaly (CompanyID, AnomalyType, AnomalySeverity, DetectedAt, AnomalyScore);
    GO

-- ========================================================================
-- القسم 9: الإجراءات المخزنة (Stored Procedures)
-- ========================================================================

-- 9.1 🔥 تسجيل تدقيق موحد (يستخدم من جميع المشغلات)
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Audit_Log')
    DROP PROCEDURE dbo.usp_Audit_Log;
GO
CREATE PROCEDURE dbo.usp_Audit_Log
    @CompanyID UNIQUEIDENTIFIER,
    @TableName NVARCHAR(128),
    @RecordID NVARCHAR(100),
    @ActionType NVARCHAR(20),
    @UserID UNIQUEIDENTIFIER,
    @UserName NVARCHAR(100) = NULL,
    @SessionID UNIQUEIDENTIFIER = NULL,
    @OldData NVARCHAR(MAX) = NULL,
    @NewData NVARCHAR(MAX) = NULL,
    @ChangedFields NVARCHAR(MAX) = NULL,
    @ActionDescription NVARCHAR(500) = NULL,
    @IPAddress NVARCHAR(45) = NULL,
    @UserAgent NVARCHAR(500) = NULL,
    @ExecutionTimeMS INT = NULL,
    @AffectedRows INT = NULL,
    @ThreatLevel NVARCHAR(10) = 'INFO',
    @ThreatScore DECIMAL(5,2) = NULL,
    @RecordCode NVARCHAR(100) = NULL,
    @PreviousAuditID BIGINT = NULL,
    @NewAuditID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- حساب التجزئة (للتحقق من السلامة)
    DECLARE @DataHash NVARCHAR(64) = NULL;
    IF @OldData IS NOT NULL OR @NewData IS NOT NULL
    BEGIN
        DECLARE @HashData NVARCHAR(MAX) = 
            ISNULL(@TableName, '') + '|' + 
            ISNULL(@RecordID, '') + '|' + 
            ISNULL(@ActionType, '') + '|' + 
            ISNULL(@OldData, '') + '|' + 
            ISNULL(@NewData, '') + '|' + 
            FORMAT(SYSUTCDATETIME(), 'yyyyMMddHHmmssfff');
        
        SET @DataHash = CONVERT(NVARCHAR(64), HASHBYTES('SHA2_256', @HashData), 2);
    END
    
    INSERT INTO dbo.AuditLog (
        CompanyID, UserID, UserName, SessionID,
        TableName, RecordID, RecordCode, ActionType, ActionDescription,
        OldData, NewData, ChangedFields, DataHash, PreviousAuditID,
        ExecutionTimeMS, AffectedRows, ThreatLevel, ThreatScore,
        IPAddress, UserAgent, ActionDate, CreatedBy
    ) VALUES (
        @CompanyID, @UserID, @UserName, @SessionID,
        @TableName, @RecordID, @RecordCode, @ActionType, @ActionDescription,
        @OldData, @NewData, @ChangedFields, @DataHash, @PreviousAuditID,
        @ExecutionTimeMS, @AffectedRows, @ThreatLevel, @ThreatScore,
        @IPAddress, @UserAgent, SYSUTCDATETIME(), @UserID
    );
    
    SET @NewAuditID = SCOPE_IDENTITY();
END;
GO
PRINT N'✅ [9.1] usp_Audit_Log created (Universal audit logger).';


-- 9.2 🔥 بدء جلسة مستخدم (Login)
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Audit_StartSession')
    DROP PROCEDURE dbo.usp_Audit_StartSession;
GO
CREATE PROCEDURE dbo.usp_Audit_StartSession
    @CompanyID UNIQUEIDENTIFIER,
    @UserID UNIQUEIDENTIFIER,
    @UserName NVARCHAR(100) = NULL,
    @IPAddress NVARCHAR(45) = NULL,
    @UserAgent NVARCHAR(500) = NULL,
    @DeviceType NVARCHAR(20) = NULL,
    @BrowserName NVARCHAR(50) = NULL,
    @Country NVARCHAR(50) = NULL,
    @City NVARCHAR(50) = NULL,
    @MFAVerified BIT = 0,
    @SessionID UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @SessionID = NEWID();
    
    -- إنشاء الجلسة
    INSERT INTO dbo.UserSession (
        SessionID, CompanyID, UserID, UserName, IPAddress, UserAgent,
        DeviceType, BrowserName, Country, City, MFAVerified, SessionStatus
    ) VALUES (
        @SessionID, @CompanyID, @UserID, @UserName, @IPAddress, @UserAgent,
        @DeviceType, @BrowserName, @Country, @City, @MFAVerified, 'ACTIVE'
    );
    
    -- تسجيل في AuditLog (حدث تسجيل دخول)
    DECLARE @AuditID BIGINT;
    EXEC dbo.usp_Audit_Log
        @CompanyID = @CompanyID,
        @TableName = 'UserSession',
        @RecordID = CAST(@SessionID AS NVARCHAR(100)),
        @ActionType = 'LOGIN',
        @UserID = @UserID,
        @UserName = @UserName,
        @SessionID = @SessionID,
        @ActionDescription = N'تسجيل دخول المستخدم ' + ISNULL(@UserName, CAST(@UserID AS NVARCHAR)),
        @IPAddress = @IPAddress,
        @UserAgent = @UserAgent,
        @NewAuditID = @AuditID OUTPUT;
END;
GO
PRINT N'✅ [9.2] usp_Audit_StartSession created (Login tracking).';


-- 9.3 🔥 إنهاء جلسة مستخدم (Logout)
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Audit_EndSession')
    DROP PROCEDURE dbo.usp_Audit_EndSession;
GO
CREATE PROCEDURE dbo.usp_Audit_EndSession
    @SessionID UNIQUEIDENTIFIER,
    @TerminationReason NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE dbo.UserSession
    SET LogoutTime = SYSUTCDATETIME(),
        SessionStatus = 'LOGGED_OUT',
        TerminationReason = @TerminationReason
    WHERE SessionID = @SessionID AND SessionStatus = 'ACTIVE';
    
    -- تسجيل في AuditLog (حدث تسجيل خروج)
    DECLARE @CompanyID UNIQUEIDENTIFIER;
    DECLARE @UserID UNIQUEIDENTIFIER;
    DECLARE @UserName NVARCHAR(100);
    
    SELECT @CompanyID = CompanyID, @UserID = UserID, @UserName = UserName
    FROM dbo.UserSession WHERE SessionID = @SessionID;
    
    DECLARE @AuditID BIGINT;
    EXEC dbo.usp_Audit_Log
        @CompanyID = @CompanyID,
        @TableName = 'UserSession',
        @RecordID = CAST(@SessionID AS NVARCHAR(100)),
        @ActionType = 'LOGOUT',
        @UserID = @UserID,
        @UserName = @UserName,
        @SessionID = @SessionID,
        @ActionDescription = N'تسجيل خروج المستخدم ' + ISNULL(@UserName, CAST(@UserID AS NVARCHAR)),
        @NewAuditID = @AuditID OUTPUT;
END;
GO
PRINT N'✅ [9.3] usp_Audit_EndSession created (Logout tracking).';


-- 9.4 🔥 البحث في سجل التدقيق
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Audit_Search')
    DROP PROCEDURE dbo.usp_Audit_Search;
GO
CREATE PROCEDURE dbo.usp_Audit_Search
    @CompanyID UNIQUEIDENTIFIER,
    @TableName NVARCHAR(128) = NULL,
    @RecordID NVARCHAR(100) = NULL,
    @UserID UNIQUEIDENTIFIER = NULL,
    @ActionType NVARCHAR(20) = NULL,
    @FromDate DATETIME2(7) = NULL,
    @ToDate DATETIME2(7) = NULL,
    @ThreatLevel NVARCHAR(10) = NULL,
    @AnomalyDetected BIT = NULL,
    @TopN INT = 100,
    @SearchTerm NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -30, GETDATE());
    IF @ToDate IS NULL SET @ToDate = GETDATE();
    
    SELECT TOP (@TopN)
        AuditID, UserID, UserName, SessionID,
        TableName, RecordID, RecordCode, ActionType, ActionDescription,
        ChangedFields, DataHash, ExecutionTimeMS, AffectedRows,
        ThreatLevel, ThreatScore, AnomalyDetected, AnomalyReason,
        ActionDate
    FROM dbo.AuditLog
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND ActionDate BETWEEN @FromDate AND @ToDate
        AND (@TableName IS NULL OR TableName = @TableName)
        AND (@RecordID IS NULL OR RecordID = @RecordID)
        AND (@UserID IS NULL OR UserID = @UserID)
        AND (@ActionType IS NULL OR ActionType = @ActionType)
        AND (@ThreatLevel IS NULL OR ThreatLevel = @ThreatLevel)
        AND (@AnomalyDetected IS NULL OR AnomalyDetected = @AnomalyDetected)
        AND (@SearchTerm IS NULL 
            OR ActionDescription LIKE N'%' + @SearchTerm + N'%'
            OR TableName LIKE N'%' + @SearchTerm + N'%'
            OR RecordID LIKE N'%' + @SearchTerm + N'%')
    ORDER BY ActionDate DESC;
END;
GO
PRINT N'✅ [9.4] usp_Audit_Search created (Audit search).';


-- 9.5 🔥 تقرير نشاط المستخدمين
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Audit_Report_UserActivity')
    DROP PROCEDURE dbo.usp_Audit_Report_UserActivity;
GO
CREATE PROCEDURE dbo.usp_Audit_Report_UserActivity
    @CompanyID UNIQUEIDENTIFIER,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL,
    @UserID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -30, GETDATE());
    IF @ToDate IS NULL SET @ToDate = GETDATE();
    
    SELECT 
        u.UserID,
        u.UserName,
        COUNT(a.AuditID) AS TotalActions,
        COUNT(DISTINCT a.TableName) AS TablesAccessed,
        SUM(CASE WHEN a.ActionType = 'INSERT' THEN 1 ELSE 0 END) AS Inserts,
        SUM(CASE WHEN a.ActionType = 'UPDATE' THEN 1 ELSE 0 END) AS Updates,
        SUM(CASE WHEN a.ActionType = 'DELETE' THEN 1 ELSE 0 END) AS Deletes,
        SUM(CASE WHEN a.ActionType = 'VIEW' THEN 1 ELSE 0 END) AS Views,
        SUM(CASE WHEN a.ActionType = 'EXPORT' THEN 1 ELSE 0 END) AS Exports,
        SUM(CASE WHEN a.ThreatLevel IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) AS HighThreatActions,
        AVG(a.ExecutionTimeMS) AS AvgExecutionTime,
        MIN(a.ActionDate) AS FirstAction,
        MAX(a.ActionDate) AS LastAction,
        DATEDIFF(SECOND, MIN(a.ActionDate), MAX(a.ActionDate)) AS ActivityDuration
    FROM dbo.AuditLog a
    LEFT JOIN dbo.Users u ON a.UserID = u.UserID
    WHERE a.CompanyID = @CompanyID
        AND a.IsDeleted = 0
        AND CAST(a.ActionDate AS DATE) BETWEEN @FromDate AND @ToDate
        AND (@UserID IS NULL OR a.UserID = @UserID)
    GROUP BY u.UserID, u.UserName
    ORDER BY TotalActions DESC;
END;
GO
PRINT N'✅ [9.5] usp_Audit_Report_UserActivity created (User activity report).';


-- 9.6 🔥 تقرير نشاط الجداول
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Audit_Report_TableActivity')
    DROP PROCEDURE dbo.usp_Audit_Report_TableActivity;
GO
CREATE PROCEDURE dbo.usp_Audit_Report_TableActivity
    @CompanyID UNIQUEIDENTIFIER,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL,
    @TableName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -30, GETDATE());
    IF @ToDate IS NULL SET @ToDate = GETDATE();
    
    SELECT 
        TableName,
        COUNT(AuditID) AS TotalActions,
        COUNT(DISTINCT UserID) AS UniqueUsers,
        SUM(CASE WHEN ActionType = 'INSERT' THEN 1 ELSE 0 END) AS Inserts,
        SUM(CASE WHEN ActionType = 'UPDATE' THEN 1 ELSE 0 END) AS Updates,
        SUM(CASE WHEN ActionType = 'DELETE' THEN 1 ELSE 0 END) AS Deletes,
        SUM(CASE WHEN ActionType = 'VIEW' THEN 1 ELSE 0 END) AS Views,
        SUM(CASE WHEN ThreatLevel IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) AS HighThreatActions,
        COUNT(DISTINCT RecordID) AS UniqueRecords,
        MIN(ActionDate) AS FirstAction,
        MAX(ActionDate) AS LastAction
    FROM dbo.AuditLog
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND CAST(ActionDate AS DATE) BETWEEN @FromDate AND @ToDate
        AND (@TableName IS NULL OR TableName = @TableName)
    GROUP BY TableName
    ORDER BY TotalActions DESC;
END;
GO
PRINT N'✅ [9.6] usp_Audit_Report_TableActivity created (Table activity report).';


-- 9.7 🔥 كشف الشذوذ (AI Ready)
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Audit_DetectAnomalies')
    DROP PROCEDURE dbo.usp_Audit_DetectAnomalies;
GO
CREATE PROCEDURE dbo.usp_Audit_DetectAnomalies
    @CompanyID UNIQUEIDENTIFIER,
    @DaysBack INT = 7,
    @MinScore DECIMAL(5,2) = 50
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CutoffDate DATETIME2(7) = DATEADD(DAY, -@DaysBack, GETDATE());
    
    -- 1. نشاط غير عادي في الوقت (ساعات متأخرة)
    INSERT INTO dbo.AuditAnomaly (
        CompanyID, AuditID, AnomalyType, AnomalySeverity, AnomalyScore,
        DetectionMethod, DetectionDescription, Status
    )
    SELECT TOP 100
        @CompanyID,
        AuditID,
        'UNUSUAL_TIME',
        CASE WHEN DATEPART(HOUR, ActionDate) BETWEEN 0 AND 5 THEN 'HIGH' 
             WHEN DATEPART(HOUR, ActionDate) BETWEEN 22 AND 23 THEN 'MEDIUM'
             ELSE 'LOW' END,
        CASE WHEN DATEPART(HOUR, ActionDate) BETWEEN 0 AND 5 THEN 80
             WHEN DATEPART(HOUR, ActionDate) BETWEEN 22 AND 23 THEN 60
             ELSE 40 END,
        'RULE_BASED',
        N'نشاط في وقت غير معتاد: ' + CAST(DATEPART(HOUR, ActionDate) AS NVARCHAR) + N':00',
        'OPEN'
    FROM dbo.AuditLog
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND ActionDate >= @CutoffDate
        AND (DATEPART(HOUR, ActionDate) BETWEEN 0 AND 5 OR DATEPART(HOUR, ActionDate) BETWEEN 22 AND 23)
        AND UserID NOT IN (SELECT UserID FROM dbo.Users WHERE IsAdmin = 1)
        AND NOT EXISTS (
            SELECT 1 FROM dbo.AuditAnomaly 
            WHERE AuditID = AuditLog.AuditID AND AnomalyType = 'UNUSUAL_TIME'
        );
    
    -- 2. عمليات حذف كبيرة (حذف أكثر من 100 سجل)
    INSERT INTO dbo.AuditAnomaly (
        CompanyID, AuditID, AnomalyType, AnomalySeverity, AnomalyScore,
        DetectionMethod, DetectionDescription, Status
    )
    SELECT TOP 100
        @CompanyID,
        AuditID,
        'BULK_OPERATION',
        CASE WHEN AffectedRows > 1000 THEN 'CRITICAL'
             WHEN AffectedRows > 500 THEN 'HIGH'
             WHEN AffectedRows > 100 THEN 'MEDIUM'
             ELSE 'LOW' END,
        CASE WHEN AffectedRows > 1000 THEN 90
             WHEN AffectedRows > 500 THEN 75
             WHEN AffectedRows > 100 THEN 60
             ELSE 40 END,
        'RULE_BASED',
        N'عملية حذف كبيرة: ' + CAST(AffectedRows AS NVARCHAR) + N' سجل',
        'OPEN'
    FROM dbo.AuditLog
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND ActionType = 'DELETE'
        AND ActionDate >= @CutoffDate
        AND AffectedRows >= 100
        AND NOT EXISTS (
            SELECT 1 FROM dbo.AuditAnomaly 
            WHERE AuditID = AuditLog.AuditID AND AnomalyType = 'BULK_OPERATION'
        );
    
    PRINT N'✅ شذوذات تم اكتشافها وتخزينها في AuditAnomaly.';
END;
GO
PRINT N'✅ [9.7] usp_Audit_DetectAnomalies created (AI-ready anomaly detection).';

-- ========================================================================
-- القسم 10: طرق العرض (Views)
-- ========================================================================

-- 10.1 سلسلة التدقيق الكاملة (Chain of Custody)
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_AuditTrail')
    DROP VIEW dbo.vw_AuditTrail;
GO
CREATE VIEW dbo.vw_AuditTrail
AS
WITH AuditChain AS (
    SELECT 
        AuditID, TableName, RecordID, ActionType, UserID, UserName,
        ActionDate, DataHash, PreviousAuditID, 0 AS Depth
    FROM dbo.AuditLog
    WHERE IsDeleted = 0 AND PreviousAuditID IS NULL
    
    UNION ALL
    
    SELECT 
        a.AuditID, a.TableName, a.RecordID, a.ActionType, a.UserID, a.UserName,
        a.ActionDate, a.DataHash, a.PreviousAuditID, ac.Depth + 1
    FROM dbo.AuditLog a
    INNER JOIN AuditChain ac ON a.PreviousAuditID = ac.AuditID
    WHERE a.IsDeleted = 0
)
SELECT * FROM AuditChain;
GO
PRINT N'✅ [10.1] vw_AuditTrail created (Chain of custody).';

-- 10.2 خلاصة التدقيق
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_AuditSummary')
    DROP VIEW dbo.vw_AuditSummary;
GO
CREATE VIEW dbo.vw_AuditSummary
AS
SELECT 
    CompanyID,
    TableName,
    COUNT(AuditID) AS TotalActions,
    COUNT(DISTINCT UserID) AS UniqueUsers,
    COUNT(DISTINCT CAST(ActionDate AS DATE)) AS UniqueDays,
    SUM(CASE WHEN ActionType = 'INSERT' THEN 1 ELSE 0 END) AS Inserts,
    SUM(CASE WHEN ActionType = 'UPDATE' THEN 1 ELSE 0 END) AS Updates,
    SUM(CASE WHEN ActionType = 'DELETE' THEN 1 ELSE 0 END) AS Deletes,
    SUM(CASE WHEN ActionType = 'VIEW' THEN 1 ELSE 0 END) AS Views,
    SUM(CASE WHEN ActionType IN ('LOGIN', 'LOGOUT') THEN 1 ELSE 0 END) AS Logins,
    SUM(CASE WHEN ThreatLevel IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) AS SecurityIncidents,
    MIN(ActionDate) AS FirstAction,
    MAX(ActionDate) AS LastAction
FROM dbo.AuditLog
WHERE IsDeleted = 0
GROUP BY CompanyID, TableName;
GO
PRINT N'✅ [10.2] vw_AuditSummary created (Audit summary).';

-- 10.3 إشعارات غير مقروءة للمستخدم
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_UserNotifications')
    DROP VIEW dbo.vw_UserNotifications;
GO
CREATE VIEW dbo.vw_UserNotifications
AS
SELECT 
    n.NotificationID,
    n.UserID,
    n.NotificationType,
    n.Priority,
    n.Title,
    n.Message,
    n.ActionURL,
    n.ActionButtonText,
    n.EntityType,
    n.EntityID,
    n.DeliveryMethod,
    n.SentAt,
    n.IsRead,
    n.IsDismissed,
    n.ExpiresAt,
    u.UserName AS CreatedByUserName,
    n.CreatedAt
FROM dbo.Notifications n
LEFT JOIN dbo.Users u ON n.CreatedBy = u.UserID
WHERE n.IsDeleted = 0;
GO
PRINT N'✅ [10.3] vw_UserNotifications created (User notifications).';

-- ========================================================================
-- القسم 11: البيانات الأولية (Seed Data)
-- ========================================================================
    DECLARE @SystemCompanyID UNIQUEIDENTIFIER;
    DECLARE @SystemUserID UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000001';
    SELECT TOP 1 @SystemCompanyID = CompanyID FROM MST.dbo.Companies;

    -- سياسات التدقيق الافتراضية
    IF NOT EXISTS (SELECT 1 FROM dbo.AuditPolicy WHERE TableName = 'Customers' AND CompanyID = @SystemCompanyID)
    BEGIN
        INSERT INTO dbo.AuditPolicy (
            CompanyID, TableName, AuditInsert, AuditUpdate, AuditDelete, AuditView, AuditExport,
            LogLevel, LogOldData, LogNewData, IsActive, CreatedBy
        ) VALUES 
            (@SystemCompanyID, 'Customers', 1, 1, 1, 0, 1, 'FULL', 1, 1, 1, @SystemUserID),
            (@SystemCompanyID, 'Suppliers', 1, 1, 1, 0, 1, 'FULL', 1, 1, 1, @SystemUserID),
            (@SystemCompanyID, 'Products', 1, 1, 1, 0, 1, 'FULL', 1, 1, 1, @SystemUserID),
            (@SystemCompanyID, 'Invoices', 1, 1, 1, 0, 1, 'FULL', 1, 1, 1, @SystemUserID),
            (@SystemCompanyID, 'StockBalances', 1, 1, 1, 0, 0, 'CHANGES_ONLY', 1, 1, 1, @SystemUserID),
            (@SystemCompanyID, 'FinancialLedger', 1, 1, 0, 0, 0, 'FULL', 1, 1, 1, @SystemUserID);
        PRINT N'✅ [11] Default audit policies seeded.';
    END

-- ========================================================================
-- الخاتمة
-- ========================================================================
    
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
END CATCH
GO