-- ═══════════════════════════════════════════════════════════════════════════
-- ShouTech ERP — Chart of Accounts: GCC GENERAL (دول مجلس التعاون)
-- Covers: UAE, Kuwait, Bahrain, Oman, Qatar (+ reusable for KSA trading)
-- Currency: multi (AED/KWD/BHD/OMR/QAR) — set base currency per company
-- VAT: typically 5% (UAE/BH/OM/SA uses 15% — adjust tax accounts by country)
-- ═══════════════════════════════════════════════════════════════════════════
SET NOCOUNT ON;
DECLARE @CompanyID NVARCHAR(50) = N'$(CompanyID)';

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '1', NULL, N'الأصول', 'Assets', 'ASSET', 'DEBIT', 1, 1, 'ASSETS'),
(@CompanyID, '2', NULL, N'الالتزامات', 'Liabilities', 'LIABILITY', 'CREDIT', 1, 1, 'LIABILITIES'),
(@CompanyID, '3', NULL, N'حقوق الملكية', 'Equity', 'EQUITY', 'CREDIT', 1, 1, 'EQUITY'),
(@CompanyID, '4', NULL, N'الإيرادات', 'Revenue', 'REVENUE', 'CREDIT', 1, 1, 'REVENUE'),
(@CompanyID, '5', NULL, N'المصروفات', 'Expenses', 'EXPENSE', 'DEBIT', 1, 1, 'EXPENSES');

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '11', '1', N'الأصول المتداولة', 'Current Assets', 'ASSET', 'DEBIT', 2, 1, 'CURRENT_ASSETS'),
(@CompanyID, '111', '11', N'النقد والبنوك', 'Cash & Banks', 'ASSET', 'DEBIT', 3, 1, 'CURRENT_ASSETS'),
(@CompanyID, '1111', '111', N'صندوق', 'Cash', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1112', '111', N'بنوك محلية', 'Local Banks', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1113', '111', N'بنوك أجنبية / عملات', 'Foreign / FCY Banks', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '112', '11', N'الذمم المدينة', 'Receivables', 'ASSET', 'DEBIT', 3, 1, 'CURRENT_ASSETS'),
(@CompanyID, '1121', '112', N'عملاء محليون', 'Local Customers', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1122', '112', N'عملاء دول الخليج', 'GCC Customers', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1123', '112', N'عملاء دوليون', 'International Customers', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1124', '112', N'مخصص خسائر ائتمانية', 'Credit Loss Allowance', 'ASSET', 'CREDIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '113', '11', N'المخزون', 'Inventory', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '114', '11', N'ضريبة القيمة المضافة - مدخلات', 'VAT Input', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '115', '11', N'مصروفات مقدمة', 'Prepayments', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '12', '1', N'الأصول الثابتة', 'Fixed Assets', 'ASSET', 'DEBIT', 2, 1, 'NON_CURRENT_ASSETS'),
(@CompanyID, '121', '12', N'أراضي ومبانٍ', 'Land & Buildings', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '122', '12', N'معدات وآلات', 'Plant & Equipment', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '123', '12', N'مركبات', 'Vehicles', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '124', '12', N'أثاث وتقنية', 'Furniture & IT', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '125', '12', N'مجمع الاستهلاك', 'Accumulated Depreciation', 'ASSET', 'CREDIT', 3, 0, 'NON_CURRENT_ASSETS');

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '21', '2', N'الالتزامات المتداولة', 'Current Liabilities', 'LIABILITY', 'CREDIT', 2, 1, 'CURRENT_LIABILITIES'),
(@CompanyID, '211', '21', N'موردون', 'Trade Payables', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '212', '21', N'ضريبة قيمة مضافة - مخرجات', 'VAT Output', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '213', '21', N'صافي ضريبة مستحقة للهيئة', 'Net VAT Payable to Authority', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '214', '21', N'ضريبة دخل / شركات مستحقة', 'Corporate Tax Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '215', '21', N'تأمينات / ضمان اجتماعي مستحق', 'Social Insurance Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '216', '21', N'رواتب مستحقة', 'Accrued Payroll', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '217', '21', N'قروض قصيرة الأجل', 'Short-term Loans', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '22', '2', N'الالتزامات غير المتداولة', 'Non-Current Liabilities', 'LIABILITY', 'CREDIT', 2, 1, 'NON_CURRENT_LIABILITIES'),
(@CompanyID, '221', '22', N'قروض طويلة الأجل', 'Long-term Loans', 'LIABILITY', 'CREDIT', 3, 0, 'NON_CURRENT_LIABILITIES'),
(@CompanyID, '222', '22', N'مكافأة نهاية الخدمة', 'End-of-Service Benefits', 'LIABILITY', 'CREDIT', 3, 0, 'NON_CURRENT_LIABILITIES');

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '31', '3', N'رأس المال', 'Capital', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '32', '3', N'احتياطيات', 'Reserves', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '33', '3', N'أرباح محتجزة', 'Retained Earnings', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '34', '3', N'نتيجة الفترة', 'Period Result', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY');

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '41', '4', N'إيرادات المبيعات', 'Sales Revenue', 'REVENUE', 'CREDIT', 2, 1, 'OPERATING_REVENUE'),
(@CompanyID, '411', '41', N'مبيعات محلية خاضعة للضريبة', 'Domestic Taxable Sales', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '412', '41', N'مبيعات خليجية / بين دول الخليج', 'Intra-GCC Sales', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '413', '41', N'مبيعات تصدير (صفرية)', 'Zero-rated Exports', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '414', '41', N'مبيعات معفاة', 'Exempt Sales', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '415', '41', N'مردودات وخصومات', 'Returns & Discounts', 'REVENUE', 'DEBIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '42', '4', N'إيرادات أخرى', 'Other Income', 'REVENUE', 'CREDIT', 2, 0, 'OTHER_INCOME');

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '51', '5', N'تكلفة المبيعات', 'Cost of Sales', 'EXPENSE', 'DEBIT', 2, 0, 'COGS'),
(@CompanyID, '52', '5', N'مصروفات التشغيل', 'Operating Expenses', 'EXPENSE', 'DEBIT', 2, 1, 'OPERATING_EXPENSES'),
(@CompanyID, '521', '52', N'رواتب ومزايا', 'Salaries & Benefits', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '522', '52', N'تأمينات اجتماعية (حصة صاحب العمل)', 'Employer Social Insurance', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '523', '52', N'إيجار ومرافق', 'Rent & Utilities', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '524', '52', N'استهلاك', 'Depreciation', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '525', '52', N'مصروفات إدارية وعمومية', 'G&A Expenses', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '53', '5', N'ضرائب', 'Tax Expenses', 'EXPENSE', 'DEBIT', 2, 1, 'OTHER_EXPENSES'),
(@CompanyID, '531', '53', N'ضريبة شركات / دخل', 'Corporate Tax Expense', 'EXPENSE', 'DEBIT', 3, 0, 'OTHER_EXPENSES');

PRINT N'GCC General COA seeded.';
GO
