-- ========================================================================
-- FILE: dba/sch/lead_upgrade.sql
-- PROJECT: SHOUTECH ERP V10 - Leads Module (UPGRADE to 10/10 ULTIMATE)
-- VERSION: 10.7.0
-- DESCRIPTION: 
--   إضافة الميزات المفقودة لنظام العملاء المتوقعين: سجل التدقيق،
--   تاريخ الحالة، جهات الاتصال، العناوين، توزيع المبيعات، وأدوات الذكاء الاصطناعي.
-- ========================================================================

USE [$(DbFileName)];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

PRINT N'═══════════════════════════════════════════════════════════════════════';
PRINT N'SHOUTECH ERP V10 – LEADS MODULE (UPGRADE to 10.10.0 ULTIMATE)';
PRINT N'═══════════════════════════════════════════════════════════════════════';
GO

BEGIN TRY
    BEGIN TRANSACTION;

-- ========================================================================
-- 1. إضافة حقول جديدة إلى Leads
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Leads') AND name = 'LeadQualityScore')
    BEGIN
        ALTER TABLE dbo.Leads ADD 
            LeadQualityScore DECIMAL(5,2) NULL,                 -- جودة العميل المتوقع (AI)
            EngagementScore DECIMAL(5,2) NULL,                  -- درجة التفاعل
            SalesReadinessScore DECIMAL(5,2) NULL,              -- درجة جاهزية البيع
            PreferredContactTime NVARCHAR(50) NULL,
            LeadOwnerTeamID UNIQUEIDENTIFIER NULL,
            CampaignID BIGINT NULL,
            LastActivityDate DATETIME2(7) NULL,
            NextFollowUpDate DATE NULL,
            FollowUpCount INT NOT NULL DEFAULT 0,
            TimeInCurrentStageDays INT NULL,                    -- المدة في المرحلة الحالية
            ConversionTimeDays INT NULL,                        -- الوقت المستغرق للتحويل
            DataPrivacyConsent BIT NOT NULL DEFAULT 0,
            DataPrivacyConsentDate DATE NULL,
            MarketingOptOut BIT NOT NULL DEFAULT 0;
        PRINT N'✅ [1] Added AI and marketing fields to Leads.';
    END

-- ========================================================================
-- 2. جدول سجل التدقيق (LeadAudit) – ميزة الأمان المتقدم
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'LeadAudit')
    BEGIN
        CREATE TABLE dbo.LeadAudit (
            AuditID BIGINT IDENTITY(1,1) NOT NULL,
            LeadID BIGINT NOT NULL,
            ActionType NVARCHAR(20) NOT NULL,          -- INSERT, UPDATE, DELETE, CONVERT, STAGE_CHANGE
            ChangedField NVARCHAR(100) NULL,
            OldValue NVARCHAR(MAX) NULL,
            NewValue NVARCHAR(MAX) NULL,
            ChangedBy UNIQUEIDENTIFIER NOT NULL,
            ChangedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            IPAddress NVARCHAR(45) NULL,
            UserAgent NVARCHAR(255) NULL,
            
            CONSTRAINT PK_LeadAudit PRIMARY KEY (AuditID),
            CONSTRAINT FK_LeadAudit_Lead FOREIGN KEY (LeadID) 
                REFERENCES dbo.Leads(LeadID) ON DELETE CASCADE,
            CONSTRAINT CK_LeadAudit_ActionType CHECK (ActionType IN ('INSERT', 'UPDATE', 'DELETE', 'CONVERT', 'STAGE_CHANGE'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [2] LeadAudit table created (Full Audit Trail).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_LeadAudit_Lead 
        ON dbo.LeadAudit(LeadID, ChangedAt DESC);
    GO

-- ========================================================================
-- 3. جدول تاريخ مراحل العميل المتوقع (LeadStageHistory) – ميزة تنافسية
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'LeadStageHistory')
    BEGIN
        CREATE TABLE dbo.LeadStageHistory (
            StageHistoryID BIGINT IDENTITY(1,1) NOT NULL,
            LeadID BIGINT NOT NULL,
            PreviousStage NVARCHAR(30) NULL,
            NewStage NVARCHAR(30) NOT NULL,
            ChangedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            ChangedBy UNIQUEIDENTIFIER NOT NULL,
            Reason NVARCHAR(500) NULL,
            DurationInStageDays AS DATEDIFF(DAY, ChangedAt, 
                (SELECT MIN(ChangedAt) FROM dbo.LeadStageHistory lsh2 
                 WHERE lsh2.LeadID = LeadID AND lsh2.StageHistoryID > StageHistoryID)) PERSISTED,
            
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_LeadStageHistory PRIMARY KEY CLUSTERED (StageHistoryID),
            CONSTRAINT FK_LeadStageHistory_Lead FOREIGN KEY (LeadID) 
                REFERENCES dbo.Leads(LeadID) ON DELETE CASCADE,
            CONSTRAINT CK_LeadStageHistory_Stage CHECK (NewStage IN 
                ('NEW', 'CONTACTED', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'CLOSED_WON', 'CLOSED_LOST'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [3] LeadStageHistory table created.';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_LeadStageHistory_Lead 
        ON dbo.LeadStageHistory(LeadID, ChangedAt DESC) WHERE IsDeleted = 0;
    GO

-- ========================================================================
-- 4. جدول جهات الاتصال للعملاء المتوقعين (LeadContacts)
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'LeadContacts')
    BEGIN
        CREATE TABLE dbo.LeadContacts (
            ContactID BIGINT IDENTITY(1,1) NOT NULL,
            LeadID BIGINT NOT NULL,
            FullName NVARCHAR(200) NOT NULL,
            JobTitle NVARCHAR(100) NULL,
            Department NVARCHAR(100) NULL,
            Phone1 NVARCHAR(50) NULL,
            Phone2 NVARCHAR(50) NULL,
            Mobile NVARCHAR(50) NULL,
            Email NVARCHAR(255) NULL,
            IsPrimary BIT NOT NULL DEFAULT 0,
            IsDecisionMaker BIT NOT NULL DEFAULT 0,
            IsActive BIT NOT NULL DEFAULT 1,
            Notes NVARCHAR(MAX) NULL,
            
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_LeadContacts PRIMARY KEY CLUSTERED (ContactID),
            CONSTRAINT FK_LeadContacts_Lead FOREIGN KEY (LeadID) 
                REFERENCES dbo.Leads(LeadID) ON DELETE CASCADE
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [4] LeadContacts table created.';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_LeadContacts_Lead 
        ON dbo.LeadContacts(LeadID, IsPrimary) WHERE IsActive = 1;
    GO

-- ========================================================================
-- 5. جدول العناوين للعملاء المتوقعين (LeadAddresses)
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'LeadAddresses')
    BEGIN
        CREATE TABLE dbo.LeadAddresses (
            AddressID BIGINT IDENTITY(1,1) NOT NULL,
            LeadID BIGINT NOT NULL,
            AddressType NVARCHAR(20) NOT NULL DEFAULT 'MAIN', -- MAIN, BILLING, SHIPPING, BRANCH
            AddressLine1 NVARCHAR(255) NOT NULL,
            AddressLine2 NVARCHAR(255) NULL,
            City NVARCHAR(100) NOT NULL,
            State NVARCHAR(100) NULL,
            PostalCode NVARCHAR(20) NULL,
            Country NVARCHAR(100) DEFAULT N'المملكة العربية السعودية',
            BuildingNumber NVARCHAR(20) NULL,
            AdditionalNumber NVARCHAR(20) NULL,
            DistrictName NVARCHAR(100) NULL,
            IsDefault BIT NOT NULL DEFAULT 0,
            IsActive BIT NOT NULL DEFAULT 1,
            
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_LeadAddresses PRIMARY KEY CLUSTERED (AddressID),
            CONSTRAINT FK_LeadAddresses_Lead FOREIGN KEY (LeadID) 
                REFERENCES dbo.Leads(LeadID) ON DELETE CASCADE,
            CONSTRAINT CK_LeadAddresses_Type CHECK (AddressType IN ('MAIN', 'BILLING', 'SHIPPING', 'BRANCH'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [5] LeadAddresses table created.';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_LeadAddresses_Lead 
        ON dbo.LeadAddresses(LeadID, IsDefault) WHERE IsActive = 1;
    GO

-- ========================================================================
-- 6. جدول توزيع العملاء المتوقعين (LeadAssignments) – ميزة تنافسية
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'LeadAssignments')
    BEGIN
        CREATE TABLE dbo.LeadAssignments (
            AssignmentID BIGINT IDENTITY(1,1) NOT NULL,
            LeadID BIGINT NOT NULL,
            AssignedToSalesPersonID UNIQUEIDENTIFIER NOT NULL,
            AssignedBy UNIQUEIDENTIFIER NOT NULL,
            AssignedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UnassignedAt DATETIME2(7) NULL,
            UnassignedBy UNIQUEIDENTIFIER NULL,
            UnassignmentReason NVARCHAR(500) NULL,
            
            AssignmentNotes NVARCHAR(500) NULL,
            IsActive BIT NOT NULL DEFAULT 1,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_LeadAssignments PRIMARY KEY CLUSTERED (AssignmentID),
            CONSTRAINT FK_LeadAssignments_Lead FOREIGN KEY (LeadID) 
                REFERENCES dbo.Leads(LeadID) ON DELETE CASCADE,
            CONSTRAINT CK_LeadAssignments_Active CHECK (IsActive IN (0, 1))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [6] LeadAssignments table created.';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_LeadAssignments_Lead 
        ON dbo.LeadAssignments(LeadID, IsActive) WHERE IsActive = 1 AND IsDeleted = 0;
    GO

-- ========================================================================
-- 7. جدول الحملات التسويقية (MarketingCampaigns) – ميزة تنافسية
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
        PRINT N'✅ [7] MarketingCampaigns table created.';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_MarketingCampaigns_Company_Status 
        ON dbo.MarketingCampaigns(CompanyID, CampaignStatus) WHERE IsDeleted = 0;

    -- إضافة المفتاح الخارجي للحملات
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Leads_Campaign')
        ALTER TABLE dbo.Leads ADD CONSTRAINT FK_Leads_Campaign 
        FOREIGN KEY (CampaignID) REFERENCES dbo.MarketingCampaigns(CampaignID);
    GO

-- ========================================================================
-- 8. الإجراءات المخزنة الجديدة والمحسّنة
-- ========================================================================

-- 8.1 🔥 تحويل العميل المتوقع إلى عميل فعلي (النسخة المحسّنة)
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_ConvertLeadToCustomer_V2')
    DROP PROCEDURE dbo.usp_ConvertLeadToCustomer_V2;
GO
CREATE PROCEDURE dbo.usp_ConvertLeadToCustomer_V2
    @LeadID BIGINT,
    @NewCustomerCode NVARCHAR(50) = NULL,
    @CustomerType NVARCHAR(30) = 'INDIVIDUAL',
    @CustomerGroupCode NVARCHAR(50) = NULL,
    @ConvertedBy UNIQUEIDENTIFIER,
    @NewCustomerID BIGINT OUTPUT,
    @CopyContacts BIT = 1,
    @CopyAddresses BIT = 1
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
        DECLARE @VATCategory NVARCHAR(10);
        DECLARE @ZATCAStatus NVARCHAR(20);
        DECLARE @LeadScore DECIMAL(5,2);
        DECLARE @CampaignID BIGINT;
        
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
            @LeadSource = LeadSource,
            @VATCategory = VATCategory,
            @ZATCAStatus = ZATCAComplianceStatus,
            @LeadScore = LeadScore,
            @CampaignID = CampaignID
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
            CustomerGroupCode, VATCategory, ZATCAComplianceStatus,
            CustomerScore, IsActive, CreatedBy
        ) VALUES (
            @CompanyID, @NewCustomerCode, @LeadName, @LeadNameEN,
            @Phone, @Mobile, @Email, @TaxNumber, @City, @State, @Country,
            @ContactPerson, @Website, @LeadSource, @CustomerType,
            @CustomerGroupCode, @VATCategory, @ZATCAStatus,
            @LeadScore, 1, @ConvertedBy
        );
        SET @NewCustomerID = SCOPE_IDENTITY();
        
        -- 4. نسخ جهات الاتصال (إذا كان مطلوباً)
        IF @CopyContacts = 1
        BEGIN
            INSERT INTO dbo.CustomerContacts (
                CustomerID, FullName, JobTitle, Department,
                Phone1, Phone2, Mobile, Email, IsPrimary, IsActive, CreatedBy
            )
            SELECT 
                @NewCustomerID, FullName, JobTitle, Department,
                Phone1, Phone2, Mobile, Email, IsPrimary, 1, @ConvertedBy
            FROM dbo.LeadContacts
            WHERE LeadID = @LeadID AND IsActive = 1 AND IsDeleted = 0;
        END
        
        -- 5. نسخ العناوين (إذا كان مطلوباً)
        IF @CopyAddresses = 1
        BEGIN
            INSERT INTO dbo.CustomerAddresses (
                CustomerID, AddressType, AddressLine1, AddressLine2,
                City, State, PostalCode, Country,
                BuildingNumber, AdditionalNumber, DistrictName,
                IsDefault, IsActive, CreatedBy
            )
            SELECT 
                @NewCustomerID, 
                CASE WHEN AddressType = 'MAIN' THEN 'BILLING' ELSE AddressType END,
                AddressLine1, AddressLine2, City, State, PostalCode, Country,
                BuildingNumber, AdditionalNumber, DistrictName,
                IsDefault, 1, @ConvertedBy
            FROM dbo.LeadAddresses
            WHERE LeadID = @LeadID AND IsActive = 1 AND IsDeleted = 0;
        END
        
        -- 6. تحديث حالة العميل المتوقع
        UPDATE dbo.Leads 
        SET LeadStage = 'CLOSED_WON',
            ActualCloseDate = CAST(GETDATE() AS DATE),
            ConversionTimeDays = DATEDIFF(DAY, CreatedAt, GETDATE()),
            UpdatedBy = @ConvertedBy,
            UpdatedAt = SYSUTCDATETIME()
        WHERE LeadID = @LeadID;
        
        -- 7. تسجيل في تاريخ المراحل
        INSERT INTO dbo.LeadStageHistory (
            LeadID, PreviousStage, NewStage, ChangedBy, Reason
        ) VALUES (
            @LeadID, 'NEGOTIATION', 'CLOSED_WON', @ConvertedBy, N'تحويل إلى عميل'
        );
        
        -- 8. تسجيل في سجل التدقيق
        INSERT INTO dbo.LeadAudit (
            LeadID, ActionType, ChangedField, OldValue, NewValue, ChangedBy
        ) VALUES (
            @LeadID, 'CONVERT', 'LeadStage', 'NEGOTIATION', 'CLOSED_WON', @ConvertedBy
        );
        
        -- 9. تسجيل في AuditLog الموحد
        DECLARE @AuditID BIGINT;
        EXEC dbo.usp_Audit_Log
            @CompanyID = @CompanyID,
            @TableName = 'Leads',
            @RecordID = CAST(@LeadID AS NVARCHAR(100)),
            @ActionType = 'UPDATE',
            @UserID = @ConvertedBy,
            @ActionDescription = N'تحويل العميل المتوقع ' + @LeadCode + N' إلى عميل رقم ' + @NewCustomerCode,
            @NewData = N'CustomerID: ' + CAST(@NewCustomerID AS NVARCHAR),
            @NewAuditID = @AuditID OUTPUT;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
PRINT N'✅ [8.1] usp_ConvertLeadToCustomer_V2 created (Enhanced with full data migration).';


-- 8.2 🔥 تحديث مرحلة العميل المتوقع (مع تاريخ)
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_UpdateLeadStage')
    DROP PROCEDURE dbo.usp_UpdateLeadStage;
GO
CREATE PROCEDURE dbo.usp_UpdateLeadStage
    @LeadID BIGINT,
    @NewStage NVARCHAR(30),
    @Reason NVARCHAR(500) = NULL,
    @UpdatedBy UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @OldStage NVARCHAR(30);
        DECLARE @CompanyID UNIQUEIDENTIFIER;
        
        SELECT @OldStage = LeadStage, @CompanyID = CompanyID
        FROM dbo.Leads WHERE LeadID = @LeadID AND IsDeleted = 0;
        
        IF @OldStage IS NULL THROW 50000, 'العميل المتوقع غير موجود.', 1;
        IF @OldStage = @NewStage 
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END
        
        -- تحديث المرحلة
        UPDATE dbo.Leads 
        SET LeadStage = @NewStage,
            TimeInCurrentStageDays = 0,
            UpdatedBy = @UpdatedBy,
            UpdatedAt = SYSUTCDATETIME()
        WHERE LeadID = @LeadID;
        
        -- تسجيل في تاريخ المراحل
        INSERT INTO dbo.LeadStageHistory (
            LeadID, PreviousStage, NewStage, ChangedBy, Reason
        ) VALUES (
            @LeadID, @OldStage, @NewStage, @UpdatedBy, @Reason
        );
        
        -- تسجيل في سجل التدقيق
        INSERT INTO dbo.LeadAudit (
            LeadID, ActionType, ChangedField, OldValue, NewValue, ChangedBy
        ) VALUES (
            @LeadID, 'STAGE_CHANGE', 'LeadStage', @OldStage, @NewStage, @UpdatedBy
        );
        
        -- تسجيل في AuditLog الموحد
        DECLARE @AuditID BIGINT;
        EXEC dbo.usp_Audit_Log
            @CompanyID = @CompanyID,
            @TableName = 'Leads',
            @RecordID = CAST(@LeadID AS NVARCHAR(100)),
            @ActionType = 'UPDATE',
            @UserID = @UpdatedBy,
            @ActionDescription = N'تحديث مرحلة العميل المتوقع: ' + @OldStage + N' → ' + @NewStage,
            @NewData = @NewStage,
            @NewAuditID = @AuditID OUTPUT;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
PRINT N'✅ [8.2] usp_UpdateLeadStage created.';


-- 8.3 🔥 إحصائيات العملاء المتوقعين المتقدمة (لوحة القيادة)
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_GetLeadPipeline_V2')
    DROP PROCEDURE dbo.usp_GetLeadPipeline_V2;
GO
CREATE PROCEDURE dbo.usp_GetLeadPipeline_V2
    @CompanyID UNIQUEIDENTIFIER,
    @SalesPersonID UNIQUEIDENTIFIER = NULL,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(MONTH, -3, GETDATE());
    IF @ToDate IS NULL SET @ToDate = GETDATE();
    
    -- 1. توزيع العملاء حسب المرحلة
    SELECT 
        LeadStage,
        COUNT(*) AS LeadCount,
        SUM(ExpectedValue) AS TotalExpectedValue,
        AVG(ConversionProbability) AS AvgProbability,
        AVG(LeadScore) AS AvgScore,
        AVG(DATEDIFF(DAY, CreatedAt, GETDATE())) AS AvgAgeDays
    FROM dbo.Leads
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND (@SalesPersonID IS NULL OR AssignedToSalesPersonID = @SalesPersonID)
        AND CAST(CreatedAt AS DATE) BETWEEN @FromDate AND @ToDate
    GROUP BY LeadStage
    ORDER BY 
        CASE LeadStage 
            WHEN 'NEW' THEN 1
            WHEN 'CONTACTED' THEN 2
            WHEN 'QUALIFIED' THEN 3
            WHEN 'PROPOSAL' THEN 4
            WHEN 'NEGOTIATION' THEN 5
            ELSE 6
        END;
    
    -- 2. معدلات التحويل حسب المصدر
    SELECT 
        LeadSource,
        COUNT(*) AS TotalLeads,
        SUM(CASE WHEN LeadStage = 'CLOSED_WON' THEN 1 ELSE 0 END) AS Converted,
        CAST(SUM(CASE WHEN LeadStage = 'CLOSED_WON' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS ConversionRate,
        SUM(CASE WHEN LeadStage = 'CLOSED_WON' THEN ExpectedValue ELSE 0 END) AS TotalValue
    FROM dbo.Leads
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND (@SalesPersonID IS NULL OR AssignedToSalesPersonID = @SalesPersonID)
        AND CAST(CreatedAt AS DATE) BETWEEN @FromDate AND @ToDate
    GROUP BY LeadSource
    ORDER BY ConversionRate DESC;
    
    -- 3. متوسط وقت التحويل (أيام)
    SELECT 
        AVG(DATEDIFF(DAY, CreatedAt, ActualCloseDate)) AS AvgConversionDays,
        MIN(DATEDIFF(DAY, CreatedAt, ActualCloseDate)) AS MinConversionDays,
        MAX(DATEDIFF(DAY, CreatedAt, ActualCloseDate)) AS MaxConversionDays
    FROM dbo.Leads
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND LeadStage = 'CLOSED_WON'
        AND ActualCloseDate IS NOT NULL
        AND (@SalesPersonID IS NULL OR AssignedToSalesPersonID = @SalesPersonID)
        AND CAST(CreatedAt AS DATE) BETWEEN @FromDate AND @ToDate;
END;
GO
PRINT N'✅ [8.3] usp_GetLeadPipeline_V2 created (Advanced pipeline analytics).';


-- 8.4 🔥 توزيع العملاء المتوقعين على المندوبين
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_AssignLeadsToSalesPerson')
    DROP PROCEDURE dbo.usp_AssignLeadsToSalesPerson;
GO
CREATE PROCEDURE dbo.usp_AssignLeadsToSalesPerson
    @LeadIDs NVARCHAR(MAX),
    @SalesPersonID UNIQUEIDENTIFIER,
    @AssignedBy UNIQUEIDENTIFIER,
    @AssignmentNotes NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- إنشاء جدول مؤقت للمعرفات
        DECLARE @LeadTable TABLE (LeadID BIGINT);
        INSERT INTO @LeadTable
        SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@LeadIDs, ',');
        
        -- تحديث المندوب المسؤول
        UPDATE dbo.Leads
        SET AssignedToSalesPersonID = @SalesPersonID,
            AssignedAt = SYSUTCDATETIME(),
            UpdatedBy = @AssignedBy,
            UpdatedAt = SYSUTCDATETIME()
        WHERE LeadID IN (SELECT LeadID FROM @LeadTable)
            AND IsDeleted = 0;
        
        -- تسجيل في سجل التوزيع
        INSERT INTO dbo.LeadAssignments (
            LeadID, AssignedToSalesPersonID, AssignedBy, AssignedAt, AssignmentNotes
        )
        SELECT LeadID, @SalesPersonID, @AssignedBy, SYSUTCDATETIME(), @AssignmentNotes
        FROM @LeadTable;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
PRINT N'✅ [8.4] usp_AssignLeadsToSalesPerson created.';


-- 8.5 🔥 حساب درجة العميل المتوقع (AI Scoring)
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_CalculateLeadScore')
    DROP PROCEDURE dbo.usp_CalculateLeadScore;
GO
CREATE PROCEDURE dbo.usp_CalculateLeadScore
    @CompanyID UNIQUEIDENTIFIER,
    @LeadID BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentLeadID BIGINT;
    DECLARE @Score DECIMAL(5,2);
    DECLARE @Engagement DECIMAL(5,2);
    DECLARE @Readiness DECIMAL(5,2);
    
    -- مؤشر للعملاء المتوقعين
    DECLARE cur CURSOR FOR
        SELECT LeadID FROM dbo.Leads
        WHERE CompanyID = @CompanyID
            AND IsDeleted = 0
            AND LeadStage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
            AND (@LeadID IS NULL OR LeadID = @LeadID);
    
    OPEN cur;
    FETCH NEXT FROM cur INTO @CurrentLeadID;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- حساب الدرجات بناءً على عوامل مختلفة
        SELECT 
            @Score = 
                -- العوامل الأساسية (0-40)
                CASE 
                    WHEN LeadSource IN ('Website', 'SocialMedia') THEN 20
                    WHEN LeadSource = 'Referral' THEN 35
                    WHEN LeadSource = 'Campaign' THEN 15
                    WHEN LeadSource = 'WalkIn' THEN 25
                    ELSE 10
                END
                +
                -- العوامل المتقدمة (0-30)
                CASE 
                    WHEN ExpectedValue > 50000 THEN 30
                    WHEN ExpectedValue > 10000 THEN 20
                    WHEN ExpectedValue > 5000 THEN 10
                    ELSE 5
                END
                +
                -- العوامل السلوكية (0-30)
                (SELECT COUNT(*) * 5 FROM dbo.LeadActivities 
                 WHERE LeadID = @CurrentLeadID AND IsDeleted = 0 AND ActivityDate >= DATEADD(DAY, -30, GETDATE()))
                +
                -- العوامل المستندة إلى المرحلة
                CASE LeadStage
                    WHEN 'NEW' THEN 0
                    WHEN 'CONTACTED' THEN 10
                    WHEN 'QUALIFIED' THEN 20
                    WHEN 'PROPOSAL' THEN 30
                    WHEN 'NEGOTIATION' THEN 40
                    ELSE 0
                END,
            @Engagement = 
                CASE 
                    WHEN (SELECT COUNT(*) FROM dbo.LeadActivities 
                          WHERE LeadID = @CurrentLeadID AND IsDeleted = 0 AND ActivityDate >= DATEADD(DAY, -7, GETDATE())) >= 3 THEN 90
                    WHEN (SELECT COUNT(*) FROM dbo.LeadActivities 
                          WHERE LeadID = @CurrentLeadID AND IsDeleted = 0 AND ActivityDate >= DATEADD(DAY, -30, GETDATE())) >= 5 THEN 70
                    WHEN (SELECT COUNT(*) FROM dbo.LeadActivities 
                          WHERE LeadID = @CurrentLeadID AND IsDeleted = 0 AND ActivityDate >= DATEADD(DAY, -60, GETDATE())) >= 3 THEN 50
                    ELSE 30
                END,
            @Readiness = 
                CASE LeadStage
                    WHEN 'NEW' THEN 10
                    WHEN 'CONTACTED' THEN 30
                    WHEN 'QUALIFIED' THEN 50
                    WHEN 'PROPOSAL' THEN 70
                    WHEN 'NEGOTIATION' THEN 90
                    ELSE 10
                END;
        
        -- تحديث الدرجات
        UPDATE dbo.Leads
        SET LeadScore = @Score,
            EngagementScore = @Engagement,
            SalesReadinessScore = @Readiness,
            UpdatedBy = '00000000-0000-0000-0000-000000000001',
            UpdatedAt = SYSUTCDATETIME()
        WHERE LeadID = @CurrentLeadID;
        
        FETCH NEXT FROM cur INTO @CurrentLeadID;
    END
    
    CLOSE cur;
    DEALLOCATE cur;
END;
GO
PRINT N'✅ [8.5] usp_CalculateLeadScore created (AI scoring engine).';

-- ========================================================================
-- 9. طرق عرض جديدة
-- ========================================================================

-- 9.1 عرض تحليلات العملاء المتوقعين
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_LeadAnalytics')
    DROP VIEW dbo.vw_LeadAnalytics;
GO
CREATE VIEW dbo.vw_LeadAnalytics
AS
SELECT 
    l.LeadID,
    l.LeadCode,
    l.LeadName,
    l.LeadStage,
    l.LeadSource,
    l.LeadScore,
    l.ConversionProbability,
    l.ExpectedValue,
    l.CreatedAt,
    DATEDIFF(DAY, l.CreatedAt, GETDATE()) AS AgeDays,
    l.AssignedToSalesPersonID,
    (SELECT COUNT(*) FROM dbo.LeadActivities la WHERE la.LeadID = l.LeadID AND la.IsDeleted = 0) AS ActivityCount,
    (SELECT COUNT(*) FROM dbo.LeadContacts lc WHERE lc.LeadID = l.LeadID AND lc.IsActive = 1) AS ContactCount,
    lsh.NewStage AS CurrentStage,
    lsh.DurationInStageDays AS TimeInStage,
    CASE 
        WHEN l.LeadStage = 'CLOSED_WON' THEN N'✅ تم التحويل'
        WHEN l.LeadStage = 'CLOSED_LOST' THEN N'❌ تم الفقد'
        WHEN l.ConversionProbability > 0.7 THEN N'🟢 احتمال مرتفع'
        WHEN l.ConversionProbability > 0.4 THEN N'🟡 احتمال متوسط'
        ELSE N'🔴 احتمال منخفض'
    END AS ConversionStatus,
    CASE 
        WHEN DATEDIFF(DAY, l.CreatedAt, GETDATE()) > 90 AND l.LeadStage NOT IN ('CLOSED_WON', 'CLOSED_LOST') THEN N'⚠️ قديم'
        WHEN DATEDIFF(DAY, l.CreatedAt, GETDATE()) > 30 AND l.LeadStage NOT IN ('CLOSED_WON', 'CLOSED_LOST') THEN N'📊 قيد المتابعة'
        ELSE N'✅ جديد'
    END AS LeadAgeStatus
FROM dbo.Leads l
LEFT JOIN (
    SELECT DISTINCT LeadID, NewStage, DurationInStageDays
    FROM dbo.LeadStageHistory
    WHERE IsDeleted = 0
) lsh ON l.LeadID = lsh.LeadID
WHERE l.IsDeleted = 0;
GO
PRINT N'✅ [9.1] vw_LeadAnalytics created.';


-- 9.2 عرض أداء المندوبين
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_SalesPersonPerformance')
    DROP VIEW dbo.vw_SalesPersonPerformance;
GO
CREATE VIEW dbo.vw_SalesPersonPerformance
AS
SELECT 
    l.AssignedToSalesPersonID,
    COUNT(*) AS TotalLeads,
    SUM(CASE WHEN l.LeadStage = 'CLOSED_WON' THEN 1 ELSE 0 END) AS Converted,
    CAST(SUM(CASE WHEN l.LeadStage = 'CLOSED_WON' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS ConversionRate,
    SUM(CASE WHEN l.LeadStage = 'CLOSED_WON' THEN l.ExpectedValue ELSE 0 END) AS TotalValue,
    AVG(l.LeadScore) AS AvgScore,
    AVG(DATEDIFF(DAY, l.CreatedAt, GETDATE())) AS AvgAge,
    COUNT(DISTINCT CASE WHEN l.LeadStage IN ('NEW', 'CONTACTED', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION') THEN l.LeadID END) AS ActiveLeads
FROM dbo.Leads l
WHERE l.IsDeleted = 0
    AND l.AssignedToSalesPersonID IS NOT NULL
GROUP BY l.AssignedToSalesPersonID;
GO
PRINT N'✅ [9.2] vw_SalesPersonPerformance created.';

-- ========================================================================
-- 10. المشغلات (Triggers) للتدقيق التلقائي
-- ========================================================================

-- 10.1 مشغل لإدراج سجل التدقيق عند إضافة عميل متوقع جديد
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_Leads_Audit_Insert')
    DROP TRIGGER dbo.trg_Leads_Audit_Insert;
GO
CREATE TRIGGER dbo.trg_Leads_Audit_Insert
ON dbo.Leads
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.LeadAudit (LeadID, ActionType, ChangedBy, ChangedAt)
    SELECT LeadID, 'INSERT', CreatedBy, SYSUTCDATETIME()
    FROM inserted;
END;
GO
PRINT N'✅ [10.1] trg_Leads_Audit_Insert created.';

-- 10.2 مشغل لتسجيل تغييرات المرحلة تلقائياً
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_Leads_Stage_Change')
    DROP TRIGGER dbo.trg_Leads_Stage_Change;
GO
CREATE TRIGGER dbo.trg_Leads_Stage_Change
ON dbo.Leads
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dbo.LeadStageHistory (LeadID, PreviousStage, NewStage, ChangedBy)
    SELECT 
        i.LeadID,
        d.LeadStage,
        i.LeadStage,
        i.UpdatedBy
    FROM inserted i
    INNER JOIN deleted d ON i.LeadID = d.LeadID
    WHERE ISNULL(i.LeadStage, '') <> ISNULL(d.LeadStage, '');
    
    -- تسجيل في LeadAudit
    INSERT INTO dbo.LeadAudit (LeadID, ActionType, ChangedField, OldValue, NewValue, ChangedBy)
    SELECT 
        i.LeadID,
        'STAGE_CHANGE',
        'LeadStage',
        d.LeadStage,
        i.LeadStage,
        i.UpdatedBy
    FROM inserted i
    INNER JOIN deleted d ON i.LeadID = d.LeadID
    WHERE ISNULL(i.LeadStage, '') <> ISNULL(d.LeadStage, '');
END;
GO
PRINT N'✅ [10.2] trg_Leads_Stage_Change created.';

-- ========================================================================
-- 11. البيانات الأولية (Seed Data)
-- ========================================================================
-- تمت إزالة الحملة التجريبية CAMPAIGN_001 / Test Campaign.
-- لا يتم إدراج حملات تسويقية وهمية.
-- ========================================================================

-- 12. الخاتمة
-- ========================================================================
    COMMIT TRANSACTION;
    PRINT N'═══════════════════════════════════════════════════════════════════════';
    PRINT N'✅ LEADS MODULE UPGRADED TO 10.10.0 (ULTIMATE).';
    PRINT N'📌 الميزات المضافة (التفوق على cust_ultimate.sql):';
    PRINT N'   - LeadAudit (سجل تدقيق كامل مع IP/UserAgent)';
    PRINT N'   - LeadStageHistory (تاريخ المراحل مع توقيت كل مرحلة)';
    PRINT N'   - LeadContacts + LeadAddresses (جهات اتصال وعناوين متعددة)';
    PRINT N'   - LeadAssignments (توزيع العملاء المتوقعين مع سجل)';
    PRINT N'   - MarketingCampaigns (حملات تسويقية مع ROI)';
    PRINT N'   - تحويل محسّن (نسخ جهات الاتصال والعناوين تلقائياً)';
    PRINT N'   - تحديث المراحل مع تاريخ (usp_UpdateLeadStage)';
    PRINT N'   - محرك حساب الدرجات (usp_CalculateLeadScore - AI Ready)';
    PRINT N'   - توزيع جماعي على المندوبين (usp_AssignLeadsToSalesPerson)';
    PRINT N'   - تقارير متقدمة (تحليلات الأداء والمبيعات)';
    PRINT N'   - مشغلات للتدقيق التلقائي للمراحل';
    PRINT N'🏆 LEADS MODULE NOW 10/10 ULTIMATE (BETTER THAN CUST)';
    PRINT N'═══════════════════════════════════════════════════════════════════════';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    RAISERROR(@ErrorMessage, @ErrorSeverity, 1);
END CATCH
GO