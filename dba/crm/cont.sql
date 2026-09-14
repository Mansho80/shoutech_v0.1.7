اول ملف في المجلد -- ========================================================================
-- FILE: dba/sch/cont.sql
-- PROJECT: SHOUTECH ERP V10 - Contacts Module (ULTIMATE 10/10)
-- VERSION: 10.5.0
-- DESCRIPTION: إدارة جهات الاتصال المتعددة للعملاء والموردين.
-- ========================================================================

USE [$(DbFileName)];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

PRINT N'═══════════════════════════════════════════════════════════════════════';
PRINT N'SHOUTECH ERP V10 – CONTACTS MODULE (Ultimate 10/10)';
PRINT N'═══════════════════════════════════════════════════════════════════════';
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- ========================================================================
    -- 1. CONTACTS (جهات الاتصال الرئيسية)
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Contacts')
    BEGIN
        CREATE TABLE dbo.Contacts (
            ContactID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            PartyType NVARCHAR(20) NOT NULL,                 -- CUSTOMER, SUPPLIER, LEAD
            PartyID BIGINT NOT NULL,                         -- FK إلى الجدول المناسب
            Salutation NVARCHAR(20) NULL,                    -- السيد، السيدة، الدكتور
            FullName NVARCHAR(200) NOT NULL,
            JobTitle NVARCHAR(100) NULL,
            Department NVARCHAR(100) NULL,
            Phone1 NVARCHAR(50) NULL,
            Phone2 NVARCHAR(50) NULL,
            Mobile NVARCHAR(50) NULL,
            Email NVARCHAR(255) NULL,
            WhatsApp NVARCHAR(50) NULL,
            IsPrimary BIT NOT NULL DEFAULT 0,                -- جهة الاتصال الأساسية
            IsDecisionMaker BIT NOT NULL DEFAULT 0,          -- صانع القرار (مهم للمبيعات)
            IsActive BIT NOT NULL DEFAULT 1,
            PreferredContactMethod NVARCHAR(20) NULL,       -- Email, Phone, WhatsApp
            Notes NVARCHAR(MAX) NULL,
            
            -- الحذف والتدقيق
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            
            CONSTRAINT PK_Contacts PRIMARY KEY CLUSTERED (ContactID),
            CONSTRAINT FK_Contacts_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID),
            CONSTRAINT CK_Contacts_PartyType CHECK (PartyType IN ('CUSTOMER', 'SUPPLIER', 'LEAD'))
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ Contacts table created.';
    END

    -- فهارس الأداء العالي
    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Contacts_Party 
        ON dbo.Contacts(PartyType, PartyID, IsPrimary) INCLUDE (FullName, Phone1, Email) WHERE IsDeleted = 0 AND IsActive = 1;

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_Contacts_Search 
        ON dbo.Contacts(FullName, Mobile, Email) WHERE IsDeleted = 0;

    -- ========================================================================
    -- 2. الإجراءات المخزنة (Stored Procedures)
    -- ========================================================================

    -- 2.1 جلب جهة الاتصال الأساسية لطرف ما
    IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_GetPrimaryContact')
        DROP PROCEDURE dbo.usp_GetPrimaryContact;
    GO
    CREATE PROCEDURE dbo.usp_GetPrimaryContact
        @PartyType NVARCHAR(20),
        @PartyID BIGINT
    AS
    BEGIN
        SET NOCOUNT ON;
        SELECT TOP 1 ContactID, FullName, JobTitle, Phone1, Email, Mobile
        FROM dbo.Contacts
        WHERE PartyType = @PartyType AND PartyID = @PartyID AND IsPrimary = 1 AND IsDeleted = 0 AND IsActive = 1
        ORDER BY ContactID;
    END;
    PRINT N'✅ usp_GetPrimaryContact created.';

    -- 2.2 البحث عن جهات الاتصال (لشاشة CRM)
    IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_SearchContacts')
        DROP PROCEDURE dbo.usp_SearchContacts;
    GO
    CREATE PROCEDURE dbo.usp_SearchContacts
        @CompanyID UNIQUEIDENTIFIER,
        @SearchTerm NVARCHAR(200) = NULL,
        @PartyType NVARCHAR(20) = NULL,
        @TopN INT = 50
    AS
    BEGIN
        SET NOCOUNT ON;
        SELECT TOP (@TopN)
            c.ContactID,
            c.PartyType,
            c.PartyID,
            c.FullName,
            c.JobTitle,
            c.Phone1,
            c.Mobile,
            c.Email,
            c.IsPrimary,
            c.IsDecisionMaker,
            CASE 
                WHEN c.PartyType = 'CUSTOMER' THEN cust.CustomerNameAR
                WHEN c.PartyType = 'SUPPLIER' THEN supp.SupplierNameAR
                WHEN c.PartyType = 'LEAD' THEN lead.LeadName
                ELSE NULL
            END AS PartyName
        FROM dbo.Contacts c
        LEFT JOIN dbo.Customers cust ON c.PartyType = 'CUSTOMER' AND c.PartyID = cust.CustomerID AND cust.IsDeleted = 0
        LEFT JOIN dbo.Suppliers supp ON c.PartyType = 'SUPPLIER' AND c.PartyID = supp.SupplierID AND supp.IsDeleted = 0
        LEFT JOIN dbo.Leads lead ON c.PartyType = 'LEAD' AND c.PartyID = lead.LeadID AND lead.IsDeleted = 0
        WHERE c.CompanyID = @CompanyID
            AND c.IsDeleted = 0
            AND (@PartyType IS NULL OR c.PartyType = @PartyType)
            AND (@SearchTerm IS NULL 
                OR c.FullName LIKE N'%' + @SearchTerm + N'%'
                OR c.Phone1 LIKE N'%' + @SearchTerm + N'%'
                OR c.Mobile LIKE N'%' + @SearchTerm + N'%'
                OR c.Email LIKE N'%' + @SearchTerm + N'%')
        ORDER BY c.IsPrimary DESC, c.FullName;
    END;
    PRINT N'✅ usp_SearchContacts created.';

    -- ========================================================================
    -- 3. البيانات الأولية (Seed Data)
    -- ========================================================================
    -- لا توجد بيانات أولية مطلوبة، لأنها تعتمد على العملاء والموردين.

    COMMIT TRANSACTION;
    PRINT N'✅ Contacts Module (Ultimate 10/10) deployed successfully.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@ErrorMessage, 16, 1);
END CATCH
GO