-- ═══════════════════════════════════════════════════════════════════════════
-- ShouTech ERP — Chart of Accounts: LEBANON (الجمهورية اللبنانية)
-- Currency: LBP (with multi-currency USD common practice)
-- VAT + NSSF (National Social Security Fund)
-- ═══════════════════════════════════════════════════════════════════════════
SET NOCOUNT ON;
DECLARE @CompanyID NVARCHAR(50) = N'$(CompanyID)';

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '1', NULL, N'الأصول', 'Assets', 'ASSET', 'DEBIT', 1, 1, 'ASSETS'),
(@CompanyID, '2', NULL, N'الخصوم', 'Liabilities', 'LIABILITY', 'CREDIT', 1, 1, 'LIABILITIES'),
(@CompanyID, '3', NULL, N'حقوق الملكية', 'Equity', 'EQUITY', 'CREDIT', 1, 1, 'EQUITY'),
(@CompanyID, '4', NULL, N'الإيرادات', 'Revenue', 'REVENUE', 'CREDIT', 1, 1, 'REVENUE'),
(@CompanyID, '5', NULL, N'المصروفات', 'Expenses', 'EXPENSE', 'DEBIT', 1, 1, 'EXPENSES');

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '11', '1', N'الأصول المتداولة', 'Current Assets', 'ASSET', 'DEBIT', 2, 1, 'CURRENT_ASSETS'),
(@CompanyID, '111', '11', N'الصناديق والبنوك', 'Cash & Banks', 'ASSET', 'DEBIT', 3, 1, 'CURRENT_ASSETS'),
(@CompanyID, '1111', '111', N'صندوق ليرة', 'Cash LBP', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1112', '111', N'صندوق دولار', 'Cash USD', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1113', '111', N'بنك - حساب ليرة', 'Bank LBP', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1114', '111', N'بنك - حساب دولار', 'Bank USD', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '112', '11', N'الذمم المدينة', 'Receivables', 'ASSET', 'DEBIT', 3, 1, 'CURRENT_ASSETS'),
(@CompanyID, '1121', '112', N'زبائن', 'Customers', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1122', '112', N'أوراق قبض', 'Notes Receivable', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '113', '11', N'المخزون', 'Inventory', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '114', '11', N'ضريبة قيمة مضافة قابلة للخصم', 'VAT Recoverable (Input)', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '115', '11', N'مصاريف مدفوعة مسبقاً', 'Prepaid Expenses', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '12', '1', N'الأصول الثابتة', 'Fixed Assets', 'ASSET', 'DEBIT', 2, 1, 'NON_CURRENT_ASSETS'),
(@CompanyID, '121', '12', N'أراضٍ ومبانٍ', 'Land & Buildings', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '122', '12', N'آليات وتجهيزات', 'Machinery & Equipment', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '123', '12', N'سيارات', 'Vehicles', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '124', '12', N'أثاث ومفروشات', 'Furniture', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '125', '12', N'مؤونة الاستهلاك', 'Accumulated Depreciation', 'ASSET', 'CREDIT', 3, 0, 'NON_CURRENT_ASSETS');

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '21', '2', N'الخصوم المتداولة', 'Current Liabilities', 'LIABILITY', 'CREDIT', 2, 1, 'CURRENT_LIABILITIES'),
(@CompanyID, '211', '21', N'موردون', 'Suppliers', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '212', '21', N'أوراق دفع', 'Notes Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '213', '21', N'ضريبة قيمة مضافة مستحقة', 'VAT Payable (Output)', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '214', '21', N'ضريبة على الأرباح مستحقة', 'Corporate Tax Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '215', '21', N'ضمان اجتماعي (NSSF) مستحق', 'NSSF Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '216', '21', N'رواتب مستحقة', 'Salaries Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '22', '2', N'قروض متوسطة وطويلة الأجل', 'Medium/Long-term Loans', 'LIABILITY', 'CREDIT', 2, 0, 'NON_CURRENT_LIABILITIES');

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '31', '3', N'رأس المال', 'Capital', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '32', '3', N'احتياطي قانوني', 'Legal Reserve', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '33', '3', N'أرباح مدورة', 'Retained Earnings', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '34', '3', N'نتيجة الدورة', 'Current Period Result', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY');

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '41', '4', N'المبيعات', 'Sales', 'REVENUE', 'CREDIT', 2, 1, 'OPERATING_REVENUE'),
(@CompanyID, '411', '41', N'مبيعات خاضعة للـ VAT', 'VAT-taxable Sales', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '412', '41', N'مبيعات معفاة', 'Exempt Sales', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '413', '41', N'مردودات مبيعات', 'Sales Returns', 'REVENUE', 'DEBIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '42', '4', N'إيرادات أخرى / فروقات عملة', 'Other Income / FX', 'REVENUE', 'CREDIT', 2, 0, 'OTHER_INCOME');

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '51', '5', N'كلفة المبيعات', 'Cost of Sales', 'EXPENSE', 'DEBIT', 2, 0, 'COGS'),
(@CompanyID, '52', '5', N'مصاريف التشغيل', 'Operating Expenses', 'EXPENSE', 'DEBIT', 2, 1, 'OPERATING_EXPENSES'),
(@CompanyID, '521', '52', N'رواتب وأجور', 'Salaries & Wages', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '522', '52', N'اشتراكات ضمان (NSSF)', 'NSSF Employer Contribution', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '523', '52', N'إيجار', 'Rent', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '524', '52', N'استهلاك أصول ثابتة', 'Depreciation', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '525', '52', N'مصاريف إدارية وعمومية', 'G&A', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '53', '5', N'ضريبة على الأرباح', 'Corporate Tax Expense', 'EXPENSE', 'DEBIT', 2, 0, 'OTHER_EXPENSES');

PRINT N'Lebanon COA seeded.';
GO
