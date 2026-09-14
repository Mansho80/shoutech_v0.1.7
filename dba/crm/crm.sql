-- ========================================================================
-- FILE: dba/sch/crm_upgrade.sql
-- PROJECT: SHOUTECH ERP V10 - CRM Module (UPGRADE to 10/10 ULTIMATE)
-- VERSION: 10.7.0
-- DESCRIPTION: 
--   إضافة الميزات المفقودة لنظام CRM: جهات الاتصال، العملاء المتوقعون،
--   تتبع المبيعات، التسويق، دعم العملاء، والتكامل مع AuditLog.
-- ========================================================================

USE [$(DbFileName)];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

PRINT N'═══════════════════════════════════════════════════════════════════════';
PRINT N'SHOUTECH ERP V10 – CRM MODULE (UPGRADE to 10.10.0 ULTIMATE)';
PRINT N'═══════════════════════════════════════════════════════════════════════';
GO

BEGIN TRY
    BEGIN TRANSACTION;

-- ========================================================================
-- 1. إضافة حقول جديدة إلى Customers (لتكامل Leads و Marketing)
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Customers') AND name = 'LeadSource')
    BEGIN
        ALTER TABLE dbo.Customers ADD 
            LeadSource NVARCHAR(50) NULL,
            LeadSourceDetails NVARCHAR(200) NULL,
            FirstContactDate DATE NULL,
            AcquisitionCost DECIMAL(18,2) NULL,
            PreferredLanguage NVARCHAR(10) NULL DEFAULT 'AR',
            CommunicationPreferences NVARCHAR(200) NULL,
            LastMarketingEmailSent DATE NULL,
            MarketingOptOut BIT NOT NULL DEFAULT 0,
            DataPrivacyConsentDate DATE NULL,
            DataPrivacyConsentVersion NVARCHAR(20) NULL;
        PRINT N'✅ [1] Added marketing and acquisition fields to Customers.';
    END

-- ========================================================================
-- 2. جدول العملاء المتوقعون (Leads) – مدمج مع CRM
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Leads')
    BEGIN
        CREATE TABLE dbo.Leads (
            LeadID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            BranchID UNIQUEIDENTIFIER NULL,
            
            -- المعلومات الأساسية
            LeadCode NVARCHAR(50) NOT NULL,
            LeadName NVARCHAR(255) NOT NULL,
            LeadNameEN NVARCHAR(255) NULL,
            LeadDescription NVARCHAR(MAX) NULL,
            
            -- معلومات الاتصال
            ContactPerson NVARCHAR(200) NULL,
            Phone NVARCHAR(50) NULL,
            Mobile NVARCHAR(50) NULL,
            Email NVARCHAR(255) NULL,
            Website NVARCHAR(255) NULL,
            
            -- العنوان
            City NVARCHAR(100) NULL,
            State NVARCHAR(100) NULL,
            Country NVARCHAR(100) DEFAULT N'المملكة العربية السعودية',
            
            -- 🔥 مصدر العميل المتوقع
            LeadSource NVARCHAR(50) NULL,
            LeadSourceDetails NVARCHAR(200) NULL,
            
            -- 🔥 مراحل التحويل (Sales Pipeline)
            LeadStage NVARCHAR(30) NOT NULL DEFAULT 'NEW',
            LeadScore DECIMAL(5,2) NULL,
            ConversionProbability DECIMAL(5,4) NULL,
            ExpectedValue DECIMAL(18,2) NULL,
            ExpectedCloseDate DATE NULL,
            ActualCloseDate DATE NULL,
            
            -- المندوب المسؤول
            AssignedToSalesPersonID UNIQUEIDENTIFIER NULL,
            AssignedAt DATETIME2(7) NULL,
            
            -- ZATCA (لدعم العملاء المتوقعين)
            TaxNumber NVARCHAR(100) NULL,
            VATCategory NVARCHAR(10) NULL DEFAULT 'B2C',
            ZATCAComplianceStatus NVARCHAR(20) NULL DEFAULT 'PENDING',
            
            -- المراجع
            RejectReason NVARCHAR(200) NULL,
            Notes NVARCHAR(MAX) NULL,
            
            -- حالة السجل
            IsActive BIT NOT NULL DEFAULT 1,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_Leads PRIMARY KEY CLUSTERED (LeadID),
            CONSTRAINT UQ_Leads_Code UNIQUE (CompanyID, LeadCode),
            CONSTRAINT FK_Leads_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID),
            CONSTRAINT CK_Leads_Stage CHECK (LeadStage IN ('NEW', 'CONTACTED', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'CLOSED_WON', 'CLOSED_LOST')),
            CONSTRAINT CK_Leads_VAT CHECK (VATCategory IN ('B2B', 'B2C', NULL)),
            CONSTRAINT CK_Leads_ZATCA CHECK (ZATCAComplianceStatus IN ('PENDING', 'VERIFIED', 'REJECTED', NULL))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [2] Leads table created (Integrated with CRM).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Leads_Company_Stage 
        ON dbo.Leads(CompanyID, LeadStage, IsActive) INCLUDE (LeadCode, LeadName, Phone, Mobile, ExpectedValue) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Leads_Probability 
        ON dbo.Leads(ConversionProbability DESC, ExpectedCloseDate) WHERE LeadStage NOT IN ('CLOSED_WON', 'CLOSED_LOST') AND IsDeleted = 0;

    CREATE NONCLUSTERED COLUMNSTORE INDEX IF NOT EXISTS CSIX_Leads_Analytics 
        ON dbo.Leads (LeadSource, LeadStage, ConversionProbability, ExpectedValue, CreatedAt);
    GO

-- ========================================================================
-- 3. جدول تتبع المبيعات (SalesPipeline)
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'SalesPipeline')
    BEGIN
        CREATE TABLE dbo.SalesPipeline (
            PipelineID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            LeadID BIGINT NOT NULL,
            PipelineStage NVARCHAR(30) NOT NULL,
            StageEnteredAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            StageExitedAt DATETIME2(7) NULL,
            StageDuration AS DATEDIFF(SECOND, StageEnteredAt, ISNULL(StageExitedAt, GETDATE())) PERSISTED,
            Notes NVARCHAR(500) NULL,
            EnteredBy UNIQUEIDENTIFIER NOT NULL,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            RowVersion ROWVERSION,
            CONSTRAINT PK_SalesPipeline PRIMARY KEY CLUSTERED (PipelineID),
            CONSTRAINT FK_SalesPipeline_Lead FOREIGN KEY (LeadID) REFERENCES dbo.Leads(LeadID) ON DELETE CASCADE,
            CONSTRAINT CK_SalesPipeline_Stage CHECK (PipelineStage IN ('NEW', 'CONTACTED', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'CLOSED_WON', 'CLOSED_LOST'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [3] SalesPipeline table created (Sales funnel tracking).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_SalesPipeline_Lead_Stage 
        ON dbo.SalesPipeline(LeadID, PipelineStage, StageEnteredAt) WHERE IsDeleted = 0;
    GO

-- ========================================================================
-- 4. جدول دعم العملاء (SupportTickets) – ميزة تنافسية
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'SupportTickets')
    BEGIN
        CREATE TABLE dbo.SupportTickets (
            TicketID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            CustomerID BIGINT NOT NULL,
            TicketNumber NVARCHAR(50) NOT NULL,
            TicketType NVARCHAR(30) NOT NULL,
            TicketSubject NVARCHAR(200) NOT NULL,
            TicketDescription NVARCHAR(MAX) NULL,
            
            -- حالة التذكرة
            TicketStatus NVARCHAR(20) NOT NULL DEFAULT 'OPEN',
            TicketPriority NVARCHAR(10) NOT NULL DEFAULT 'MEDIUM',
            
            -- SLA
            SLAHours INT NOT NULL DEFAULT 24,
            SLAExpiryDate DATETIME2(7) NULL,
            SLAViolated BIT NOT NULL DEFAULT 0,
            
            -- التواريخ
            OpenedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            ClosedAt DATETIME2(7) NULL,
            ResolvedAt DATETIME2(7) NULL,
            FirstResponseAt DATETIME2(7) NULL,
            
            -- المراجع
            AssignedToUserID UNIQUEIDENTIFIER NULL,
            OpenedByUserID UNIQUEIDENTIFIER NOT NULL,
            ClosedByUserID UNIQUEIDENTIFIER NULL,
            
            -- التصنيف
            Category NVARCHAR(50) NULL,
            SubCategory NVARCHAR(50) NULL,
            
            -- التقييم
            CustomerSatisfactionScore TINYINT NULL, -- 1-5
            ResolutionNotes NVARCHAR(MAX) NULL,
            
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_SupportTickets PRIMARY KEY CLUSTERED (TicketID),
            CONSTRAINT UQ_SupportTickets_Number UNIQUE (CompanyID, TicketNumber),
            CONSTRAINT FK_SupportTickets_Customer FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID),
            CONSTRAINT CK_SupportTickets_Status CHECK (TicketStatus IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'ESCALATED')),
            CONSTRAINT CK_SupportTickets_Priority CHECK (TicketPriority IN ('LOW', 'MEDIUM', 'HIGH', 'URGENT')),
            CONSTRAINT CK_SupportTickets_CSAT CHECK (CustomerSatisfactionScore BETWEEN 1 AND 5 OR CustomerSatisfactionScore IS NULL)
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [4] SupportTickets table created (Customer support).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_SupportTickets_Customer_Status 
        ON dbo.SupportTickets(CustomerID, TicketStatus) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_SupportTickets_SLA 
        ON dbo.SupportTickets(SLAExpiryDate, TicketStatus) WHERE TicketStatus IN ('OPEN', 'IN_PROGRESS') AND IsDeleted = 0;

    CREATE NONCLUSTERED COLUMNSTORE INDEX IF NOT EXISTS CSIX_SupportTickets_Analytics 
        ON dbo.SupportTickets (CompanyID, TicketType, TicketStatus, TicketPriority, OpenedAt);
    GO

-- ========================================================================
-- 5. جدول تفاعلات العملاء (CustomerInteractions) – سجل زمني كامل
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'CustomerInteractions')
    BEGIN
        CREATE TABLE dbo.CustomerInteractions (
            InteractionID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            CustomerID BIGINT NOT NULL,
            InteractionType NVARCHAR(30) NOT NULL,
            InteractionDate DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            
            -- المحتوى
            Subject NVARCHAR(200) NOT NULL,
            Details NVARCHAR(MAX) NULL,
            Attachments NVARCHAR(500) NULL,
            
            -- المرجع
            ReferenceTable NVARCHAR(50) NULL,
            ReferenceID BIGINT NULL,
            
            -- معلومات إضافية
            Channel NVARCHAR(20) NULL,                 -- Phone, Email, WhatsApp, Meeting, Chat
            Direction NVARCHAR(10) NOT NULL DEFAULT 'INCOMING', -- INCOMING, OUTGOING
            DurationMinutes INT NULL,
            
            -- المندوب المسؤول
            PerformedByUserID UNIQUEIDENTIFIER NOT NULL,
            AssignedToUserID UNIQUEIDENTIFIER NULL,
            
            -- التقييم
            InteractionRating TINYINT NULL,
            
            -- الحذف المنطقي
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_CustomerInteractions PRIMARY KEY CLUSTERED (InteractionID),
            CONSTRAINT FK_CustomerInteractions_Customer FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID) ON DELETE CASCADE,
            CONSTRAINT CK_CustomerInteractions_Type CHECK (InteractionType IN ('CALL', 'EMAIL', 'MEETING', 'NOTE', 'TASK', 'VISIT', 'CHAT')),
            CONSTRAINT CK_CustomerInteractions_Channel CHECK (Channel IN ('Phone', 'Email', 'WhatsApp', 'Meeting', 'Chat', 'SMS', NULL)),
            CONSTRAINT CK_CustomerInteractions_Direction CHECK (Direction IN ('INCOMING', 'OUTGOING'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [5] CustomerInteractions table created (Full history).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_CustomerInteractions_Customer_Date 
        ON dbo.CustomerInteractions(CustomerID, InteractionDate DESC) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED COLUMNSTORE INDEX IF NOT EXISTS CSIX_CustomerInteractions_Analytics 
        ON dbo.CustomerInteractions (CompanyID, InteractionType, Channel, Direction, InteractionDate);
    GO

-- ========================================================================
-- 6. جدول الحملات التسويقية (MarketingCampaigns) – ميزة تنافسية
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'MarketingCampaigns')
    BEGIN
        CREATE TABLE dbo.MarketingCampaigns (
            CampaignID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            CampaignCode NVARCHAR(50) NOT NULL,
            CampaignNameAR NVARCHAR(200) NOT NULL,
            CampaignNameEN NVARCHAR(200) NULL,
            CampaignType NVARCHAR(30) NOT NULL,
            CampaignDescription NVARCHAR(MAX) NULL,
            
            -- التواريخ
            StartDate DATE NOT NULL,
            EndDate DATE NULL,
            ActualEndDate DATE NULL,
            
            -- الميزانية
            Budget DECIMAL(18,2) NOT NULL DEFAULT 0,
            ActualCost DECIMAL(18,2) NOT NULL DEFAULT 0,
            
            -- المقاييس
            TargetAudience INT NULL,
            ContactsReached INT NULL,
            Responses INT NULL,
            LeadsGenerated INT NULL,
            Conversions INT NULL,
            ConversionRate AS (CASE WHEN ContactsReached > 0 THEN (Conversions * 100.0 / ContactsReached) ELSE 0 END) PERSISTED,
            
            -- ROI
            RevenueGenerated DECIMAL(18,2) NULL,
            ROICalculated AS (CASE WHEN ActualCost > 0 AND RevenueGenerated IS NOT NULL 
                THEN ((RevenueGenerated - ActualCost) / ActualCost) * 100 
                ELSE NULL END) PERSISTED,
            
            -- الحالة
            CampaignStatus NVARCHAR(20) NOT NULL DEFAULT 'DRAFT',
            IsActive BIT NOT NULL DEFAULT 1,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_MarketingCampaigns PRIMARY KEY CLUSTERED (CampaignID),
            CONSTRAINT UQ_MarketingCampaigns_Code UNIQUE (CompanyID, CampaignCode),
            CONSTRAINT FK_MarketingCampaigns_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID),
            CONSTRAINT CK_MarketingCampaigns_Type CHECK (CampaignType IN ('EMAIL', 'SMS', 'SOCIAL_MEDIA', 'DIRECT_MAIL', 'EVENT', 'PAID_AD', 'CONTENT')),
            CONSTRAINT CK_MarketingCampaigns_Status CHECK (CampaignStatus IN ('DRAFT', 'ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [6] MarketingCampaigns table created (Marketing automation).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_MarketingCampaigns_Company_Status 
        ON dbo.MarketingCampaigns(CompanyID, CampaignStatus) WHERE IsDeleted = 0;

    CREATE NONCLUSTERED COLUMNSTORE INDEX IF NOT EXISTS CSIX_MarketingCampaigns_Analytics 
        ON dbo.MarketingCampaigns (CompanyID, CampaignType, CampaignStatus, StartDate, Budget, ActualCost);
    GO

-- ========================================================================
-- 7. الإجراءات المخزنة الجديدة
-- ========================================================================

-- 7.1 🔥 تحويل العميل المتوقع إلى عميل فعلي
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_ConvertLeadToCustomer')
    DROP PROCEDURE dbo.usp_ConvertLeadToCustomer;
GO
CREATE PROCEDURE dbo.usp_ConvertLeadToCustomer
    @LeadID BIGINT,
    @NewCustomerCode NVARCHAR(50) = NULL,
    @CustomerType NVARCHAR(30) = 'INDIVIDUAL',
    @ConvertedBy UNIQUEIDENTIFIER,
    @NewCustomerID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 1. جلب بيانات العميل المتوقع
        DECLARE @CompanyID UNIQUEIDENTIFIER;
        DECLARE @LeadName NVARCHAR(255);
        DECLARE @LeadNameEN NVARCHAR(255);
        DECLARE @Phone NVARCHAR(50);
        DECLARE @Mobile NVARCHAR(50);
        DECLARE @Email NVARCHAR(255);
        DECLARE @TaxNumber NVARCHAR(100);
        DECLARE @City NVARCHAR(100);
        DECLARE @State NVARCHAR(100);
        DECLARE @Country NVARCHAR(100);
        DECLARE @LeadCode NVARCHAR(50);
        DECLARE @ContactPerson NVARCHAR(200);
        DECLARE @Website NVARCHAR(255);
        DECLARE @LeadSource NVARCHAR(50);
        
        SELECT 
            @CompanyID = CompanyID,
            @LeadName = LeadName,
            @LeadNameEN = LeadNameEN,
            @Phone = Phone,
            @Mobile = Mobile,
            @Email = Email,
            @TaxNumber = TaxNumber,
            @City = City,
            @State = State,
            @Country = Country,
            @LeadCode = LeadCode,
            @ContactPerson = ContactPerson,
            @Website = Website,
            @LeadSource = LeadSource
        FROM dbo.Leads WHERE LeadID = @LeadID AND IsDeleted = 0;
        
        IF @LeadName IS NULL THROW 50000, 'العميل المتوقع غير موجود.', 1;
        
        -- 2. إنشاء كود العميل
        IF @NewCustomerCode IS NULL
            SET @NewCustomerCode = 'CUST_' + CAST(NEWID() AS NVARCHAR(8));
        
        -- 3. إدراج العميل الجديد
        INSERT INTO dbo.Customers (
            CompanyID, CustomerCode, CustomerNameAR, CustomerNameEN,
            Phone, Mobile, Email, TaxNumber, City, State, Country,
            ContactPerson, Website, LeadSource, CustomerType,
            IsActive, CreatedBy
        ) VALUES (
            @CompanyID, @NewCustomerCode, @LeadName, @LeadNameEN,
            @Phone, @Mobile, @Email, @TaxNumber, @City, @State, @Country,
            @ContactPerson, @Website, @LeadSource, @CustomerType,
            1, @ConvertedBy
        );
        SET @NewCustomerID = SCOPE_IDENTITY();
        
        -- 4. تحديث حالة العميل المتوقع
        UPDATE dbo.Leads 
        SET LeadStage = 'CLOSED_WON',
            ActualCloseDate = CAST(GETDATE() AS DATE),
            UpdatedBy = @ConvertedBy,
            UpdatedAt = SYSUTCDATETIME()
        WHERE LeadID = @LeadID;
        
        -- 5. تسجيل في سجل التفاعلات
        INSERT INTO dbo.CustomerInteractions (
            CompanyID, CustomerID, InteractionType, Subject, Details,
            PerformedByUserID, CreatedBy
        ) VALUES (
            @CompanyID, @NewCustomerID, 'NOTE', 
            N'تحويل من عميل متوقع',
            N'تم تحويل العميل المتوقع ' + @LeadCode + N' إلى عميل فعلي برقم ' + @NewCustomerCode,
            @ConvertedBy, @ConvertedBy
        );
        
        -- 6. تسجيل في AuditLog
        DECLARE @AuditID BIGINT;
        EXEC dbo.usp_Audit_Log
            @CompanyID = @CompanyID,
            @TableName = 'Customers',
            @RecordID = CAST(@NewCustomerID AS NVARCHAR(100)),
            @ActionType = 'INSERT',
            @UserID = @ConvertedBy,
            @ActionDescription = N'تحويل عميل متوقع (Lead ID: ' + CAST(@LeadID AS NVARCHAR) + N') إلى عميل',
            @NewData = N'CustomerCode: ' + @NewCustomerCode,
            @NewAuditID = @AuditID OUTPUT;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
PRINT N'✅ [7.1] usp_ConvertLeadToCustomer created (Lead conversion).';


-- 7.2 🔥 إغلاق تذكرة دعم
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_CloseSupportTicket')
    DROP PROCEDURE dbo.usp_CloseSupportTicket;
GO
CREATE PROCEDURE dbo.usp_CloseSupportTicket
    @TicketID BIGINT,
    @ClosedByUserID UNIQUEIDENTIFIER,
    @ResolutionNotes NVARCHAR(MAX) = NULL,
    @CustomerSatisfactionScore TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        UPDATE dbo.SupportTickets
        SET TicketStatus = 'CLOSED',
            ClosedAt = SYSUTCDATETIME(),
            ResolvedAt = SYSUTCDATETIME(),
            ClosedByUserID = @ClosedByUserID,
            ResolutionNotes = @ResolutionNotes,
            CustomerSatisfactionScore = @CustomerSatisfactionScore,
            UpdatedBy = @ClosedByUserID,
            UpdatedAt = SYSUTCDATETIME()
        WHERE TicketID = @TicketID AND TicketStatus IN ('OPEN', 'IN_PROGRESS');
        
        -- تسجيل في AuditLog
        DECLARE @CompanyID UNIQUEIDENTIFIER;
        DECLARE @CustomerID BIGINT;
        SELECT @CompanyID = CompanyID, @CustomerID = CustomerID
        FROM dbo.SupportTickets WHERE TicketID = @TicketID;
        
        DECLARE @AuditID BIGINT;
        EXEC dbo.usp_Audit_Log
            @CompanyID = @CompanyID,
            @TableName = 'SupportTickets',
            @RecordID = CAST(@TicketID AS NVARCHAR(100)),
            @ActionType = 'UPDATE',
            @UserID = @ClosedByUserID,
            @ActionDescription = N'إغلاق تذكرة دعم رقم ' + CAST(@TicketID AS NVARCHAR),
            @NewData = N'Status: CLOSED, Score: ' + CAST(@CustomerSatisfactionScore AS NVARCHAR),
            @NewAuditID = @AuditID OUTPUT;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
PRINT N'✅ [7.2] usp_CloseSupportTicket created (Ticket closure).';


-- 7.3 🔥 تقرير تحليلات المبيعات (Sales Analytics)
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_CRM_SalesAnalytics')
    DROP PROCEDURE dbo.usp_CRM_SalesAnalytics;
GO
CREATE PROCEDURE dbo.usp_CRM_SalesAnalytics
    @CompanyID UNIQUEIDENTIFIER,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(MONTH, -12, GETDATE());
    IF @ToDate IS NULL SET @ToDate = GETDATE();
    
    -- 1. ملخص العملاء الجدد
    SELECT 
        'new_customers' AS Metric,
        COUNT(*) AS Value,
        SUM(CurrentBalance) AS TotalBalance
    FROM dbo.Customers
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND CAST(CreatedAt AS DATE) BETWEEN @FromDate AND @ToDate;
    
    -- 2. توزيع العملاء حسب النوع
    SELECT 
        'customer_type' AS Metric,
        CustomerType,
        COUNT(*) AS Count
    FROM dbo.Customers
    WHERE CompanyID = @CompanyID AND IsDeleted = 0
    GROUP BY CustomerType;
    
    -- 3. ملخص العملاء المتوقعين
    SELECT 
        'leads_summary' AS Metric,
        LeadStage,
        COUNT(*) AS Count,
        SUM(ExpectedValue) AS TotalValue
    FROM dbo.Leads
    WHERE CompanyID = @CompanyID AND IsDeleted = 0
    GROUP BY LeadStage;
    
    -- 4. نشاط التفاعلات
    SELECT 
        'interactions' AS Metric,
        InteractionType,
        COUNT(*) AS Count,
        AVG(DurationMinutes) AS AvgDuration
    FROM dbo.CustomerInteractions
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND CAST(InteractionDate AS DATE) BETWEEN @FromDate AND @ToDate
    GROUP BY InteractionType;
    
    -- 5. تذاكر الدعم
    SELECT 
        'support_tickets' AS Metric,
        TicketStatus,
        COUNT(*) AS Count,
        AVG(DATEDIFF(HOUR, OpenedAt, ISNULL(ClosedAt, GETDATE()))) AS AvgHoursOpen
    FROM dbo.SupportTickets
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND CAST(OpenedAt AS DATE) BETWEEN @FromDate AND @ToDate
    GROUP BY TicketStatus;
END;
GO
PRINT N'✅ [7.3] usp_CRM_SalesAnalytics created (Sales analytics).';


-- 7.4 🔥 تقرير العملاء المعرضين للخطر (Churn Risk Report)
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_CRM_ChurnRiskReport')
    DROP PROCEDURE dbo.usp_CRM_ChurnRiskReport;
GO
CREATE PROCEDURE dbo.usp_CRM_ChurnRiskReport
    @CompanyID UNIQUEIDENTIFIER,
    @MinRiskThreshold DECIMAL(5,4) = 0.5,
    @DaysSinceLastVisit INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        CustomerID,
        CustomerCode,
        CustomerNameAR,
        Phone,
        Mobile,
        Email,
        CurrentBalance,
        CreditLimit,
        ChurnRisk,
        CustomerScore,
        LastVisitDate,
        DATEDIFF(DAY, LastVisitDate, GETDATE()) AS DaysSinceLastVisit,
        LoyaltyPoints,
        CASE 
            WHEN ChurnRisk > 0.7 THEN N'⚠️ خطر مرتفع'
            WHEN ChurnRisk > 0.5 THEN N'⚠️ خطر متوسط'
            WHEN ChurnRisk > 0.3 THEN N'📊 خطر منخفض'
            ELSE N'✅ آمن'
        END AS RiskLevel,
        CASE 
            WHEN DATEDIFF(DAY, LastVisitDate, GETDATE()) > @DaysSinceLastVisit THEN N'⚠️ غير نشط'
            ELSE N'✅ نشط'
        END AS ActivityStatus
    FROM dbo.Customers
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND IsActive = 1
        AND (ChurnRisk >= @MinRiskThreshold OR DATEDIFF(DAY, LastVisitDate, GETDATE()) > @DaysSinceLastVisit)
    ORDER BY ChurnRisk DESC, DaysSinceLastVisit DESC;
END;
GO
PRINT N'✅ [7.4] usp_CRM_ChurnRiskReport created (Churn analysis).';

-- ========================================================================
-- 8. طرق عرض جديدة للتقارير
-- ========================================================================

-- 8.1 عرض تحليلات العملاء (Customer Analytics)
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_CustomerAnalytics')
    DROP VIEW dbo.vw_CustomerAnalytics;
GO
CREATE VIEW dbo.vw_CustomerAnalytics
AS
SELECT 
    c.CustomerID,
    c.CustomerCode,
    c.CustomerNameAR,
    c.CustomerType,
    c.CustomerScore,
    c.ChurnRisk,
    c.LoyaltyPoints,
    c.CurrentBalance,
    c.CreditLimit,
    c.LastVisitDate,
    DATEDIFF(DAY, c.LastVisitDate, GETDATE()) AS DaysSinceLastVisit,
    c.TotalTransactions,
    c.TotalVisits,
    c.CustomerLifetimeValue,
    (SELECT COUNT(*) FROM dbo.CustomerInteractions ci 
     WHERE ci.CustomerID = c.CustomerID AND ci.IsDeleted = 0) AS TotalInteractions,
    (SELECT COUNT(*) FROM dbo.SupportTickets st 
     WHERE st.CustomerID = c.CustomerID AND st.IsDeleted = 0) AS TotalTickets,
    (SELECT AVG(CustomerSatisfactionScore) FROM dbo.SupportTickets st 
     WHERE st.CustomerID = c.CustomerID AND st.IsDeleted = 0 AND st.CustomerSatisfactionScore IS NOT NULL) AS AvgCSAT
FROM dbo.Customers c
WHERE c.IsDeleted = 0;
GO
PRINT N'✅ [8.1] vw_CustomerAnalytics created (Advanced analytics).';


-- 8.2 عرض أداء المبيعات (Sales Performance)
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_SalesPerformance')
    DROP VIEW dbo.vw_SalesPerformance;
GO
CREATE VIEW dbo.vw_SalesPerformance
AS
SELECT 
    l.LeadID,
    l.LeadCode,
    l.LeadName,
    l.LeadStage,
    l.ConversionProbability,
    l.ExpectedValue,
    l.ExpectedCloseDate,
    l.AssignedToSalesPersonID,
    l.CreatedAt,
    DATEDIFF(DAY, l.CreatedAt, GETDATE()) AS DaysInPipeline,
    sp.StageEnteredAt,
    sp.StageDuration,
    CASE 
        WHEN l.LeadStage = 'CLOSED_WON' THEN N'✅ تم التحويل'
        WHEN l.LeadStage = 'CLOSED_LOST' THEN N'❌ تم الفقد'
        WHEN l.ConversionProbability > 0.7 THEN N'🟢 احتمال مرتفع'
        WHEN l.ConversionProbability > 0.4 THEN N'🟡 احتمال متوسط'
        ELSE N'🔴 احتمال منخفض'
    END AS ConversionStatus
FROM dbo.Leads l
LEFT JOIN dbo.SalesPipeline sp ON l.LeadID = sp.LeadID AND sp.StageExitedAt IS NULL
WHERE l.IsDeleted = 0;
GO
PRINT N'✅ [8.2] vw_SalesPerformance created (Sales pipeline view).';


-- 8.3 عرض أداء الحملات التسويقية
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_CampaignPerformance')
    DROP VIEW dbo.vw_CampaignPerformance;
GO
CREATE VIEW dbo.vw_CampaignPerformance
AS
SELECT 
    mc.CampaignID,
    mc.CampaignCode,
    mc.CampaignNameAR,
    mc.CampaignType,
    mc.StartDate,
    mc.EndDate,
    mc.Budget,
    mc.ActualCost,
    mc.TargetAudience,
    mc.ContactsReached,
    mc.LeadsGenerated,
    mc.Conversions,
    mc.ConversionRate,
    mc.RevenueGenerated,
    mc.ROICalculated,
    mc.CampaignStatus,
    CASE 
        WHEN mc.CampaignStatus = 'COMPLETED' AND mc.ConversionRate > 10 THEN N'⭐ ممتاز'
        WHEN mc.CampaignStatus = 'COMPLETED' AND mc.ConversionRate > 5 THEN N'✅ جيد'
        WHEN mc.CampaignStatus = 'COMPLETED' AND mc.ConversionRate > 2 THEN N'⚠️ متوسط'
        WHEN mc.CampaignStatus = 'COMPLETED' THEN N'❌ ضعيف'
        ELSE N'⏳ قيد التنفيذ'
    END AS PerformanceRating
FROM dbo.MarketingCampaigns mc
WHERE mc.IsDeleted = 0;
GO
PRINT N'✅ [8.3] vw_CampaignPerformance created (Campaign analytics).';

-- ========================================================================
-- 9. البيانات الأولية (Seed Data)
-- ========================================================================
-- تمت إزالة البيانات التشغيلية التجريبية (LEAD_SAMPLE / TKT-0001).
-- لا يتم إدراج عملاء متوقعين أو تذاكر دعم وهمية.
-- ========================================================================

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
END CATCH
GO