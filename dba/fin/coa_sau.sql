-- ═══════════════════════════════════════════════════════════════════════════
-- ShouTech ERP — Chart of Accounts: SAUDI ARABIA (المملكة العربية السعودية)
-- Currency: SAR | ZATCA VAT 15% | GOSI | Zakat
-- Aligned with SOCPA / IFRS practice for SMEs & trading companies
-- ═══════════════════════════════════════════════════════════════════════════
SET NOCOUNT ON;
DECLARE @CompanyID NVARCHAR(50) = N'$(CompanyID)';

INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '1', NULL, N'الأصول', 'Assets', 'ASSET', 'DEBIT', 1, 1, 'ASSETS'),
(@CompanyID, '2', NULL, N'الالتزامات', 'Liabilities', 'LIABILITY', 'CREDIT', 1, 1, 'LIABILITIES'),
(@CompanyID, '3', NULL, N'حقوق الملكية', 'Equity', 'EQUITY', 'CREDIT', 1, 1, 'EQUITY'),
(@CompanyID, '4', NULL, N'الإيرادات', 'Revenue', 'REVENUE', 'CREDIT', 1, 1, 'REVENUE'),
(@CompanyID, '5', NULL, N'المصروفات', 'Expenses', 'EXPENSE', 'DEBIT', 1, 1, 'EXPENSES');

-- Assets
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '11', '1', N'الأصول المتداولة', 'Current Assets', 'ASSET', 'DEBIT', 2, 1, 'CURRENT_ASSETS'),
(@CompanyID, '111', '11', N'النقد وما في حكمه', 'Cash & Cash Equivalents', 'ASSET', 'DEBIT', 3, 1, 'CURRENT_ASSETS'),
(@CompanyID, '1111', '111', N'الصندوق', 'Petty Cash / Cash on Hand', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1112', '111', N'البنوك - حسابات جارية', 'Banks - Current Accounts', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1113', '111', N'البنوك - ودائع قصيرة الأجل', 'Short-term Deposits', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '112', '11', N'الذمم المدينة التجارية', 'Trade Receivables', 'ASSET', 'DEBIT', 3, 1, 'CURRENT_ASSETS'),
(@CompanyID, '1121', '112', N'العملاء', 'Customers', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1122', '112', N'أوراق القبض', 'Notes Receivable', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1123', '112', N'مخصص خسائر ائتمانية متوقعة', 'ECL Allowance', 'ASSET', 'CREDIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '113', '11', N'المخزون', 'Inventory', 'ASSET', 'DEBIT', 3, 1, 'CURRENT_ASSETS'),
(@CompanyID, '1131', '113', N'بضاعة بغرض البيع', 'Merchandise Inventory', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '1132', '113', N'مواد ومستلزمات', 'Supplies', 'ASSET', 'DEBIT', 4, 0, 'CURRENT_ASSETS'),
(@CompanyID, '114', '11', N'ضريبة القيمة المضافة - مدينة (مدخلات)', 'VAT Input (Recoverable)', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '115', '11', N'مصروفات مدفوعة مقدماً', 'Prepaid Expenses', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '116', '11', N'عهد وسلف موظفين', 'Employee Advances', 'ASSET', 'DEBIT', 3, 0, 'CURRENT_ASSETS'),
(@CompanyID, '12', '1', N'الأصول غير المتداولة', 'Non-Current Assets', 'ASSET', 'DEBIT', 2, 1, 'NON_CURRENT_ASSETS'),
(@CompanyID, '121', '12', N'العقارات والآلات والمعدات', 'Property, Plant & Equipment', 'ASSET', 'DEBIT', 3, 1, 'NON_CURRENT_ASSETS'),
(@CompanyID, '1211', '121', N'أراضي', 'Land', 'ASSET', 'DEBIT', 4, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '1212', '121', N'مباني', 'Buildings', 'ASSET', 'DEBIT', 4, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '1213', '121', N'آلات ومعدات', 'Machinery & Equipment', 'ASSET', 'DEBIT', 4, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '1214', '121', N'سيارات', 'Vehicles', 'ASSET', 'DEBIT', 4, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '1215', '121', N'أثاث وتجهيزات مكتبية', 'Furniture & Office Equipment', 'ASSET', 'DEBIT', 4, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '122', '12', N'مجمع الاستهلاك', 'Accumulated Depreciation', 'ASSET', 'CREDIT', 3, 0, 'NON_CURRENT_ASSETS'),
(@CompanyID, '123', '12', N'أصول غير ملموسة', 'Intangible Assets', 'ASSET', 'DEBIT', 3, 0, 'NON_CURRENT_ASSETS');

-- Liabilities
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '21', '2', N'الالتزامات المتداولة', 'Current Liabilities', 'LIABILITY', 'CREDIT', 2, 1, 'CURRENT_LIABILITIES'),
(@CompanyID, '211', '21', N'الموردون', 'Trade Payables', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '212', '21', N'أوراق الدفع', 'Notes Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '213', '21', N'ضريبة القيمة المضافة - دائنة (مخرجات)', 'VAT Output Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '214', '21', N'صافي ضريبة القيمة المضافة المستحق', 'Net VAT Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '215', '21', N'الزكاة الشرعية المستحقة', 'Zakat Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '216', '21', N'التأمينات الاجتماعية (GOSI) مستحقة', 'GOSI Payable', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '217', '21', N'رواتب ومكافآت مستحقة', 'Accrued Salaries', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '218', '21', N'قروض قصيرة الأجل', 'Short-term Borrowings', 'LIABILITY', 'CREDIT', 3, 0, 'CURRENT_LIABILITIES'),
(@CompanyID, '22', '2', N'الالتزامات غير المتداولة', 'Non-Current Liabilities', 'LIABILITY', 'CREDIT', 2, 1, 'NON_CURRENT_LIABILITIES'),
(@CompanyID, '221', '22', N'قروض طويلة الأجل', 'Long-term Loans', 'LIABILITY', 'CREDIT', 3, 0, 'NON_CURRENT_LIABILITIES'),
(@CompanyID, '222', '22', N'التزامات منافع الموظفين', 'Employee Benefit Obligations', 'LIABILITY', 'CREDIT', 3, 0, 'NON_CURRENT_LIABILITIES');

-- Equity
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '31', '3', N'رأس المال', 'Share Capital', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '32', '3', N'الاحتياطي النظامي', 'Statutory Reserve', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '33', '3', N'أرباح مبقاة', 'Retained Earnings', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY'),
(@CompanyID, '34', '3', N'صافي ربح / خسارة الفترة', 'Current Period P/L', 'EQUITY', 'CREDIT', 2, 0, 'EQUITY');

-- Revenue
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '41', '4', N'إيرادات النشاط', 'Operating Revenue', 'REVENUE', 'CREDIT', 2, 1, 'OPERATING_REVENUE'),
(@CompanyID, '411', '41', N'مبيعات محلية خاضعة لضريبة القيمة المضافة', 'Local VAT-taxable Sales', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '412', '41', N'مبيعات تصدير (صفرية)', 'Zero-rated Export Sales', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '413', '41', N'مبيعات معفاة', 'Exempt Sales', 'REVENUE', 'CREDIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '414', '41', N'مردودات المبيعات', 'Sales Returns', 'REVENUE', 'DEBIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '415', '41', N'خصم مسموح به', 'Sales Discounts', 'REVENUE', 'DEBIT', 3, 0, 'OPERATING_REVENUE'),
(@CompanyID, '42', '4', N'إيرادات أخرى', 'Other Income', 'REVENUE', 'CREDIT', 2, 0, 'OTHER_INCOME');

-- Expenses
INSERT INTO dbo.ChartOfAccounts (CompanyID, AccountCode, ParentAccountCode, AccountNameAR, AccountNameEN, AccountType, AccountNature, AccountLevel, IsHeader, FinancialStatementCategory) VALUES
(@CompanyID, '51', '5', N'تكلفة الإيرادات', 'Cost of Revenue', 'EXPENSE', 'DEBIT', 2, 1, 'COGS'),
(@CompanyID, '511', '51', N'تكلفة البضاعة المباعة', 'Cost of Goods Sold', 'EXPENSE', 'DEBIT', 3, 0, 'COGS'),
(@CompanyID, '52', '5', N'مصروفات البيع والتوزيع', 'Selling & Distribution', 'EXPENSE', 'DEBIT', 2, 1, 'OPERATING_EXPENSES'),
(@CompanyID, '521', '52', N'رواتب المبيعات', 'Sales Salaries', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '522', '52', N'عمولات بيع', 'Sales Commissions', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '523', '52', N'دعاية وإعلان', 'Advertising', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '53', '5', N'المصروفات العمومية والإدارية', 'General & Administrative', 'EXPENSE', 'DEBIT', 2, 1, 'OPERATING_EXPENSES'),
(@CompanyID, '531', '53', N'رواتب إدارية', 'Admin Salaries', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '532', '53', N'اشتراكات التأمينات (حصة المنشأة GOSI)', 'GOSI Employer Share', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '533', '53', N'إيجار', 'Rent', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '534', '53', N'كهرباء ومياه واتصالات', 'Utilities', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '535', '53', N'استهلاك الأصول', 'Depreciation', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '536', '53', N'أتعاب مهنية واستشارات', 'Professional Fees', 'EXPENSE', 'DEBIT', 3, 0, 'OPERATING_EXPENSES'),
(@CompanyID, '54', '5', N'الزكاة والضرائب', 'Zakat & Tax', 'EXPENSE', 'DEBIT', 2, 1, 'OTHER_EXPENSES'),
(@CompanyID, '541', '54', N'مصروف الزكاة', 'Zakat Expense', 'EXPENSE', 'DEBIT', 3, 0, 'OTHER_EXPENSES'),
(@CompanyID, '542', '54', N'مصروف ضريبة الدخل (إن وجدت)', 'Income Tax Expense', 'EXPENSE', 'DEBIT', 3, 0, 'OTHER_EXPENSES');

PRINT N'Saudi Arabia COA seeded.';
GO
