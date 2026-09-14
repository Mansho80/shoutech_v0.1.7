-- ========================================================================
-- ShouTech ERP
-- FILE: dba/fin/coa.sql
-- PURPOSE: الدليل المحاسبي المبسط العام
--
-- هذا الدليل هو الدليل الافتراضي العام للمنشأة.
-- الأدلة المحلية مثل السعودية والخليج والأردن ولبنان وسوريا
-- تكون منفصلة عن هذا الدليل.
--
-- PRINCIPLES:
-- 1. الدليل مبسط ومناسب لمعظم المنشآت.
-- 2. الحساب يمكن أن يكون أبًا وحساب ترحيل في نفس الوقت إذا لم يكن له أبناء.
-- 3. عند إنشاء أول ابن للحساب يتحول إلى حساب تجميعي.
-- 4. الحساب الذي لديه أبناء لا يقبل الترحيل المباشر.
-- 5. الحسابات الختامية ليست جزءًا من دليل الحسابات.
-- 6. الأرباح والخسائر والمتاجرة والميزانية تقارير وليست حسابات.
-- 7. صافي المبيعات وصافي المشتريات بنود تجميعية.
-- ========================================================================

SET NOCOUNT ON;

DECLARE @CompanyID NVARCHAR(50) = N'$(CompanyID)';

PRINT N'============================================================';
PRINT N'ShouTech ERP - Simplified Chart of Accounts';
PRINT N'الدليل المحاسبي المبسط العام';
PRINT N'============================================================';


-- ========================================================================
-- 1 - الأصول
-- ========================================================================

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID,
    AccountCode,
    ParentAccountCode,
    AccountNameAR,
    AccountNameEN,
    AccountType,
    AccountNature,
    AccountLevel,
    IsHeader,
    FinancialStatementCategory
)
VALUES
(
    @CompanyID,
    '1',
    NULL,
    N'الأصول',
    'Assets',
    'ASSET',
    'DEBIT',
    1,
    1,
    'ASSETS'
);


-- ------------------------------------------------------------------------
-- 11 - الأصول الثابتة
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '11', '1',
 N'الأصول الثابتة', 'Fixed Assets',
 'ASSET', 'DEBIT', 2, 1,
 'NON_CURRENT_ASSETS'),

(@CompanyID, '111', '11',
 N'الأراضي', 'Land',
 'ASSET', 'DEBIT', 3, 0,
 'NON_CURRENT_ASSETS'),

(@CompanyID, '112', '11',
 N'المباني', 'Buildings',
 'ASSET', 'DEBIT', 3, 0,
 'NON_CURRENT_ASSETS'),

(@CompanyID, '113', '11',
 N'السيارات', 'Vehicles',
 'ASSET', 'DEBIT', 3, 0,
 'NON_CURRENT_ASSETS'),

(@CompanyID, '114', '11',
 N'الآلات والمعدات', 'Machinery & Equipment',
 'ASSET', 'DEBIT', 3, 0,
 'NON_CURRENT_ASSETS'),

(@CompanyID, '115', '11',
 N'الأثاث والتجهيزات', 'Furniture & Equipment',
 'ASSET', 'DEBIT', 3, 0,
 'NON_CURRENT_ASSETS'),

(@CompanyID, '116', '11',
 N'مجمع الإهلاك', 'Accumulated Depreciation',
 'ASSET', 'CREDIT', 3, 0,
 'NON_CURRENT_ASSETS');


-- ------------------------------------------------------------------------
-- 12 - الأصول المتداولة
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '12', '1',
 N'الأصول المتداولة', 'Current Assets',
 'ASSET', 'DEBIT', 2, 1,
 'CURRENT_ASSETS'),

(@CompanyID, '121', '12',
 N'العملاء', 'Customers',
 'ASSET', 'DEBIT', 3, 0,
 'CURRENT_ASSETS'),

(@CompanyID, '122', '12',
 N'المخزون', 'Inventory',
 'ASSET', 'DEBIT', 3, 0,
 'CURRENT_ASSETS'),

(@CompanyID, '123', '12',
 N'أوراق القبض', 'Notes Receivable',
 'ASSET', 'DEBIT', 3, 0,
 'CURRENT_ASSETS'),

(@CompanyID, '124', '12',
 N'المصروفات المقدمة', 'Prepaid Expenses',
 'ASSET', 'DEBIT', 3, 0,
 'CURRENT_ASSETS'),

(@CompanyID, '125', '12',
 N'الضرائب والذمم المدينة الأخرى', 'Other Receivables',
 'ASSET', 'DEBIT', 3, 0,
 'CURRENT_ASSETS');


-- ------------------------------------------------------------------------
-- 13 - النقدية وما في حكمها
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '13', '1',
 N'النقدية وما في حكمها', 'Cash & Cash Equivalents',
 'ASSET', 'DEBIT', 2, 1,
 'CASH'),

(@CompanyID, '131', '13',
 N'الصندوق', 'Cash',
 'ASSET', 'DEBIT', 3, 0,
 'CASH'),

(@CompanyID, '132', '13',
 N'البنوك', 'Banks',
 'ASSET', 'DEBIT', 3, 0,
 'CASH'),

(@CompanyID, '133', '13',
 N'الودائع', 'Deposits',
 'ASSET', 'DEBIT', 3, 0,
 'CASH');


-- ========================================================================
-- 2 - الخصوم
-- ========================================================================

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '2', NULL,
 N'الخصوم', 'Liabilities',
 'LIABILITY', 'CREDIT', 1, 1,
 'LIABILITIES');


-- ------------------------------------------------------------------------
-- 21 - الخصوم المتداولة
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '21', '2',
 N'الخصوم المتداولة', 'Current Liabilities',
 'LIABILITY', 'CREDIT', 2, 1,
 'CURRENT_LIABILITIES'),

(@CompanyID, '211', '21',
 N'الموردون', 'Suppliers',
 'LIABILITY', 'CREDIT', 3, 0,
 'CURRENT_LIABILITIES'),

(@CompanyID, '212', '21',
 N'أوراق الدفع', 'Notes Payable',
 'LIABILITY', 'CREDIT', 3, 0,
 'CURRENT_LIABILITIES'),

(@CompanyID, '213', '21',
 N'الضرائب المستحقة', 'Taxes Payable',
 'LIABILITY', 'CREDIT', 3, 0,
 'CURRENT_LIABILITIES'),

(@CompanyID, '214', '21',
 N'الرواتب المستحقة', 'Salaries Payable',
 'LIABILITY', 'CREDIT', 3, 0,
 'CURRENT_LIABILITIES'),

(@CompanyID, '215', '21',
 N'ذمم دائنة أخرى', 'Other Payables',
 'LIABILITY', 'CREDIT', 3, 0,
 'CURRENT_LIABILITIES');


-- ------------------------------------------------------------------------
-- 22 - الخصوم غير المتداولة
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '22', '2',
 N'الخصوم غير المتداولة', 'Non-Current Liabilities',
 'LIABILITY', 'CREDIT', 2, 1,
 'NON_CURRENT_LIABILITIES'),

(@CompanyID, '221', '22',
 N'القروض طويلة الأجل', 'Long-term Loans',
 'LIABILITY', 'CREDIT', 3, 0,
 'NON_CURRENT_LIABILITIES');


-- ========================================================================
-- 3 - الإيرادات
-- ========================================================================

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '3', NULL,
 N'الإيرادات', 'Revenue',
 'REVENUE', 'CREDIT', 1, 1,
 'REVENUE');


-- ------------------------------------------------------------------------
-- 31 - صافي المبيعات
--
-- صافي المبيعات =
-- المبيعات - مردودات المبيعات - خصم المبيعات
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '31', '3',
 N'صافي المبيعات', 'Net Sales',
 'REVENUE', 'CREDIT', 2, 1,
 'OPERATING_REVENUE'),

(@CompanyID, '311', '31',
 N'المبيعات', 'Sales',
 'REVENUE', 'CREDIT', 3, 0,
 'OPERATING_REVENUE'),

(@CompanyID, '312', '31',
 N'مردودات المبيعات', 'Sales Returns',
 'REVENUE', 'DEBIT', 3, 0,
 'OPERATING_REVENUE'),

(@CompanyID, '313', '31',
 N'خصم المبيعات', 'Sales Discounts',
 'REVENUE', 'DEBIT', 3, 0,
 'OPERATING_REVENUE');


-- ------------------------------------------------------------------------
-- 32 - الإيرادات الأخرى
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '32', '3',
 N'الإيرادات الأخرى', 'Other Income',
 'REVENUE', 'CREDIT', 2, 0,
 'OTHER_INCOME');


-- ========================================================================
-- 4 - صافي المشتريات
--
-- صافي المشتريات =
-- المشتريات + مصاريف الشراء
-- - مردودات المشتريات
-- - خصم المشتريات
--
-- هذا القسم مهم جدًا للمنشآت التجارية التي تستخدم نظام الجرد الدوري.
-- ========================================================================

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '4', NULL,
 N'صافي المشتريات', 'Net Purchases',
 'EXPENSE', 'DEBIT', 1, 1,
 'COGS');


-- المشتريات

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '41', '4',
 N'المشتريات', 'Purchases',
 'EXPENSE', 'DEBIT', 2, 0,
 'COGS');


-- مردودات المشتريات

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '42', '4',
 N'مردودات المشتريات', 'Purchase Returns',
 'EXPENSE', 'CREDIT', 2, 0,
 'COGS');


-- خصم المشتريات

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '43', '4',
 N'خصم المشتريات', 'Purchase Discounts',
 'EXPENSE', 'CREDIT', 2, 0,
 'COGS');


-- مصاريف الشراء

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '44', '4',
 N'مصاريف الشراء', 'Purchase Expenses',
 'EXPENSE', 'DEBIT', 2, 0,
 'COGS');


-- ========================================================================
-- 5 - المصروفات
-- ========================================================================

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '5', NULL,
 N'المصروفات', 'Expenses',
 'EXPENSE', 'DEBIT', 1, 1,
 'EXPENSES');


-- ------------------------------------------------------------------------
-- 51 - المصروفات الإدارية
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '51', '5',
 N'المصروفات الإدارية', 'Administrative Expenses',
 'EXPENSE', 'DEBIT', 2, 1,
 'OPERATING_EXPENSES'),

(@CompanyID, '511', '51',
 N'الرواتب والأجور', 'Salaries & Wages',
 'EXPENSE', 'DEBIT', 3, 0,
 'OPERATING_EXPENSES'),

(@CompanyID, '512', '51',
 N'الإيجار', 'Rent',
 'EXPENSE', 'DEBIT', 3, 0,
 'OPERATING_EXPENSES'),

(@CompanyID, '513', '51',
 N'الكهرباء والمياه والاتصالات', 'Utilities & Communications',
 'EXPENSE', 'DEBIT', 3, 0,
 'OPERATING_EXPENSES'),

(@CompanyID, '514', '51',
 N'الصيانة', 'Maintenance',
 'EXPENSE', 'DEBIT', 3, 0,
 'OPERATING_EXPENSES'),

(@CompanyID, '515', '51',
 N'المصاريف المكتبية', 'Office Expenses',
 'EXPENSE', 'DEBIT', 3, 0,
 'OPERATING_EXPENSES');


-- ------------------------------------------------------------------------
-- 52 - مصروفات البيع والتوزيع
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '52', '5',
 N'مصروفات البيع والتوزيع', 'Selling & Distribution Expenses',
 'EXPENSE', 'DEBIT', 2, 1,
 'OPERATING_EXPENSES'),

(@CompanyID, '521', '52',
 N'الدعاية والإعلان', 'Advertising',
 'EXPENSE', 'DEBIT', 3, 0,
 'OPERATING_EXPENSES'),

(@CompanyID, '522', '52',
 N'النقل والتوصيل', 'Transportation & Delivery',
 'EXPENSE', 'DEBIT', 3, 0,
 'OPERATING_EXPENSES');


-- ------------------------------------------------------------------------
-- 53 - المصروفات المالية
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '53', '5',
 N'المصروفات المالية', 'Financial Expenses',
 'EXPENSE', 'DEBIT', 2, 1,
 'FINANCIAL_EXPENSES'),

(@CompanyID, '531', '53',
 N'مصروفات بنكية', 'Bank Charges',
 'EXPENSE', 'DEBIT', 3, 0,
 'FINANCIAL_EXPENSES'),

(@CompanyID, '532', '53',
 N'فوائد ومصاريف تمويلية', 'Finance Costs',
 'EXPENSE', 'DEBIT', 3, 0,
 'FINANCIAL_EXPENSES');


-- ------------------------------------------------------------------------
-- 54 - مصروفات أخرى
-- ------------------------------------------------------------------------

INSERT INTO dbo.ChartOfAccounts
(
    CompanyID, AccountCode, ParentAccountCode,
    AccountNameAR, AccountNameEN,
    AccountType, AccountNature,
    AccountLevel, IsHeader,
    FinancialStatementCategory
)
VALUES
(@CompanyID, '54', '5',
 N'مصروفات أخرى', 'Other Expenses',
 'EXPENSE', 'DEBIT', 2, 0,
 'OTHER_EXPENSES');


-- ========================================================================
-- END
-- ========================================================================

PRINT N'============================================================';
PRINT N'تم إنشاء الدليل المحاسبي المبسط بنجاح.';
PRINT N'عدد الحسابات: 52 حسابًا تقريبًا حسب بنية الجدول.';
PRINT N'الحسابات الختامية = تقارير وليست حسابات.';
PRINT N'صافي المبيعات وصافي المشتريات = حسابات تجميعية.';
PRINT N'============================================================';

GO