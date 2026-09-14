// ============================================================================
// FILE: Services/Security/PermissionCatalog.cs
// PROJECT: SHOUTECH ERP
// PURPOSE:
//     Central enterprise permission catalog.
//
// DESIGN:
//     MODULE.RESOURCE.ACTION
//
// SECURITY:
//     Permission keys are stable public contracts.
//     Do NOT rename released keys without a migration strategy.
// ============================================================================

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;

namespace ShouTech.App.Services.Security
{
    /// <summary>
    /// Central catalog of all application permissions.
    ///
    /// Permission format:
    ///
    ///     MODULE.RESOURCE.ACTION
    ///
    /// Example:
    ///
    ///     SALES.INVOICE.POST
    /// </summary>
    public static class PermCat
    {
        // =====================================================================
        // SYSTEM
        // =====================================================================

        public static class System
        {
            public const string Admin = "SYS.ADMIN";

            public const string SettingsView = "SYS.SETTINGS.VIEW";
            public const string SettingsUpdate = "SYS.SETTINGS.UPDATE";

            public const string UsersView = "SYS.USERS.VIEW";
            public const string UsersCreate = "SYS.USERS.CREATE";
            public const string UsersUpdate = "SYS.USERS.UPDATE";
            public const string UsersDisable = "SYS.USERS.DISABLE";
            public const string UsersDelete = "SYS.USERS.DELETE";

            public const string RolesView = "SYS.ROLES.VIEW";
            public const string RolesCreate = "SYS.ROLES.CREATE";
            public const string RolesUpdate = "SYS.ROLES.UPDATE";
            public const string RolesDelete = "SYS.ROLES.DELETE";

            public const string PermissionsView = "SYS.PERMISSIONS.VIEW";
            public const string PermissionTemplatesManage =
                "SYS.PERMISSION_TEMPLATES.MANAGE";

            public const string Maintenance = "SYS.MAINTENANCE";
            public const string PluginsManage = "SYS.PLUGINS.MANAGE";
        }

        // =====================================================================
        // COMPANY / ORGANIZATION
        // =====================================================================

        public static class Company
        {
            public const string View = "ORG.COMPANY.VIEW";
            public const string Create = "ORG.COMPANY.CREATE";
            public const string Update = "ORG.COMPANY.UPDATE";
            public const string Delete = "ORG.COMPANY.DELETE";

            public const string BranchView = "ORG.BRANCH.VIEW";
            public const string BranchCreate = "ORG.BRANCH.CREATE";
            public const string BranchUpdate = "ORG.BRANCH.UPDATE";
            public const string BranchDelete = "ORG.BRANCH.DELETE";

            public const string WarehouseView = "ORG.WAREHOUSE.VIEW";
            public const string WarehouseCreate = "ORG.WAREHOUSE.CREATE";
            public const string WarehouseUpdate = "ORG.WAREHOUSE.UPDATE";
            public const string WarehouseDelete = "ORG.WAREHOUSE.DELETE";
        }

        // =====================================================================
        // INVENTORY
        // =====================================================================

        public static class Inventory
        {
            public const string ItemView = "INV.ITEM.VIEW";
            public const string ItemCreate = "INV.ITEM.CREATE";
            public const string ItemUpdate = "INV.ITEM.UPDATE";
            public const string ItemDelete = "INV.ITEM.DELETE";

            public const string CategoryView = "INV.CATEGORY.VIEW";
            public const string CategoryCreate = "INV.CATEGORY.CREATE";
            public const string CategoryUpdate = "INV.CATEGORY.UPDATE";
            public const string CategoryDelete = "INV.CATEGORY.DELETE";

            public const string WarehouseView = "INV.WAREHOUSE.VIEW";
            public const string WarehouseCreate = "INV.WAREHOUSE.CREATE";
            public const string WarehouseUpdate = "INV.WAREHOUSE.UPDATE";
            public const string WarehouseDelete = "INV.WAREHOUSE.DELETE";

            public const string StockView = "INV.STOCK.VIEW";
            public const string StockTransfer = "INV.STOCK.TRANSFER";
            public const string StockAdjust = "INV.STOCK.ADJUST";
            public const string StockCount = "INV.STOCK.COUNT";
            public const string StockPost = "INV.STOCK.POST";

            public const string BarcodeView = "INV.BARCODE.VIEW";
            public const string BarcodeGenerate = "INV.BARCODE.GENERATE";
            public const string BarcodeDesign = "INV.BARCODE.DESIGN";
            public const string BarcodePrint = "INV.BARCODE.PRINT";

            public const string PriceListView = "INV.PRICELIST.VIEW";
            public const string PriceListCreate = "INV.PRICELIST.CREATE";
            public const string PriceListUpdate = "INV.PRICELIST.UPDATE";

            public const string SerialView = "INV.SERIAL.VIEW";
            public const string SerialUpdate = "INV.SERIAL.UPDATE";

            public const string ExpiryView = "INV.EXPIRY.VIEW";

            public const string ItemDiscountView = "INV.DISCOUNT.VIEW";
            public const string ItemDiscountManage = "INV.DISCOUNT.MANAGE";
        }

        // =====================================================================
        // ACCOUNTING
        // =====================================================================

        public static class Accounting
        {
            public const string AccountView = "ACC.ACCOUNT.VIEW";
            public const string AccountCreate = "ACC.ACCOUNT.CREATE";
            public const string AccountUpdate = "ACC.ACCOUNT.UPDATE";
            public const string AccountDelete = "ACC.ACCOUNT.DELETE";

            public const string JournalView = "ACC.JOURNAL.VIEW";
            public const string JournalCreate = "ACC.JOURNAL.CREATE";
            public const string JournalUpdate = "ACC.JOURNAL.UPDATE";
            public const string JournalPost = "ACC.JOURNAL.POST";
            public const string JournalReverse = "ACC.JOURNAL.REVERSE";

            public const string LedgerView = "ACC.LEDGER.VIEW";

            public const string CustomerLedgerView =
                "ACC.CUSTOMER_LEDGER.VIEW";

            public const string CostCenterView = "ACC.COSTCENTER.VIEW";
            public const string CostCenterManage = "ACC.COSTCENTER.MANAGE";

            public const string CurrencyView = "ACC.CURRENCY.VIEW";
            public const string CurrencyManage = "ACC.CURRENCY.MANAGE";

            public const string ExchangeRateView = "ACC.EXCHANGE_RATE.VIEW";
            public const string ExchangeRateManage = "ACC.EXCHANGE_RATE.MANAGE";

            public const string TrialBalanceView = "ACC.TRIAL_BALANCE.VIEW";

            public const string FinancialStatementsView =
                "ACC.FINANCIAL_STATEMENTS.VIEW";

            public const string FinancialAnalysisView =
                "ACC.FINANCIAL_ANALYSIS.VIEW";

            public const string FinancialAnalysisAi =
                "ACC.FINANCIAL_ANALYSIS.AI";
        }

        // =====================================================================
        // VOUCHERS
        // =====================================================================

        public static class Vouchers
        {
            public const string View = "VCH.VOUCHER.VIEW";
            public const string Create = "VCH.VOUCHER.CREATE";
            public const string Update = "VCH.VOUCHER.UPDATE";
            public const string Delete = "VCH.VOUCHER.DELETE";
            public const string Post = "VCH.VOUCHER.POST";
            public const string Reverse = "VCH.VOUCHER.REVERSE";

            public const string ReceiptCreate = "VCH.RECEIPT.CREATE";
            public const string PaymentCreate = "VCH.PAYMENT.CREATE";

            public const string SecuritiesView = "VCH.SECURITY.VIEW";
            public const string SecuritiesManage = "VCH.SECURITY.MANAGE";

            public const string InstallmentView = "VCH.INSTALLMENT.VIEW";
            public const string InstallmentManage = "VCH.INSTALLMENT.MANAGE";

            public const string PaymentMethodManage =
                "VCH.PAYMENT_METHOD.MANAGE";
        }

        // =====================================================================
        // SALES
        // =====================================================================

        public static class Sales
        {
            public const string InvoiceView = "SALES.INVOICE.VIEW";
            public const string InvoiceCreate = "SALES.INVOICE.CREATE";
            public const string InvoiceUpdate = "SALES.INVOICE.UPDATE";
            public const string InvoiceDelete = "SALES.INVOICE.DELETE";
            public const string InvoicePost = "SALES.INVOICE.POST";
            public const string InvoiceReverse = "SALES.INVOICE.REVERSE";

            public const string ReturnView = "SALES.RETURN.VIEW";
            public const string ReturnCreate = "SALES.RETURN.CREATE";
            public const string ReturnPost = "SALES.RETURN.POST";

            public const string QuotationView = "SALES.QUOTATION.VIEW";
            public const string QuotationCreate = "SALES.QUOTATION.CREATE";
            public const string QuotationUpdate = "SALES.QUOTATION.UPDATE";
            public const string QuotationDelete = "SALES.QUOTATION.DELETE";
            public const string QuotationConvert = "SALES.QUOTATION.CONVERT";

            public const string OrderView = "SALES.ORDER.VIEW";
            public const string OrderCreate = "SALES.ORDER.CREATE";
            public const string OrderUpdate = "SALES.ORDER.UPDATE";
            public const string OrderCancel = "SALES.ORDER.CANCEL";

            public const string CashInvoiceCreate = "SALES.CASH.CREATE";
            public const string PriceOverride = "SALES.PRICE.OVERRIDE";

            public const string DiscountOverride = "SALES.DISCOUNT.OVERRIDE";

            public const string InvoiceRepost = "SALES.INVOICE.REPOST";

            public const string ReportsView = "SALES.REPORTS.VIEW";
        }

        // =====================================================================
        // PURCHASING
        // =====================================================================

        public static class Purchasing
        {
            public const string InvoiceView = "PURCH.INVOICE.VIEW";
            public const string InvoiceCreate = "PURCH.INVOICE.CREATE";
            public const string InvoiceUpdate = "PURCH.INVOICE.UPDATE";
            public const string InvoiceDelete = "PURCH.INVOICE.DELETE";
            public const string InvoicePost = "PURCH.INVOICE.POST";

            public const string ReturnView = "PURCH.RETURN.VIEW";
            public const string ReturnCreate = "PURCH.RETURN.CREATE";
            public const string ReturnPost = "PURCH.RETURN.POST";

            public const string OrderView = "PURCH.ORDER.VIEW";
            public const string OrderCreate = "PURCH.ORDER.CREATE";
            public const string OrderUpdate = "PURCH.ORDER.UPDATE";
            public const string OrderCancel = "PURCH.ORDER.CANCEL";

            public const string ReportsView = "PURCH.REPORTS.VIEW";
        }

        // =====================================================================
        // POS
        // =====================================================================

        public static class Pos
        {
            public const string TerminalView = "POS.TERMINAL.VIEW";
            public const string TerminalManage = "POS.TERMINAL.MANAGE";

            public const string SessionOpen = "POS.SESSION.OPEN";
            public const string SessionClose = "POS.SESSION.CLOSE";
            public const string SessionReopen = "POS.SESSION.REOPEN";

            public const string InvoiceCreate = "POS.INVOICE.CREATE";
            public const string InvoiceDelete = "POS.INVOICE.DELETE";
            public const string InvoiceRefund = "POS.INVOICE.REFUND";

            public const string PriceOverride = "POS.PRICE.OVERRIDE";
            public const string QuantityOverride = "POS.QUANTITY.OVERRIDE";
            public const string ItemDelete = "POS.ITEM.DELETE";

            public const string DiscountManage = "POS.DISCOUNT.MANAGE";

            public const string SyncExecute = "POS.SYNC.EXECUTE";
            public const string ReportsView = "POS.REPORTS.VIEW";
        }

        // =====================================================================
        // CRM / CUSTOMERS
        // =====================================================================

        public static class Customers
        {
            public const string View = "CRM.CUSTOMER.VIEW";
            public const string Create = "CRM.CUSTOMER.CREATE";
            public const string Update = "CRM.CUSTOMER.UPDATE";
            public const string Delete = "CRM.CUSTOMER.DELETE";

            public const string PricingView = "CRM.CUSTOMER_PRICING.VIEW";
            public const string PricingManage = "CRM.CUSTOMER_PRICING.MANAGE";

            public const string DiscountView = "CRM.CUSTOMER_DISCOUNT.VIEW";
            public const string DiscountManage = "CRM.CUSTOMER_DISCOUNT.MANAGE";

            public const string BalanceView = "CRM.CUSTOMER_BALANCE.VIEW";
            public const string ReceivableView = "CRM.RECEIVABLE.VIEW";
            public const string ReceivableManage = "CRM.RECEIVABLE.MANAGE";

            public const string TargetView = "CRM.CUSTOMER_TARGET.VIEW";
            public const string TargetManage = "CRM.CUSTOMER_TARGET.MANAGE";

            public const string ReportsView = "CRM.CUSTOMER_REPORTS.VIEW";
        }

        // =====================================================================
        // REPRESENTATIVES
        // =====================================================================

        public static class Representatives
        {
            public const string View = "REP.REPRESENTATIVE.VIEW";
            public const string Create = "REP.REPRESENTATIVE.CREATE";
            public const string Update = "REP.REPRESENTATIVE.UPDATE";
            public const string Delete = "REP.REPRESENTATIVE.DELETE";

            public const string TargetView = "REP.TARGET.VIEW";
            public const string TargetManage = "REP.TARGET.MANAGE";

            public const string CollectionView = "REP.COLLECTION.VIEW";
            public const string CollectionManage = "REP.COLLECTION.MANAGE";

            public const string DeviceView = "REP.DEVICE.VIEW";
            public const string DeviceManage = "REP.DEVICE.MANAGE";

            public const string RouteView = "REP.ROUTE.VIEW";
            public const string RouteManage = "REP.ROUTE.MANAGE";
        }

        // =====================================================================
        // MANUFACTURING
        // =====================================================================

        public static class Manufacturing
        {
            public const string BomView = "MFG.BOM.VIEW";
            public const string BomManage = "MFG.BOM.MANAGE";

            public const string OrderView = "MFG.ORDER.VIEW";
            public const string OrderCreate = "MFG.ORDER.CREATE";
            public const string OrderUpdate = "MFG.ORDER.UPDATE";
            public const string OrderCancel = "MFG.ORDER.CANCEL";

            public const string ProductionView = "MFG.PRODUCTION.VIEW";
            public const string ProductionExecute = "MFG.PRODUCTION.EXECUTE";
            public const string ProductionPost = "MFG.PRODUCTION.POST";
            public const string ProductionRepost = "MFG.PRODUCTION.REPOST";

            public const string CostView = "MFG.COST.VIEW";
            public const string VarianceView = "MFG.VARIANCE.VIEW";

            public const string ReportsView = "MFG.REPORTS.VIEW";
        }

        // =====================================================================
        // BANKING
        // =====================================================================

        public static class Banking
        {
            public const string BankView = "BANK.BANK.VIEW";
            public const string BankManage = "BANK.BANK.MANAGE";

            public const string AccountView = "BANK.ACCOUNT.VIEW";
            public const string AccountManage = "BANK.ACCOUNT.MANAGE";

            public const string ReconciliationView =
                "BANK.RECONCILIATION.VIEW";

            public const string ReconciliationExecute =
                "BANK.RECONCILIATION.EXECUTE";

            public const string BalanceView = "BANK.BALANCE.VIEW";
            public const string ForecastView = "BANK.FORECAST.VIEW";
        }

        // =====================================================================
        // DELIVERY
        // =====================================================================

        public static class Delivery
        {
            public const string DriverView = "DELIVERY.DRIVER.VIEW";
            public const string DriverManage = "DELIVERY.DRIVER.MANAGE";

            public const string OrderView = "DELIVERY.ORDER.VIEW";
            public const string OrderCreate = "DELIVERY.ORDER.CREATE";
            public const string OrderUpdate = "DELIVERY.ORDER.UPDATE";
            public const string OrderCancel = "DELIVERY.ORDER.CANCEL";

            public const string PricingView = "DELIVERY.PRICING.VIEW";
            public const string PricingManage = "DELIVERY.PRICING.MANAGE";

            public const string TrackingView = "DELIVERY.TRACKING.VIEW";

            public const string CashboxView = "DELIVERY.CASHBOX.VIEW";
            public const string CashboxClose = "DELIVERY.CASHBOX.CLOSE";
        }

        // =====================================================================
        // REPORTING
        // =====================================================================

        public static class Reporting
        {
            public const string View = "REPORT.VIEW";
            public const string Export = "REPORT.EXPORT";
            public const string Print = "REPORT.PRINT";

            public const string DesignerView = "REPORT.DESIGNER.VIEW";
            public const string DesignerManage = "REPORT.DESIGNER.MANAGE";

            public const string CustomView = "REPORT.CUSTOM.VIEW";
            public const string CustomManage = "REPORT.CUSTOM.MANAGE";

            public const string DashboardView = "REPORT.DASHBOARD.VIEW";
        }

        // =====================================================================
        // DATA
        // =====================================================================

        public static class Data
        {
            public const string Import = "DATA.IMPORT";
            public const string Export = "DATA.EXPORT";

            public const string PosImport = "DATA.POS.IMPORT";
            public const string PosExport = "DATA.POS.EXPORT";

            public const string CardImport = "DATA.CARD.IMPORT";

            public const string Validate = "DATA.VALIDATE";
        }

        // =====================================================================
        // BACKUP
        // =====================================================================

        public static class Backup
        {
            public const string View = "BACKUP.VIEW";
            public const string Create = "BACKUP.CREATE";
            public const string Restore = "BACKUP.RESTORE";
            public const string Verify = "BACKUP.VERIFY";
            public const string Delete = "BACKUP.DELETE";
            public const string Configure = "BACKUP.CONFIGURE";
        }

        // =====================================================================
        // AUDIT
        // =====================================================================

        public static class Audit
        {
            public const string View = "AUDIT.VIEW";
            public const string Export = "AUDIT.EXPORT";
            public const string SecurityEventsView =
                "AUDIT.SECURITY_EVENTS.VIEW";
        }

        // =====================================================================
        // LICENSING
        // =====================================================================

        public static class Licensing
        {
            public const string View = "LIC.LICENSE.VIEW";
            public const string Renew = "LIC.LICENSE.RENEW";
            public const string Activate = "LIC.LICENSE.ACTIVATE";
            public const string DeviceView = "LIC.DEVICE.VIEW";
            public const string DeviceManage = "LIC.DEVICE.MANAGE";
        }

        // =====================================================================
        // UPDATES
        // =====================================================================

        public static class Updates
        {
            public const string Check = "UPDATE.CHECK";
            public const string Install = "UPDATE.INSTALL";
            public const string ManualInstall = "UPDATE.MANUAL_INSTALL";
        }

        // =====================================================================
        // AI
        // =====================================================================

        public static class Ai
        {
            public const string Use = "AI.USE";
            public const string FinancialAnalysis =
                "AI.FINANCIAL_ANALYSIS";
            public const string InventoryAnalysis =
                "AI.INVENTORY_ANALYSIS";
            public const string SalesAnalysis =
                "AI.SALES_ANALYSIS";
            public const string Forecast =
                "AI.FORECAST";
            public const string Assistant =
                "AI.ASSISTANT";
        }

        // =====================================================================
        // SYSTEM HELP
        // =====================================================================

        public static class Help
        {
            public const string View = "HELP.VIEW";
            public const string Support = "HELP.SUPPORT";
            public const string Suggestions = "HELP.SUGGESTIONS";
            public const string About = "HELP.ABOUT";
        }

        // =====================================================================
        // CATALOG
        // =====================================================================

        private static readonly Lazy<ReadOnlyCollection<string>> _all =
            new(BuildCatalog);

        /// <summary>
        /// Returns every registered permission key.
        /// </summary>
        public static IReadOnlyCollection<string> All => _all.Value;

        /// <summary>
        /// Checks whether a permission key is registered.
        /// </summary>
        public static bool Contains(string? permissionKey)
        {
            if (string.IsNullOrWhiteSpace(permissionKey))
                return false;

            return _all.Value.Contains(
                permissionKey.Trim(),
                StringComparer.OrdinalIgnoreCase);
        }

        // =====================================================================
        // INTERNAL CATALOG BUILDER
        // =====================================================================

        private static ReadOnlyCollection<string> BuildCatalog()
        {
            var result = new HashSet<string>(
                StringComparer.OrdinalIgnoreCase);

            AddNestedConstants(typeof(System), result);
            AddNestedConstants(typeof(Company), result);
            AddNestedConstants(typeof(Inventory), result);
            AddNestedConstants(typeof(Accounting), result);
            AddNestedConstants(typeof(Vouchers), result);
            AddNestedConstants(typeof(Sales), result);
            AddNestedConstants(typeof(Purchasing), result);
            AddNestedConstants(typeof(Pos), result);
            AddNestedConstants(typeof(Customers), result);
            AddNestedConstants(typeof(Representatives), result);
            AddNestedConstants(typeof(Manufacturing), result);
            AddNestedConstants(typeof(Banking), result);
            AddNestedConstants(typeof(Delivery), result);
            AddNestedConstants(typeof(Reporting), result);
            AddNestedConstants(typeof(Data), result);
            AddNestedConstants(typeof(Backup), result);
            AddNestedConstants(typeof(Audit), result);
            AddNestedConstants(typeof(Licensing), result);
            AddNestedConstants(typeof(Updates), result);
            AddNestedConstants(typeof(Ai), result);
            AddNestedConstants(typeof(Help), result);

            return new ReadOnlyCollection<string>(
                result.OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
                      .ToList());
        }

        private static void AddNestedConstants(
            Type type,
            HashSet<string> target)
        {
            foreach (var field in type.GetFields(
                         global::System.Reflection.BindingFlags.Public |
                         global::System.Reflection.BindingFlags.Static |
                         global::System.Reflection.BindingFlags.FlattenHierarchy))
            {
                if (field.FieldType != typeof(string))
                    continue;

                if (!field.IsLiteral || field.IsInitOnly)
                    continue;

                if (field.GetRawConstantValue() is string value &&
                    !string.IsNullOrWhiteSpace(value))
                {
                    target.Add(value);
                }
            }
        }
    }
}