-- ========================================================================
-- FILE: dba/aud/appr_upgrade.sql
-- PROJECT: SHOUTECH ERP V10 - Approval Workflow Engine (UPGRADE to 10/10)
-- VERSION: 10.7.0
-- DESCRIPTION: 
--   ترقية نظام الموافقات بإضافة الميزات المفقودة: تحديد الموافقين الديناميكي،
--   دعم PARALLEL/ANY، سحب الطلب، الموافقة الجماعية، وتكامل AuditLog.
-- ========================================================================

USE [$(DbFileName)];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

PRINT N'═══════════════════════════════════════════════════════════════════════';
PRINT N'SHOUTECH ERP V10 – APPROVAL WORKFLOW ENGINE (UPGRADE to 10.10.0)';
PRINT N'═══════════════════════════════════════════════════════════════════════';
GO

BEGIN TRY
    BEGIN TRANSACTION;

-- ========================================================================
-- 1. إضافة حقول جديدة إلى ApprovalRequests (لتتبع المقاييس)
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.ApprovalRequests') AND name = 'DataHash')
    BEGIN
        ALTER TABLE dbo.ApprovalRequests ADD 
            DataHash NVARCHAR(64) NULL,
            SLAExpiryDate DATETIME2(7) NULL,
            ActualProcessingHours DECIMAL(10,2) NULL,
            WithdrawnBy UNIQUEIDENTIFIER NULL,
            WithdrawnAt DATETIME2(7) NULL,
            WithdrawalReason NVARCHAR(500) NULL;
        PRINT N'✅ [1] Added DataHash, SLA tracking, and withdrawal fields.';
    END

-- ========================================================================
-- 2. إضافة جدول للموافقة الجماعية (Group Approvals)
-- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ApprovalGroupMembers')
    BEGIN
        CREATE TABLE dbo.ApprovalGroupMembers (
            GroupMemberID BIGINT IDENTITY(1,1) NOT NULL,
            CompanyID UNIQUEIDENTIFIER NOT NULL,
            GroupName NVARCHAR(100) NOT NULL,
            MemberUserID UNIQUEIDENTIFIER NOT NULL,
            IsActive BIT NOT NULL DEFAULT 1,
            IsDeleted BIT NOT NULL DEFAULT 0,
            DeletedAt DATETIME2(7) NULL,
            DeletedBy UNIQUEIDENTIFIER NULL,
            CreatedBy UNIQUEIDENTIFIER NOT NULL,
            CreatedAt DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
            UpdatedBy UNIQUEIDENTIFIER NULL,
            UpdatedAt DATETIME2(7) NULL,
            RowVersion ROWVERSION,
            CONSTRAINT PK_ApprovalGroupMembers PRIMARY KEY CLUSTERED (GroupMemberID),
            CONSTRAINT UQ_ApprovalGroupMembers UNIQUE (CompanyID, GroupName, MemberUserID),
            CONSTRAINT FK_ApprovalGroupMembers_Company FOREIGN KEY (CompanyID) REFERENCES MST.dbo.Companies(CompanyID)
        ) WITH (DATA_COMPRESSION = PAGE);
        PRINT N'✅ [2] ApprovalGroupMembers table created (Group approvals).';
    END

    CREATE NONCLUSTERED INDEX IF NOT EXISTS IX_ApprovalGroupMembers_Group 
        ON dbo.ApprovalGroupMembers(GroupName, IsActive) WHERE IsDeleted = 0;
    GO

-- ========================================================================
-- 3. تحديث إجراء إنشاء الطلب (مع تحديد الموافق الديناميكي)
-- ========================================================================
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Approval_CreateRequest_V2')
    DROP PROCEDURE dbo.usp_Approval_CreateRequest_V2;
GO
CREATE PROCEDURE dbo.usp_Approval_CreateRequest_V2
    @CompanyID UNIQUEIDENTIFIER,
    @EntityType NVARCHAR(50),
    @EntityID BIGINT,
    @EntityNumber NVARCHAR(50) = NULL,
    @Amount DECIMAL(18,4) = NULL,
    @Description NVARCHAR(500) = NULL,
    @RequestedBy UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX) = NULL,
    @SLAHours INT = 48,
    @NewRequestID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 1. تحديد سير العمل
        DECLARE @WorkflowID INT;
        DECLARE @ApprovalMode NVARCHAR(20);
        DECLARE @MaxLevels TINYINT;
        DECLARE @AutoEscalateHours INT;
        
        SELECT TOP 1 
            @WorkflowID = WorkflowID,
            @ApprovalMode = ApprovalMode,
            @MaxLevels = MaxLevels,
            @AutoEscalateHours = AutoEscalateAfterHours
        FROM dbo.WorkflowDefinitions
        WHERE CompanyID = @CompanyID
            AND EntityType = @EntityType
            AND IsActive = 1
            AND IsDeleted = 0;
        
        IF @WorkflowID IS NULL
            THROW 50000, 'لا يوجد سير عمل معرّف.', 1;
        
        -- 2. تحديد المستوى الأول ديناميكياً
        DECLARE @FirstLevelNumber TINYINT;
        SELECT TOP 1 @FirstLevelNumber = LevelNumber
        FROM dbo.WorkflowLevels
        WHERE WorkflowID = @WorkflowID
            AND IsActive = 1 AND IsDeleted = 0
            AND (@MinAmountThreshold IS NULL OR @Amount >= @MinAmountThreshold)
            AND (@MaxAmountThreshold IS NULL OR @Amount <= @MaxAmountThreshold)
        ORDER BY LevelNumber;
        
        IF @FirstLevelNumber IS NULL
            THROW 50000, 'لا يوجد مستوى موافقة مناسب.', 1;
        
        -- 3. تحديد الموافق الأول ديناميكياً
        DECLARE @FirstApproverID UNIQUEIDENTIFIER = NULL;
        DECLARE @RequiredRoleCode NVARCHAR(50);
        DECLARE @AllowedUsers NVARCHAR(MAX);
        DECLARE @GroupName NVARCHAR(100);
        
        SELECT 
            @RequiredRoleCode = RequiredRoleCode,
            @AllowedUsers = AllowedUserIDs,
            @GroupName = GroupName
        FROM dbo.WorkflowLevels
        WHERE WorkflowID = @WorkflowID AND LevelNumber = @FirstLevelNumber AND IsActive = 1;
        
        -- محاولة تحديد الموافق بناءً على الدور
        IF @RequiredRoleCode IS NOT NULL
        BEGIN
            SELECT TOP 1 @FirstApproverID = UserID
            FROM dbo.UserRoles ur
            INNER JOIN dbo.Roles r ON ur.RoleID = r.RoleID
            WHERE r.RoleCode = @RequiredRoleCode
                AND ur.IsActive = 1
                AND NOT EXISTS (
                    SELECT 1 FROM dbo.ApprovalDelegations ad
                    WHERE ad.DelegatedBy = ur.UserID
                        AND CAST(GETDATE() AS DATE) BETWEEN ad.StartDate AND ad.EndDate
                        AND ad.IsActive = 1
                        AND (ad.WorkflowID IS NULL OR ad.WorkflowID = @WorkflowID)
                )
            ORDER BY ur.UserID;
        END
        
        -- إذا لم يتم العثور على موافق، استخدم القائمة المحددة
        IF @FirstApproverID IS NULL AND @AllowedUsers IS NOT NULL
        BEGIN
            SELECT TOP 1 @FirstApproverID = CAST(value AS UNIQUEIDENTIFIER)
            FROM STRING_SPLIT(@AllowedUsers, ';')
            WHERE value IS NOT NULL;
        END
        
        -- إذا لم يتم العثور على موافق، استخدم المجموعة
        IF @FirstApproverID IS NULL AND @GroupName IS NOT NULL
        BEGIN
            SELECT TOP 1 @FirstApproverID = MemberUserID
            FROM dbo.ApprovalGroupMembers
            WHERE CompanyID = @CompanyID
                AND GroupName = @GroupName
                AND IsActive = 1 AND IsDeleted = 0;
        END
        
        -- 4. حساب تاريخ انتهاء SLA
        DECLARE @SLAExpiryDate DATETIME2(7) = 
            DATEADD(HOUR, ISNULL(@SLAHours, @AutoEscalateHours), SYSUTCDATETIME());
        
        -- 5. إنشاء الطلب مع DataHash
        DECLARE @HashData NVARCHAR(MAX) = 
            CAST(NEWID() AS NVARCHAR(50)) + '|' + 
            CAST(@EntityID AS NVARCHAR) + '|' + 
            @EntityType + '|' + 
            CAST(@Amount AS NVARCHAR) + '|' + 
            FORMAT(SYSUTCDATETIME(), 'yyyyMMddHHmmssfff');
        
        DECLARE @DataHash NVARCHAR(64) = 
            CONVERT(NVARCHAR(64), HASHBYTES('SHA2_256', @HashData), 2);
        
        INSERT INTO dbo.ApprovalRequests (
            CompanyID, WorkflowID, EntityType, EntityID, EntityNumber,
            RequestedBy, RequestedAt, Amount, Description, Notes,
            CurrentLevelNumber, CurrentApproverID, RequestStatus,
            DataHash, SLAExpiryDate, CreatedBy
        ) VALUES (
            @CompanyID, @WorkflowID, @EntityType, @EntityID, @EntityNumber,
            @RequestedBy, SYSUTCDATETIME(), @Amount, @Description, @Notes,
            @FirstLevelNumber, @FirstApproverID, 'PENDING',
            @DataHash, @SLAExpiryDate, @RequestedBy
        );
        SET @NewRequestID = SCOPE_IDENTITY();
        
        -- 6. تسجيل التاريخ
        INSERT INTO dbo.ApprovalHistory (
            ApprovalRequestID, LevelNumber, ApproverID, Action, Comments, CreatedBy
        ) VALUES (
            @NewRequestID, 0, @RequestedBy, 'APPROVED', N'تم إنشاء طلب الموافقة', @RequestedBy
        );
        
        -- 7. إرسال إشعار
        IF @FirstApproverID IS NOT NULL
        BEGIN
            INSERT INTO dbo.ApprovalNotifications (
                ApprovalRequestID, RecipientUserID, NotificationType,
                Subject, Message, CreatedBy
            ) VALUES (
                @NewRequestID, @FirstApproverID, 'PENDING',
                N'طلب موافقة جديد في انتظارك',
                N'طلب من نوع ' + @EntityType + N' يحتاج إلى مراجعتك (المبلغ: ' + CAST(@Amount AS NVARCHAR) + N')',
                @RequestedBy
            );
        END
        
        -- 8. تسجيل في AuditLog الموحد
        DECLARE @AuditID BIGINT;
        EXEC dbo.usp_Audit_Log
            @CompanyID = @CompanyID,
            @TableName = 'ApprovalRequests',
            @RecordID = CAST(@NewRequestID AS NVARCHAR(100)),
            @ActionType = 'INSERT',
            @UserID = @RequestedBy,
            @ActionDescription = N'تم إنشاء طلب موافقة جديد: ' + @EntityType,
            @NewData = @HashData,
            @NewAuditID = @AuditID OUTPUT;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
PRINT N'✅ [3] usp_Approval_CreateRequest_V2 created (Dynamic approver resolution + AuditLog).';


-- ========================================================================
-- 4. تحديث إجراء الموافقة (دعم PARALLEL/ANY + الموافقة الجماعية)
-- ========================================================================
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Approval_Approve_V2')
    DROP PROCEDURE dbo.usp_Approval_Approve_V2;
GO
CREATE PROCEDURE dbo.usp_Approval_Approve_V2
    @ApprovalRequestID BIGINT,
    @ApproverID UNIQUEIDENTIFIER,
    @Action NVARCHAR(20),
    @Comments NVARCHAR(500) = NULL,
    @IsDelegated BIT = 0,
    @DelegatedFrom UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 1. التحقق من صحة الطلب
        DECLARE @RequestStatus NVARCHAR(20);
        DECLARE @CurrentLevel TINYINT;
        DECLARE @WorkflowID INT;
        DECLARE @EntityType NVARCHAR(50);
        DECLARE @EntityID BIGINT;
        DECLARE @CompanyID UNIQUEIDENTIFIER;
        DECLARE @ApprovalMode NVARCHAR(20);
        DECLARE @MaxLevels TINYINT;
        DECLARE @RequestedBy UNIQUEIDENTIFIER;
        
        SELECT 
            @RequestStatus = RequestStatus,
            @CurrentLevel = CurrentLevelNumber,
            @WorkflowID = WorkflowID,
            @EntityType = EntityType,
            @EntityID = EntityID,
            @CompanyID = CompanyID,
            @RequestedBy = RequestedBy
        FROM dbo.ApprovalRequests
        WHERE ApprovalRequestID = @ApprovalRequestID AND IsDeleted = 0;
        
        IF @RequestStatus IS NULL THROW 50000, 'طلب الموافقة غير موجود.', 1;
        IF @RequestStatus NOT IN ('PENDING', 'IN_PROGRESS') 
            THROW 50000, 'لا يمكن معالجة هذا الطلب لأنه في حالة: ' + @RequestStatus, 1;
        
        SELECT @ApprovalMode = ApprovalMode, @MaxLevels = MaxLevels
        FROM dbo.WorkflowDefinitions WHERE WorkflowID = @WorkflowID;
        
        -- 2. التحقق من التفويض
        DECLARE @IsAuthorized BIT = 0;
        IF @IsDelegated = 1 AND @DelegatedFrom IS NOT NULL
        BEGIN
            IF EXISTS (
                SELECT 1 FROM dbo.ApprovalDelegations
                WHERE DelegatedBy = @DelegatedFrom
                    AND DelegatedTo = @ApproverID
                    AND CAST(GETDATE() AS DATE) BETWEEN StartDate AND EndDate
                    AND IsActive = 1 AND IsDeleted = 0
                    AND (WorkflowID IS NULL OR WorkflowID = @WorkflowID)
            ) SET @IsAuthorized = 1;
        END
        ELSE
        BEGIN
            IF @ApproverID = (SELECT CurrentApproverID FROM dbo.ApprovalRequests WHERE ApprovalRequestID = @ApprovalRequestID)
                SET @IsAuthorized = 1;
        END
        
        IF @IsAuthorized = 0 THROW 50000, 'أنت غير مخوّل للموافقة.', 1;
        
        -- 3. معالجة الإجراء
        IF @Action = 'REJECTED'
        BEGIN
            UPDATE dbo.ApprovalRequests
            SET RequestStatus = 'REJECTED',
                RejectedBy = @ApproverID,
                RejectedAt = SYSUTCDATETIME(),
                RejectionReason = @Comments,
                ActualProcessingHours = DATEDIFF(SECOND, RequestedAt, SYSUTCDATETIME()) / 3600.0
            WHERE ApprovalRequestID = @ApprovalRequestID;
            
            INSERT INTO dbo.ApprovalHistory (
                ApprovalRequestID, LevelNumber, ApproverID, Action, Comments, CreatedBy
            ) VALUES (@ApprovalRequestID, @CurrentLevel, @ApproverID, 'REJECTED', @Comments, @ApproverID);
        END
        ELSE -- APPROVED
        BEGIN
            DECLARE @NextLevel TINYINT = @CurrentLevel + 1;
            DECLARE @IsCompleted BIT = 0;
            
            -- تحديد ما إذا تمت الموافقة على جميع المستويات
            IF @ApprovalMode = 'SEQUENTIAL'
            BEGIN
                IF @CurrentLevel >= @MaxLevels SET @IsCompleted = 1;
            END
            ELSE IF @ApprovalMode = 'ANY'
            BEGIN
                -- أي موافق واحد يكفي
                SET @IsCompleted = 1;
            END
            ELSE IF @ApprovalMode = 'PARALLEL'
            BEGIN
                -- في الوضع المتوازي، يجب موافقة جميع الموافقين
                -- هنا سنتحقق من أن جميع المستويات قد تمت الموافقة عليها
                DECLARE @TotalLevels TINYINT;
                SELECT @TotalLevels = COUNT(*) 
                FROM dbo.WorkflowLevels 
                WHERE WorkflowID = @WorkflowID AND IsActive = 1 AND IsDeleted = 0;
                
                -- نتحقق من أن جميع المستويات تمت الموافقة عليها
                IF NOT EXISTS (
                    SELECT 1 FROM dbo.ApprovalHistory
                    WHERE ApprovalRequestID = @ApprovalRequestID
                        AND Action != 'APPROVED'
                        AND IsDeleted = 0
                ) AND (SELECT COUNT(*) FROM dbo.ApprovalHistory 
                        WHERE ApprovalRequestID = @ApprovalRequestID AND Action = 'APPROVED' AND IsDeleted = 0) >= @TotalLevels
                BEGIN
                    SET @IsCompleted = 1;
                END
                ELSE
                BEGIN
                    -- ننتظر الموافقات الأخرى
                    SET @NextLevel = @CurrentLevel + 1;
                END
            END
            
            IF @IsCompleted = 1
            BEGIN
                -- تمت الموافقة النهائية
                UPDATE dbo.ApprovalRequests
                SET RequestStatus = 'APPROVED',
                    ApprovedBy = @ApproverID,
                    ApprovedAt = SYSUTCDATETIME(),
                    ActualProcessingHours = DATEDIFF(SECOND, RequestedAt, SYSUTCDATETIME()) / 3600.0
                WHERE ApprovalRequestID = @ApprovalRequestID;
                
                INSERT INTO dbo.ApprovalHistory (
                    ApprovalRequestID, LevelNumber, ApproverID, Action, Comments, CreatedBy
                ) VALUES (@ApprovalRequestID, @CurrentLevel, @ApproverID, 'APPROVED', @Comments, @ApproverID);
            END
            ELSE
            BEGIN
                -- تحديد الموافق التالي
                DECLARE @NextApproverID UNIQUEIDENTIFIER = NULL;
                
                IF @ApprovalMode = 'SEQUENTIAL' OR @ApprovalMode = 'PARALLEL'
                BEGIN
                    -- الحصول على الموافق التالي ديناميكياً
                    SELECT TOP 1 @NextApproverID = ApproverID
                    FROM (
                        -- محاولة جلب من دور أو قائمة أو مجموعة
                        SELECT 
                            CASE 
                                WHEN wl.RequiredRoleCode IS NOT NULL 
                                    THEN (SELECT TOP 1 UserID FROM dbo.UserRoles ur 
                                          INNER JOIN dbo.Roles r ON ur.RoleID = r.RoleID
                                          WHERE r.RoleCode = wl.RequiredRoleCode AND ur.IsActive = 1)
                                WHEN wl.AllowedUserIDs IS NOT NULL
                                    THEN (SELECT TOP 1 CAST(value AS UNIQUEIDENTIFIER) 
                                          FROM STRING_SPLIT(wl.AllowedUserIDs, ';'))
                                WHEN wl.GroupName IS NOT NULL
                                    THEN (SELECT TOP 1 MemberUserID FROM dbo.ApprovalGroupMembers 
                                          WHERE GroupName = wl.GroupName AND IsActive = 1 AND IsDeleted = 0)
                                ELSE NULL
                            END AS ApproverID
                        FROM dbo.WorkflowLevels wl
                        WHERE wl.WorkflowID = @WorkflowID
                            AND wl.LevelNumber = @NextLevel
                            AND wl.IsActive = 1 AND wl.IsDeleted = 0
                    ) AS t
                    WHERE ApproverID IS NOT NULL;
                END
                
                -- تحديث الطلب إلى المستوى التالي
                UPDATE dbo.ApprovalRequests
                SET CurrentLevelNumber = @NextLevel,
                    CurrentApproverID = @NextApproverID,
                    RequestStatus = 'IN_PROGRESS',
                    UpdatedBy = @ApproverID,
                    UpdatedAt = SYSUTCDATETIME()
                WHERE ApprovalRequestID = @ApprovalRequestID;
                
                INSERT INTO dbo.ApprovalHistory (
                    ApprovalRequestID, LevelNumber, ApproverID, Action, Comments, CreatedBy
                ) VALUES (@ApprovalRequestID, @CurrentLevel, @ApproverID, 'APPROVED', @Comments, @ApproverID);
                
                -- إرسال إشعار للموافق التالي
                IF @NextApproverID IS NOT NULL
                BEGIN
                    INSERT INTO dbo.ApprovalNotifications (
                        ApprovalRequestID, RecipientUserID, NotificationType,
                        Subject, Message, CreatedBy
                    ) VALUES (
                        @ApprovalRequestID, @NextApproverID, 'PENDING',
                        N'طلب موافقة في انتظارك (المستوى ' + CAST(@NextLevel AS NVARCHAR) + N')',
                        N'تمت الموافقة على المستوى السابق، يرجى مراجعة الطلب.',
                        @ApproverID
                    );
                END
            END
        END
        
        -- تسجيل في AuditLog الموحد
        DECLARE @AuditID BIGINT;
        EXEC dbo.usp_Audit_Log
            @CompanyID = @CompanyID,
            @TableName = 'ApprovalRequests',
            @RecordID = CAST(@ApprovalRequestID AS NVARCHAR(100)),
            @ActionType = 'UPDATE',
            @UserID = @ApproverID,
            @ActionDescription = N'تم ' + CASE WHEN @Action = 'APPROVED' THEN N'الموافقة' ELSE N'الرفض' END + N' على الطلب',
            @NewData = @Comments,
            @NewAuditID = @AuditID OUTPUT;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
PRINT N'✅ [4] usp_Approval_Approve_V2 created (PARALLEL/ANY + Group approvals).';


-- ========================================================================
-- 5. إجراء سحب الطلب (Withdrawal)
-- ========================================================================
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Approval_Withdraw')
    DROP PROCEDURE dbo.usp_Approval_Withdraw;
GO
CREATE PROCEDURE dbo.usp_Approval_Withdraw
    @ApprovalRequestID BIGINT,
    @WithdrawnBy UNIQUEIDENTIFIER,
    @WithdrawalReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @CompanyID UNIQUEIDENTIFIER;
        DECLARE @RequestStatus NVARCHAR(20);
        DECLARE @RequestedBy UNIQUEIDENTIFIER;
        
        SELECT 
            @CompanyID = CompanyID,
            @RequestStatus = RequestStatus,
            @RequestedBy = RequestedBy
        FROM dbo.ApprovalRequests
        WHERE ApprovalRequestID = @ApprovalRequestID AND IsDeleted = 0;
        
        IF @CompanyID IS NULL THROW 50000, 'طلب الموافقة غير موجود.', 1;
        IF @RequestStatus NOT IN ('PENDING', 'IN_PROGRESS')
            THROW 50000, 'لا يمكن سحب هذا الطلب لأنه في حالة: ' + @RequestStatus, 1;
        IF @WithdrawnBy <> @RequestedBy
            THROW 50000, 'يمكن فقط لمقدم الطلب سحبه.', 1;
        
        UPDATE dbo.ApprovalRequests
        SET RequestStatus = 'CANCELLED',
            WithdrawnBy = @WithdrawnBy,
            WithdrawnAt = SYSUTCDATETIME(),
            WithdrawalReason = @WithdrawalReason,
            UpdatedBy = @WithdrawnBy,
            UpdatedAt = SYSUTCDATETIME()
        WHERE ApprovalRequestID = @ApprovalRequestID;
        
        INSERT INTO dbo.ApprovalHistory (
            ApprovalRequestID, LevelNumber, ApproverID, Action, Comments, CreatedBy
        ) VALUES (
            @ApprovalRequestID, 0, @WithdrawnBy, 'APPROVED', 
            N'تم سحب الطلب من قبل مقدمه. السبب: ' + ISNULL(@WithdrawalReason, 'غير محدد'),
            @WithdrawnBy
        );
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
PRINT N'✅ [5] usp_Approval_Withdraw created (Request withdrawal).';


-- ========================================================================
-- 6. تحديث تقرير الأداء (مع مقاييس SLA)
-- ========================================================================
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'usp_Approval_PerformanceReport_V2')
    DROP PROCEDURE dbo.usp_Approval_PerformanceReport_V2;
GO
CREATE PROCEDURE dbo.usp_Approval_PerformanceReport_V2
    @CompanyID UNIQUEIDENTIFIER,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(MONTH, -3, GETDATE());
    IF @ToDate IS NULL SET @ToDate = GETDATE();
    
    SELECT 
        EntityType,
        RequestStatus,
        COUNT(*) AS TotalRequests,
        AVG(DATEDIFF(HOUR, RequestedAt, 
            CASE WHEN RequestStatus = 'APPROVED' THEN ApprovedAt 
                 WHEN RequestStatus = 'REJECTED' THEN RejectedAt 
                 WHEN RequestStatus = 'CANCELLED' THEN WithdrawnAt
                 ELSE GETDATE() END)) AS AvgHoursToComplete,
        AVG(ActualProcessingHours) AS AvgActualHours,
        SUM(Amount) AS TotalAmount,
        CAST(COUNT(CASE WHEN RequestStatus = 'APPROVED' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS ApprovalRate,
        CAST(COUNT(CASE WHEN RequestStatus IN ('PENDING', 'IN_PROGRESS') AND SLAExpiryDate < GETDATE() THEN 1 END) * 100.0 / NULLIF(COUNT(CASE WHEN RequestStatus IN ('PENDING', 'IN_PROGRESS') THEN 1 END), 0) AS DECIMAL(5,2)) AS SLABreachRate
    FROM dbo.ApprovalRequests
    WHERE CompanyID = @CompanyID
        AND IsDeleted = 0
        AND CAST(RequestedAt AS DATE) >= @FromDate
        AND CAST(RequestedAt AS DATE) <= @ToDate
    GROUP BY EntityType, RequestStatus
    ORDER BY EntityType, RequestStatus;
END;
GO
PRINT N'✅ [6] usp_Approval_PerformanceReport_V2 created (With SLA metrics).';

-- ========================================================================
-- 7. إضافة View للطلبات المنتهكة لـ SLA
-- ========================================================================
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_SLABreachApprovals')
    DROP VIEW dbo.vw_SLABreachApprovals;
GO
CREATE VIEW dbo.vw_SLABreachApprovals
AS
SELECT 
    ar.ApprovalRequestID,
    ar.EntityType,
    ar.EntityNumber,
    ar.Amount,
    ar.RequestedBy,
    ar.RequestedAt,
    ar.SLAExpiryDate,
    DATEDIFF(HOUR, ar.SLAExpiryDate, GETDATE()) AS HoursOverdue,
    ar.CurrentApproverID,
    u.UserName AS CurrentApproverName,
    ar.RequestStatus,
    wf.WorkflowNameAR AS WorkflowName
FROM dbo.ApprovalRequests ar
INNER JOIN dbo.WorkflowDefinitions wf ON ar.WorkflowID = wf.WorkflowID
LEFT JOIN dbo.Users u ON ar.CurrentApproverID = u.UserID
WHERE ar.RequestStatus IN ('PENDING', 'IN_PROGRESS')
    AND ar.SLAExpiryDate < GETDATE()
    AND ar.IsDeleted = 0;
GO
PRINT N'✅ [7] vw_SLABreachApprovals created (SLA violation monitoring).';


-- ========================================================================
-- 8. البيانات الأولية (Seed Data للمجموعات)
-- ========================================================================
DECLARE @SystemCompanyID UNIQUEIDENTIFIER;
SELECT TOP 1 @SystemCompanyID = CompanyID FROM MST.dbo.Companies;

IF NOT EXISTS (SELECT 1 FROM dbo.ApprovalGroupMembers WHERE GroupName = 'Finance_Committee' AND CompanyID = @SystemCompanyID)
BEGIN
    -- يمكن إضافة أعضاء المجموعة هنا
    PRINT N'✅ [8] Approval groups seeded (placeholder).';
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