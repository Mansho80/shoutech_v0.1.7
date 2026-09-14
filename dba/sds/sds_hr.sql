-- ═══════════════════════════════════════════════════════════════════════════
-- FILE: dba/sds/sds_hr.sql
-- PURPOSE: HR Catalog Seed (Departments + Job Titles only) — No demo employees
-- GRADE: Enterprise — Reference data only
-- ═══════════════════════════════════════════════════════════════════════════

USE [$(DbFileName)];
GO

SET NOCOUNT ON;
GO

PRINT N'🌱 Seeding HR catalog (Departments / JobTitles) — no operational demo data...';
GO

-- الأقسام (مرجع هيكلي فقط)
IF NOT EXISTS (SELECT 1 FROM dbo.Departments WHERE DepartmentCode = 'ADM')
BEGIN
    INSERT INTO dbo.Departments (CompanyID, DepartmentCode, DepartmentNameAR, DepartmentNameEN, CostCenterCode)
    VALUES 
    ('$(CompanyID)', 'ADM', N'الإدارة العامة', 'General Management', 'CC-001'),
    ('$(CompanyID)', 'FIN', N'المالية', 'Finance', 'CC-002'),
    ('$(CompanyID)', 'SAL', N'المبيعات والتسويق', 'Sales & Marketing', 'CC-003'),
    ('$(CompanyID)', 'INV', N'المخازن واللوجستيات', 'Inventory & Logistics', 'CC-004'),
    ('$(CompanyID)', 'IT', N'تقنية المعلومات', 'IT Department', 'CC-005');
END
GO

-- المسميات الوظيفية (مرجع هيكلي فقط — بدون موظفين)
IF NOT EXISTS (SELECT 1 FROM dbo.JobTitles WHERE JobTitleCode = 'CEO')
BEGIN
    INSERT INTO dbo.JobTitles (CompanyID, JobTitleCode, JobTitleNameAR, JobTitleNameEN, JobGrade, MinSalary, MaxSalary)
    VALUES 
    ('$(CompanyID)', 'CEO', N'المدير العام', 'CEO', 'A', 50000, 80000),
    ('$(CompanyID)', 'ACC-MGR', N'مدير الحسابات', 'Accounting Manager', 'B', 15000, 25000),
    ('$(CompanyID)', 'ACC', N'محاسب', 'Accountant', 'C', 6000, 12000),
    ('$(CompanyID)', 'SAL-REP', N'مندوب مبيعات', 'Sales Representative', 'C', 4000, 8000),
    ('$(CompanyID)', 'WH-MGR', N'مدير مستودع', 'Warehouse Manager', 'B', 8000, 15000),
    ('$(CompanyID)', 'IT-SPEC', N'أخصائي نظم', 'IT Specialist', 'B', 10000, 18000);
END
GO

PRINT N'✅ HR catalog seeded (Departments + JobTitles only). No employees / contracts.';
GO
