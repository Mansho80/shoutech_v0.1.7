-- ═══════════════════════════════════════════════════════════════════════════
-- ShouTech ERP — Chart of Accounts: SYRIA (الجمهورية العربية السورية)
-- Currency: SYP | Standards: Syrian commercial practice + IFRS-aligned
-- Tax notes: Sales tax / withholding as applicable by current regulations
-- ═══════════════════════════════════════════════════════════════════════════
SET NOCOUNT ON;
DECLARE @CompanyID NVARCHAR(50) = N'$(CompanyID)';

-- Root
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '1', NULL, N'الأصول', 'Assets', 'ASSET', 'DEBIT', 1, 1, 'ASSETS'),
(@CompanyID, '2', NULL, N'الخصوم', 'Liabilities', 'LIABILITY', 'CREDIT', 1, 1, 'LIABILITIES'),
(@CompanyID, '3', NULL, N'حقوق الملكية', 'Equity', 'EQUITY', 'CREDIT', 1, 1, 'EQUITY'),
(@CompanyID, '4', NULL, N'الإيرادات', 'Revenue', 'REVENUE', 'CREDIT', 1, 1, 'REVENUE'),
(@CompanyID, '5', NULL, N'المصروفات', 'Expenses', 'EXPENSE', 'DEBIT', 1, 1, 'EXPENSES');

-- Assets
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '11', '1', N'الأصول المتداولة', 'Current Assets', 'ASSET', 'DEBIT', 2, 1, 'CURRENT_ASSETS'),
(@CompanyID, '111', '11', N'النقدية وما في حكمها', 'Cash & Equivalents', 'ASSET', 'DEBIT', 3, 1, 'CURRENT_ASSETS'),
(@CompanyID, '1111', '111', N'صندوق نقدي', 'Cash on Hand', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1112', '111', N'صندوق مبيعات', 'Sales Cash Box', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1113', '111', N'بنك محلي - حساب جاري', 'Local Bank - Current', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1114', '111', N'بنك - حساب بالعملة الأجنبية', 'Foreign Currency Bank', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '112', '11', N'الذمم المدينة', 'Receivables', 'ASSET', 'DEBIT', 3, 1, 'CURRENT_ASSETS'),
(@CompanyID, '1121', '112', N'عملاء محليون', 'Local Customers', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1122', '112', N'عملاء تصدير', 'Export Customers', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1123', '112', N'أوراق قبض', 'Notes Receivable', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1124', '112', N'مخصص ديون مشكوك فيها', 'Allowance for Doubtful Accounts', 'ASSET', 'CREDIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '113', '11', N'المخزون', 'Inventory', 'ASSET', 'DEBIT', 3, 1, 'CURRENT_ASSETS'),
(@CompanyID, '1131', '113', N'بضاعة جاهزة', 'Finished Goods', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1132', '113', N'مواد أولية', 'Raw Materials', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1133', '113', N'بضاعة بالطريق', 'Goods in Transit', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '114', '11', N'مصروفات مدفوعة مقدماً', 'Prepaid Expenses', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '115', '11', N'ضرائب مستردة / مدينة', 'Tax Receivable', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '12', '1', N'الأصول غير المتداولة', 'Non-Current Assets', 'ASSET', 'DEBIT', 2, 1, 'NON_CURRENT_ASSETS'),
(@CompanyID, '121', '12', N'أراضي', 'Land', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '122', '12', N'مباني وإنشاءات', 'Buildings', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '123', '12', N'آلات ومعدات', 'Machinery & Equipment', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '124', '12', N'وسائل نقل', 'Vehicles', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '125', '12', N'أثاث وتجهيزات', 'Furniture & Fixtures', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '126', '12', N'مجمع اهتلاك الأصول الثابتة', 'Accumulated Depreciation', 'ASSET', 'CREDIT', 3, 0, 'NON_CURRENT_ASSETS');

-- Liabilities
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '21', '2', N'الخصوم المتداولة', 'Current Liabilities', 'LIABILITY', 'CREDIT', 2, 1, 'CURRENT_LIABILITIES'),
(@CompanyID, '211', '21', N'موردون', 'Accounts Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '212', '21', N'أوراق دفع', 'Notes Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '213', '21', N'قروض قصيرة الأجل', 'Short-term Loans', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '214', '21', N'ضريبة مبيعات مستحقة', 'Sales Tax Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '215', '21', N'ضريبة دخل مستحقة', 'Income Tax Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '216', '21', N'تأمينات اجتماعية مستحقة', 'Social Security Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '217', '21', N'رواتب وأجور مستحقة', 'Salaries Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '22', '2', N'الخصوم غير المتداولة', 'Non-Current Liabilities', 'LIABILITY', 'CREDIT', 2, 1, 'NON_CURRENT_LIABILITIES'),
(@CompanyID, '221', '22', N'قروض طويلة الأجل', 'Long-term Loans', 'LIABILITY', 'CREDIT', 3, 0, 'NON_CURRENT_LIABILITIES');

-- Equity
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '31', '3', N'رأس المال', 'Capital', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '32', '3', N'احتياطي قانوني', 'Legal Reserve', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '33', '3', N'أرباح مرحلة', 'Retained Earnings', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '34', '3', N'أرباح / خسائر السنة الجارية', 'Current Year P/L', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY');

-- Revenue
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '41', '4', N'إيرادات التشغيل', 'Operating Revenue', 'REVENUE', 'CREDIT', 2, 1, 'OPERATING_REVENUE'),
(@CompanyID, '411', '41', N'مبيعات محلية', 'Local Sales', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '412', '41', N'مبيعات تصدير', 'Export Sales', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '413', '41', N'مردودات وخصم مسموح به', 'Sales Returns & Allowances', 'REVENUE', 'DEBIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '42', '4', N'إيرادات أخرى', 'Other Income', 'REVENUE', 'CREDIT', 2, 0, 'OTHER_INCOME');

-- Expenses
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '51', '5', N'تكلفة المبيعات', 'Cost of Sales', 'EXPENSE', 'DEBIT', 2, 1, 'COGS'),
(@CompanyID, '511', '51', N'تكلفة البضاعة المباعة', 'Cost of Goods Sold', 'EXPENSE', 'DEBIT', 3, 0, 'COGS'),
(@CompanyID, '52', '5', N'مصروفات التشغيل', 'Operating Expenses', 'EXPENSE', 'DEBIT', 2, 1, 'OPERATING_EXPENSES'),
(@CompanyID, '521', '52', N'رواتب وأجور', 'Salaries & Wages', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '522', '52', N'تأمينات اجتماعية (حصة المنشأة)', 'Employer Social Security', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '523', '52', N'إيجار', 'Rent Expense', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '524', '52', N'كهرباء وماء واتصالات', 'Utilities', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '525', '52', N'صيانة', 'Maintenance', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '526', '52', N'اهتلاك أصول ثابتة', 'Depreciation', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '527', '52', N'مصروفات إدارية وعمومية', 'G&A Expenses', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '53', '5', N'مصروفات تمويلية وضريبية', 'Finance & Tax Expenses', 'EXPENSE', 'DEBIT', 2, 1, 'OTHER_EXPENSES'),
(@CompanyID, '531', '53', N'فوائد مدينة', 'Interest Expense', 'EXPENSE', 'DEBIT', 3, 0, 'OTHER_EXPENSES'),
(@CompanyID, '532', '53', N'ضريبة دخل', 'Income Tax Expense', 'EXPENSE', 'DEBIT', 3, 0, 'OTHER_EXPENSES');

PRINT N'Syria COA seeded.';
GO
