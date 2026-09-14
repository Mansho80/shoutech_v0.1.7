// ========================================================================
// FILE: ViewModels/MainWnVM.cs
// PROJECT: SHOUTECH ERP V10
// PURPOSE: Main Enterprise ViewModel
// STATUS: Stable - No Mock Services
// ========================================================================

using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using CommunityToolkit.Mvvm.Input;
using ShouTech.App.Common;
using ShouTech.App.Services;

namespace ShouTech.App.ViewModels
{
    /// <summary>
    /// Main application ViewModel.
    ///
    /// Design rules:
    /// - No Mock services.
    /// - No service construction inside the ViewModel.
    /// - Navigation is delegated to INavServ.
    /// - Existing command names are preserved for XAML compatibility.
    /// </summary>
    public sealed class MainWnVM : BaseVM, IDisposable
    {
        // ====================================================================
        // CORE SERVICES
        // ====================================================================

        private readonly IAuthSvc _authService;
        private readonly IDataServ _dataService;
        private readonly IPermServ _permissionService;
        private readonly ILocSvc _localizationService;
        private readonly IThmServ _themeService;
        private readonly IBkpServ _backupService;
        private readonly INavServ _navigationService;
        private readonly ILogServ _loggingService;

        // ====================================================================
        // STATE
        // ====================================================================

        private string _windowTitle = "شو تيك ERP V10 - نظام متكامل";
        private string _currentUser = "جاري التحميل...";
        private string _currentRole = "مدير";
        private string _statusMessage = "مرحباً بك في شو تيك ERP V10";
        private string _currentDateTime = AppFormat.FormatDateTime(DateTime.Now);
        private string _currentDate = AppFormat.FormatDate(DateTime.Now);
        private string _currentTime = AppFormat.FormatTime(DateTime.Now);
        private string _currentLanguageDisplay = "🇬🇧 English";

        private string _dbConnectionStatusText = "متصل";
        private Brush _dbConnectionStatusColor = Brushes.LimeGreen;

        private bool _isDkTheme;
        private int _totalCustomers;
        private int _totalProducts;
        private int _pendingApprovals;
        private int _unreadNotifications;

        private object? _currentContent;
        private object? _contentToolbar;

        private readonly ObservableCollection<RecentDocument> _recentDocuments = new();

        private bool _disposed;

        // ====================================================================
        // PROPERTIES
        // ====================================================================

        public string WindowTitle
        {
            get => _windowTitle;
            set => SetProperty(ref _windowTitle, value);
        }

        public string CurrentUser
        {
            get => _currentUser;
            set => SetProperty(ref _currentUser, value);
        }

        public string CurrentRole
        {
            get => _currentRole;
            set => SetProperty(ref _currentRole, value);
        }

        public string StatusMessage
        {
            get => _statusMessage;
            set => SetProperty(ref _statusMessage, value);
        }

        public string CurrentDateTime
        {
            get => _currentDateTime;
            set => SetProperty(ref _currentDateTime, value);
        }

        public string CurrentDate
        {
            get => _currentDate;
            set => SetProperty(ref _currentDate, value);
        }

        public string CurrentTime
        {
            get => _currentTime;
            set => SetProperty(ref _currentTime, value);
        }

        public string CurrentLanguageDisplay
        {
            get => _currentLanguageDisplay;
            set => SetProperty(ref _currentLanguageDisplay, value);
        }

        public string DbConnectionStatusText
        {
            get => _dbConnectionStatusText;
            set => SetProperty(ref _dbConnectionStatusText, value);
        }

        public Brush DbConnectionStatusColor
        {
            get => _dbConnectionStatusColor;
            set => SetProperty(ref _dbConnectionStatusColor, value);
        }

        public bool IsDkTheme
        {
            get => _isDkTheme;
            set
            {
                if (SetProperty(ref _isDkTheme, value))
                {
                    try
                    {
                        _themeService.SetTheme(value);
                    }
                    catch (Exception ex)
                    {
                        _loggingService.LogError(
                            "Theme",
                            "Failed to change theme.",
                            ex);
                    }
                }
            }
        }

        public int TotalCustomers
        {
            get => _totalCustomers;
            set => SetProperty(ref _totalCustomers, value);
        }

        public int TotalProducts
        {
            get => _totalProducts;
            set => SetProperty(ref _totalProducts, value);
        }

        public int PendingApprovals
        {
            get => _pendingApprovals;
            set => SetProperty(ref _pendingApprovals, value);
        }

        public int UnreadNotifications
        {
            get => _unreadNotifications;
            set => SetProperty(ref _unreadNotifications, value);
        }

        public object? CurrentContent
        {
            get => _currentContent;
            set => SetProperty(ref _currentContent, value);
        }

        public object? ContentToolbar
        {
            get => _contentToolbar;
            set => SetProperty(ref _contentToolbar, value);
        }

        public ObservableCollection<RecentDocument> RecentDocuments =>
            _recentDocuments;

        // ====================================================================
        // COMMANDS
        // ====================================================================

        public ICommand NewCommand { get; }
        public ICommand OpenCommand { get; }
        public ICommand SaveCommand { get; }
        public ICommand SaveAllCommand { get; }
        public ICommand PrintPreviewCommand { get; }
        public ICommand PrintCommand { get; }
        public ICommand ExportDataCommand { get; }
        public ICommand ImportDataCommand { get; }
        public ICommand ExitCommand { get; }

        public ICommand UndoCommand { get; }
        public ICommand RedoCommand { get; }
        public ICommand CutCommand { get; }
        public ICommand CopyCommand { get; }
        public ICommand PasteCommand { get; }
        public ICommand DeleteCommand { get; }
        public ICommand FindCommand { get; }
        public ICommand ReplaceCommand { get; }
        public ICommand SelectAllCommand { get; }

        public ICommand DashVwCommand { get; }
        public ICommand FullScreenCommand { get; }
        public ICommand ZoomInCommand { get; }
        public ICommand ZoomOutCommand { get; }
        public ICommand RefreshCommand { get; }

        // Inventory
        public ICommand ProductListCommand { get; }
        public ICommand AddProductCommand { get; }
        public ICommand EditProductCommand { get; }
        public ICommand DeleteProductCommand { get; }
        public ICommand CategoriesCommand { get; }
        public ICommand WarehouseListCommand { get; }
        public ICommand StockMovementHistoryCommand { get; }
        public ICommand AdjustStockCommand { get; }
        public ICommand StockTransferCommand { get; }
        public ICommand InventoryCountCommand { get; }
        public ICommand GenerateBarcodeCommand { get; }
        public ICommand PriceListCommand { get; }
        public ICommand InventoryValuationCommand { get; }
        public ICommand SlowMovingItemsCommand { get; }
        public ICommand TopSellingItemsCommand { get; }
        public ICommand ExpiredItemsCommand { get; }
        public ICommand InventoryAnalysisCommand { get; }
        public ICommand InventoryForecastCommand { get; }
        public ICommand InventoryDashboardCommand { get; }

        // Sales
        public ICommand InvoicesListCommand { get; }
        public ICommand AddInvoiceCommand { get; }
        public ICommand EditInvoiceCommand { get; }
        public ICommand DeleteInvoiceCommand { get; }
        public ICommand InvoiceDetailsCommand { get; }
        public ICommand ProcessPaymentCommand { get; }
        public ICommand InvoicePrintCommand { get; }
        public ICommand InvoiceEmailCommand { get; }
        public ICommand CustomersListCommand { get; }
        public ICommand AddCustomerCommand { get; }
        public ICommand EditCustomerCommand { get; }
        public ICommand DeleteCustomerCommand { get; }
        public ICommand CustomerGroupsCommand { get; }
        public ICommand CustomerPriceListCommand { get; }
        public ICommand CustomerDiscountsCommand { get; }
        public ICommand CustomerStatementsCommand { get; }
        public ICommand CustomerBalanceReportCommand { get; }
        public ICommand SalesOrderListCommand { get; }
        public ICommand AddSalesOrderCommand { get; }
        public ICommand EditSalesOrderCommand { get; }
        public ICommand ConvertOrderToInvoiceCommand { get; }
        public ICommand SalesReturnsCommand { get; }
        public ICommand SalesDashboardCommand { get; }
        public ICommand SalesForecastCommand { get; }

        // Purchasing
        public ICommand SuppliersListCommand { get; }
        public ICommand AddSupplierCommand { get; }
        public ICommand EditSupplierCommand { get; }
        public ICommand DeleteSupplierCommand { get; }
        public ICommand PurchaseOrderListCommand { get; }
        public ICommand AddPurchaseOrderCommand { get; }
        public ICommand EditPurchaseOrderCommand { get; }
        public ICommand ReceivePurchaseOrderCommand { get; }
        public ICommand PurchaseReturnsCommand { get; }
        public ICommand SupplierPaymentsCommand { get; }
        public ICommand SupplierBalanceReportCommand { get; }
        public ICommand PurchasingDashboardCommand { get; }

        // Accounting
        public ICommand ChartOfAccountsCommand { get; }
        public ICommand AddAccountCommand { get; }
        public ICommand EditAccountCommand { get; }
        public ICommand DeleteAccountCommand { get; }
        public ICommand JournalEntryCommand { get; }
        public ICommand AddJournalEntryCommand { get; }
        public ICommand GeneralLedgerCommand { get; }
        public ICommand TrialBalanceCommand { get; }
        public ICommand BalanceSheetCommand { get; }
        public ICommand IncomeStatementCommand { get; }
        public ICommand CashFlowCommand { get; }
        public ICommand ProfitAndLossCommand { get; }
        public ICommand FinancialDashboardCommand { get; }

        // POS
        public ICommand POSOpenSessionCommand { get; }
        public ICommand POSCloseSessionCommand { get; }
        public ICommand POSNewSaleCommand { get; }
        public ICommand POSReturnCommand { get; }
        public ICommand POSHoldCommand { get; }
        public ICommand POSRecallCommand { get; }
        public ICommand POSDiscountCommand { get; }
        public ICommand POSPaymentCommand { get; }
        public ICommand POSReportsCommand { get; }

        // Manufacturing
        public ICommand BillOfMaterialsCommand { get; }
        public ICommand AddBOMCommand { get; }
        public ICommand EditBOMCommand { get; }
        public ICommand WorkOrdersListCommand { get; }
        public ICommand AddWorkOrderCommand { get; }
        public ICommand ProductionScheduleCommand { get; }
        public ICommand ManufacturingCostReportCommand { get; }
        public ICommand ProductionDashboardCommand { get; }

        // Reports
        public ICommand SalesReportCommand { get; }
        public ICommand InventoryReportCommand { get; }
        public ICommand FinancialReportCommand { get; }
        public ICommand CustomerReportCommand { get; }
        public ICommand SupplierReportCommand { get; }
        public ICommand EmployeeReportCommand { get; }
        public ICommand ProductionReportCommand { get; }
        public ICommand CustomReportCommand { get; }
        public ICommand ReportGalleryCommand { get; }
        public ICommand ExportReportCommand { get; }
        public ICommand PrintReportCommand { get; }
        public ICommand EmailReportCommand { get; }

        // Security
        public ICommand UserManagementCommand { get; }
        public ICommand AddUserCommand { get; }
        public ICommand EditUserCommand { get; }
        public ICommand DeleteUserCommand { get; }
        public ICommand RoleManagementCommand { get; }
        public ICommand PermissionManagementCommand { get; }
        public ICommand ChangePasswordCommand { get; }
        public ICommand AuditTrailCommand { get; }
        public ICommand SecuritySettingsCommand { get; }
        public ICommand GeneralSettingsCommand { get; }
        public ICommand CompanySettingsCommand { get; }
        public ICommand SystemSettingsCommand { get; }
        public ICommand LanguageSettingsCommand { get; }
        public ICommand ThemeSettingsCommand { get; }
        public ICommand BackupSettingsCommand { get; }
        public ICommand LicenseSettingsCommand { get; }

        // Help
        public ICommand HelpCommand { get; }
        public ICommand UserManualCommand { get; }
        public ICommand TechnicalSupportCommand { get; }
        public ICommand SuggestionsCommand { get; }
        public ICommand AboutCommand { get; }
        public ICommand CheckUpdatesCommand { get; }

        // AI
        public ICommand InventoryPredictionCommand { get; }
        public ICommand SalesPredictionCommand { get; }
        public ICommand CustomerSegmentationCommand { get; }
        public ICommand AnomalyDetectionCommand { get; }
        public ICommand SmartRecommendationsCommand { get; }
        public ICommand AiInsightsCommand { get; }

        // Additional
        public ICommand BackupNowCommand { get; }
        public ICommand RestoreBackupCommand { get; }
        public ICommand SwitchLanguageCommand { get; }
        public ICommand ToggleThemeCommand { get; }
        public ICommand ViewNotificationsCommand { get; }
        public ICommand MarkAllAsReadCommand { get; }

        // ====================================================================
        // CONSTRUCTOR
        // ====================================================================

        public MainWnVM(
            IAuthSvc authService,
            IDataServ dataService,
            IPermServ permissionService,
            ILocSvc localizationService,
            IThmServ themeService,
            IBkpServ backupService,
            INavServ navigationService,
            ILogServ loggingService)
        {
            _authService = authService
                ?? throw new ArgumentNullException(nameof(authService));

            _dataService = dataService
                ?? throw new ArgumentNullException(nameof(dataService));

            _permissionService = permissionService
                ?? throw new ArgumentNullException(nameof(permissionService));

            _localizationService = localizationService
                ?? throw new ArgumentNullException(nameof(localizationService));

            _themeService = themeService
                ?? throw new ArgumentNullException(nameof(themeService));

            _backupService = backupService
                ?? throw new ArgumentNullException(nameof(backupService));

            _navigationService = navigationService
                ?? throw new ArgumentNullException(nameof(navigationService));

            _loggingService = loggingService
                ?? throw new ArgumentNullException(nameof(loggingService));

            // ----------------------------------------------------------------
            // Core
            // ----------------------------------------------------------------

            NewCommand = Cmd(() => SetStatus("إنشاء مستند جديد..."));
            OpenCommand = Cmd(() => SetStatus("فتح مستند..."));
            SaveCommand = Cmd(() => SetStatus("جاري حفظ البيانات..."));
            SaveAllCommand = Cmd(() => SetStatus("جاري حفظ جميع البيانات..."));
            PrintPreviewCommand = Cmd(() => SetStatus("معاينة الطباعة..."));
            PrintCommand = Cmd(() => SetStatus("جاري الطباعة..."));
            ExportDataCommand = Cmd(() => SetStatus("تصدير البيانات..."));
            ImportDataCommand = Cmd(() => SetStatus("استيراد البيانات..."));
            ExitCommand = Cmd(ExecuteExit);

            UndoCommand = Cmd(() => SetStatus("تراجع"));
            RedoCommand = Cmd(() => SetStatus("إعادة"));
            CutCommand = Cmd(() => SetStatus("قص"));
            CopyCommand = Cmd(() => SetStatus("نسخ"));
            PasteCommand = Cmd(() => SetStatus("لصق"));
            DeleteCommand = Cmd(() => SetStatus("حذف"));
            FindCommand = Cmd(() => SetStatus("بحث"));
            ReplaceCommand = Cmd(() => SetStatus("استبدال"));
            SelectAllCommand = Cmd(() => SetStatus("تحديد الكل"));

            DashVwCommand = Cmd(() => Navigate("dashboard"));
            FullScreenCommand = Cmd(() => SetStatus("تبديل وضع الشاشة الكاملة"));
            ZoomInCommand = Cmd(() => SetStatus("تكبير"));
            ZoomOutCommand = Cmd(() => SetStatus("تصغير"));
            RefreshCommand = Cmd(() => _ = LoadDataAsync());

            // ----------------------------------------------------------------
            // Inventory
            // ----------------------------------------------------------------

            ProductListCommand = Module("عرض المنتجات", "inventory");
            AddProductCommand = Module("إضافة منتج", "inventory");
            EditProductCommand = Module("تعديل منتج", "inventory");
            DeleteProductCommand = Module("حذف منتج", "inventory");
            CategoriesCommand = Module("التصنيفات", "inventory");
            WarehouseListCommand = Module("المستودعات", "inventory");
            StockMovementHistoryCommand = Module("حركات المخزون", "inventory");
            AdjustStockCommand = Module("تسوية المخزون", "inventory");
            StockTransferCommand = Module("نقل المخزون", "inventory");
            InventoryCountCommand = Module("جرد المخزون", "inventory");
            GenerateBarcodeCommand = Module("توليد الباركود", "inventory");
            PriceListCommand = Module("قائمة الأسعار", "inventory");
            InventoryValuationCommand = Module("تقييم المخزون", "inventory");
            SlowMovingItemsCommand = Module("المواد الراكدة", "inventory");
            TopSellingItemsCommand = Module("الأكثر مبيعاً", "inventory");
            ExpiredItemsCommand = Module("المواد المنتهية", "inventory");
            InventoryAnalysisCommand = Module("تحليل المخزون", "inventory");
            InventoryForecastCommand = Module("التنبؤ بالمخزون", "inventory");
            InventoryDashboardCommand = Module("لوحة المخزون", "inventory");

            // ----------------------------------------------------------------
            // Sales
            // ----------------------------------------------------------------

            InvoicesListCommand = Module("عرض الفواتير", "sales");
            AddInvoiceCommand = Module("فاتورة جديدة", "sales");
            EditInvoiceCommand = Module("تعديل فاتورة", "sales");
            DeleteInvoiceCommand = Module("حذف فاتورة", "sales");
            InvoiceDetailsCommand = Module("تفاصيل الفاتورة", "sales");
            ProcessPaymentCommand = Module("معالجة الدفع", "sales");
            InvoicePrintCommand = Module("طباعة الفاتورة", "sales");
            InvoiceEmailCommand = Module("إرسال الفاتورة", "sales");
            CustomersListCommand = Module("عرض العملاء", "sales");
            AddCustomerCommand = Module("عميل جديد", "sales");
            EditCustomerCommand = Module("تعديل عميل", "sales");
            DeleteCustomerCommand = Module("حذف عميل", "sales");
            CustomerGroupsCommand = Module("مجموعات العملاء", "sales");
            CustomerPriceListCommand = Module("أسعار العملاء", "sales");
            CustomerDiscountsCommand = Module("حسومات العملاء", "sales");
            CustomerStatementsCommand = Module("كشف حساب عميل", "sales");
            CustomerBalanceReportCommand = Module("رصيد العملاء", "sales");
            SalesOrderListCommand = Module("طلبات المبيعات", "sales");
            AddSalesOrderCommand = Module("طلب مبيعات جديد", "sales");
            EditSalesOrderCommand = Module("تعديل طلب مبيعات", "sales");
            ConvertOrderToInvoiceCommand = Module("تحويل الطلب إلى فاتورة", "sales");
            SalesReturnsCommand = Module("مردودات المبيعات", "sales");
            SalesDashboardCommand = Module("لوحة المبيعات", "sales");
            SalesForecastCommand = Module("توقع المبيعات", "sales");

            // ----------------------------------------------------------------
            // Purchasing
            // ----------------------------------------------------------------

            SuppliersListCommand = Module("عرض الموردين", "purchasing");
            AddSupplierCommand = Module("مورد جديد", "purchasing");
            EditSupplierCommand = Module("تعديل مورد", "purchasing");
            DeleteSupplierCommand = Module("حذف مورد", "purchasing");
            PurchaseOrderListCommand = Module("أوامر الشراء", "purchasing");
            AddPurchaseOrderCommand = Module("أمر شراء جديد", "purchasing");
            EditPurchaseOrderCommand = Module("تعديل أمر شراء", "purchasing");
            ReceivePurchaseOrderCommand = Module("استلام أمر شراء", "purchasing");
            PurchaseReturnsCommand = Module("مردودات المشتريات", "purchasing");
            SupplierPaymentsCommand = Module("مدفوعات الموردين", "purchasing");
            SupplierBalanceReportCommand = Module("رصيد الموردين", "purchasing");
            PurchasingDashboardCommand = Module("لوحة المشتريات", "purchasing");

            // ----------------------------------------------------------------
            // Accounting
            // ----------------------------------------------------------------

            ChartOfAccountsCommand = Module("شجرة الحسابات", "accounting");
            AddAccountCommand = Module("إضافة حساب", "accounting");
            EditAccountCommand = Module("تعديل حساب", "accounting");
            DeleteAccountCommand = Module("حذف حساب", "accounting");
            JournalEntryCommand = Module("القيود اليومية", "accounting");
            AddJournalEntryCommand = Module("قيد يومي جديد", "accounting");
            GeneralLedgerCommand = Module("دفتر الأستاذ", "accounting");
            TrialBalanceCommand = Module("ميزان المراجعة", "accounting");
            BalanceSheetCommand = Module("الميزانية", "accounting");
            IncomeStatementCommand = Module("قائمة الدخل", "accounting");
            CashFlowCommand = Module("قائمة التدفق النقدي", "accounting");
            ProfitAndLossCommand = Module("الأرباح والخسائر", "accounting");
            FinancialDashboardCommand = Module("لوحة المالية", "accounting");

            // ----------------------------------------------------------------
            // POS
            // ----------------------------------------------------------------

            POSOpenSessionCommand = Module("فتح جلسة", "pos");
            POSCloseSessionCommand = Module("إغلاق جلسة", "pos");
            POSNewSaleCommand = Module("بيع جديد", "pos");
            POSReturnCommand = Module("إرجاع", "pos");
            POSHoldCommand = Module("تعليق", "pos");
            POSRecallCommand = Module("استرجاع", "pos");
            POSDiscountCommand = Module("حسومات", "pos");
            POSPaymentCommand = Module("دفع", "pos");
            POSReportsCommand = Module("تقارير", "pos");

            // ----------------------------------------------------------------
            // Manufacturing
            // ----------------------------------------------------------------

            BillOfMaterialsCommand = Module("قوائم المكونات", "manufacturing");
            AddBOMCommand = Module("BOM جديد", "manufacturing");
            EditBOMCommand = Module("تعديل BOM", "manufacturing");
            WorkOrdersListCommand = Module("أوامر التشغيل", "manufacturing");
            AddWorkOrderCommand = Module("أمر تشغيل جديد", "manufacturing");
            ProductionScheduleCommand = Module("جدولة الإنتاج", "manufacturing");
            ManufacturingCostReportCommand = Module("تقرير التكاليف", "manufacturing");
            ProductionDashboardCommand = Module("لوحة الإنتاج", "manufacturing");

            // ----------------------------------------------------------------
            // Reports
            // ----------------------------------------------------------------

            SalesReportCommand = Module("تقرير المبيعات", "reports");
            InventoryReportCommand = Module("تقرير المخزون", "reports");
            FinancialReportCommand = Module("تقرير مالي", "reports");
            CustomerReportCommand = Module("تقرير العملاء", "reports");
            SupplierReportCommand = Module("تقرير الموردين", "reports");
            EmployeeReportCommand = Module("تقرير الموظفين", "reports");
            ProductionReportCommand = Module("تقرير الإنتاج", "reports");
            CustomReportCommand = Module("تقرير مخصص", "reports");
            ReportGalleryCommand = Module("معرض التقارير", "reports");
            ExportReportCommand = Module("تصدير التقرير", "reports");
            PrintReportCommand = Module("طباعة التقرير", "reports");
            EmailReportCommand = Module("إرسال التقرير", "reports");

            // ----------------------------------------------------------------
            // Security
            // ----------------------------------------------------------------

            UserManagementCommand = Module("إدارة المستخدمين", "security");
            AddUserCommand = Module("إضافة مستخدم", "security");
            EditUserCommand = Module("تعديل مستخدم", "security");
            DeleteUserCommand = Module("حذف مستخدم", "security");
            RoleManagementCommand = Module("إدارة الأدوار", "security");
            PermissionManagementCommand = Module("إدارة الصلاحيات", "security");
            ChangePasswordCommand = Module("تغيير كلمة المرور", "security");
            AuditTrailCommand = Module("سجل التدقيق", "security");
            SecuritySettingsCommand = Module("إعدادات الأمان", "security");
            GeneralSettingsCommand = Module("الإعدادات العامة", "settings");
            CompanySettingsCommand = Module("إعدادات الشركة", "settings");
            SystemSettingsCommand = Module("إعدادات النظام", "settings");
            LanguageSettingsCommand = Module("إعدادات اللغة", "settings");
            ThemeSettingsCommand = Module("إعدادات المظهر", "settings");
            BackupSettingsCommand = Module("إعدادات النسخ الاحتياطي", "settings");
            LicenseSettingsCommand = Module("إعدادات الترخيص", "settings");

            // ----------------------------------------------------------------
            // Help
            // ----------------------------------------------------------------

            HelpCommand = Module("المساعدة", "help");
            UserManualCommand = Module("الدليل", "help");
            TechnicalSupportCommand = Module("الدعم الفني", "help");
            SuggestionsCommand = Module("اقتراحات", "help");
            AboutCommand = Cmd(ExecuteAbout);
            CheckUpdatesCommand = Module("التحقق من التحديثات", "help");

            // ----------------------------------------------------------------
            // AI
            // ----------------------------------------------------------------

            InventoryPredictionCommand = Module("التنبؤ بالمخزون", "ai");
            SalesPredictionCommand = Module("التنبؤ بالمبيعات", "ai");
            CustomerSegmentationCommand = Module("تجزئة العملاء", "ai");
            AnomalyDetectionCommand = Module("كشف الشذوذ", "ai");
            SmartRecommendationsCommand = Module("توصيات ذكية", "ai");
            AiInsightsCommand = Module("رؤى الذكاء الاصطناعي", "ai");

            // ----------------------------------------------------------------
            // Additional
            // ----------------------------------------------------------------

            BackupNowCommand = Cmd(ExecuteBackup);
            RestoreBackupCommand = Cmd(ExecuteRestore);
            SwitchLanguageCommand = Cmd(ExecuteSwitchLanguage);
            ToggleThemeCommand = Cmd(ExecuteToggleTheme);
            ViewNotificationsCommand = Cmd(ExecuteViewNotifications);
            MarkAllAsReadCommand = Cmd(ExecuteMarkAllAsRead);

            // ----------------------------------------------------------------
            // Theme / Clock
            // ----------------------------------------------------------------

            try
            {
                IsDkTheme = _themeService.GetCurrentTheme();
            }
            catch
            {
                IsDkTheme = false;
            }

            CurrentContent = CreateWelcomeMessage();

            _ = LoadDataAsync();
        }

        // ====================================================================
        // COMMAND HELPERS
        // ====================================================================

        private static RelayCommand Cmd(Action action)
        {
            return new RelayCommand(action);
        }

        private RelayCommand Module(string action, string module)
        {
            return new RelayCommand(() => NavigateModule(action, module));
        }

        private void Navigate(string pageKey)
        {
            try
            {
                CurrentContent = _navigationService.NavigateTo(pageKey);
                StatusMessage = $"تم فتح {pageKey}";
            }
            catch (Exception ex)
            {
                StatusMessage = "تعذر فتح الصفحة.";
                _loggingService.LogError(
                    "Navigation",
                    $"Navigation failed: {pageKey}",
                    ex);
            }
        }

        private void NavigateModule(string action, string module)
        {
            try
            {
                CurrentContent =
                    _navigationService.NavigateToModule(
                        action,
                        module);

                StatusMessage = $"{module} - {action}";
            }
            catch (Exception ex)
            {
                StatusMessage = $"تعذر تنفيذ: {action}";
                _loggingService.LogError(
                    "Navigation",
                    $"Module navigation failed: {module}/{action}",
                    ex);
            }
        }

        private void SetStatus(string message)
        {
            StatusMessage = message;
        }

        // ====================================================================
        // CORE ACTIONS
        // ====================================================================

        private void ExecuteExit()
        {
            System.Windows.Application.Current?.Shutdown();
        }

        private void ExecuteBackup()
        {
            try
            {
                StatusMessage = "جاري إنشاء النسخة الاحتياطية...";

                _backupService.PerformBackup();

                StatusMessage = "تم إنشاء النسخة الاحتياطية بنجاح.";
            }
            catch (Exception ex)
            {
                StatusMessage = "فشل إنشاء النسخة الاحتياطية.";

                _loggingService.LogError(
                    "Backup",
                    "Backup operation failed.",
                    ex);
            }
        }

        private void ExecuteRestore()
        {
            StatusMessage = "استعادة النسخة الاحتياطية...";
        }

        private void ExecuteSwitchLanguage()
        {
            try
            {
                var current = _localizationService.GetCurrentLanguage();

                var language = string.Equals(
                    current,
                    "ar",
                    StringComparison.OrdinalIgnoreCase)
                    ? "en"
                    : "ar";

                App.SetApplicationLanguage(language);

                CurrentLanguageDisplay =
                    GetLanguageDisplay(language);

                StatusMessage =
                    $"تم تغيير اللغة إلى {CurrentLanguageDisplay}";
            }
            catch (Exception ex)
            {
                _loggingService.LogError(
                    "Localization",
                    "Language switch failed.",
                    ex);

                StatusMessage = "تعذر تغيير اللغة.";
            }
        }

        private static string GetLanguageDisplay(string language)
        {
            return language.ToLowerInvariant() switch
            {
                "ar" => "🇸🇦 عربي",
                "en" => "🇬🇧 English",
                "fr" => "🇫🇷 Français",
                "tr" => "🇹🇷 Türkçe",
                _ => language
            };
        }

        private void ExecuteToggleTheme()
        {
            IsDkTheme = !IsDkTheme;

            StatusMessage =
                IsDkTheme
                    ? "الوضع الليلي"
                    : "الوضع النهاري";
        }

        private void ExecuteViewNotifications()
        {
            StatusMessage =
                $"الإشعارات ({UnreadNotifications} غير مقروءة)";
        }

        private void ExecuteMarkAllAsRead()
        {
            UnreadNotifications = 0;
            StatusMessage = "تم تعليم جميع الإشعارات كمقروءة.";
        }

        private static void ExecuteAbout()
        {
            MessageBox.Show(
                "شو تيك ERP V10\n\n" +
                "Enterprise Resource Planning System\n" +
                "الإصدار: 10.6.0\n\n" +
                "© ShouTech Software",
                "حول البرنامج",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
        }

        // ====================================================================
        // CLOCK
        // ====================================================================

        private void UpdateClock()
        {
            var now = DateTime.Now;

            if (System.Windows.Application.Current == null)
                return;

            System.Windows.Application.Current.Dispatcher.Invoke(() =>
            {
                CurrentDate = AppFormat.FormatDate(now);
                CurrentTime = AppFormat.FormatTime(now);
                CurrentDateTime = AppFormat.FormatDateTime(now);
            });
        }

        // ====================================================================
        // WELCOME VIEW
        // ====================================================================

        private static StackPanel CreateWelcomeMessage()
        {
            return new StackPanel
            {
                VerticalAlignment = VerticalAlignment.Center,
                HorizontalAlignment = HorizontalAlignment.Center,
                Children =
                {
                    new TextBlock
                    {
                        Text = "🏢",
                        FontSize = 72,
                        HorizontalAlignment =
                            HorizontalAlignment.Center
                    },

                    new TextBlock
                    {
                        Text = "شو تيك لإدارة المؤسسات",
                        FontSize = 32,
                        FontWeight = FontWeights.Bold,
                        Foreground =
                            new SolidColorBrush(
                                Color.FromRgb(44, 62, 80)),
                        HorizontalAlignment =
                            HorizontalAlignment.Center,
                        Margin = new Thickness(0, 20, 0, 5)
                    },

                    new TextBlock
                    {
                        Text = "SHOUTECH ERP V10 - Enterprise Edition",
                        FontSize = 18,
                        Foreground =
                            new SolidColorBrush(
                                Color.FromRgb(127, 140, 141)),
                        HorizontalAlignment =
                            HorizontalAlignment.Center
                    },

                    new TextBlock
                    {
                        Text = "نظام متكامل لإدارة الموارد المؤسسية",
                        FontSize = 14,
                        Foreground =
                            new SolidColorBrush(
                                Color.FromRgb(149, 165, 166)),
                        HorizontalAlignment =
                            HorizontalAlignment.Center,
                        Margin = new Thickness(0, 10, 0, 0)
                    }
                }
            };
        }

        // ====================================================================
        // INITIAL DATA
        // ====================================================================

        private async Task LoadDataAsync()
        {
            try
            {
                StatusMessage = "جاري تحميل البيانات...";

                var user =
                    await _authService.GetCurrentUserAsync();

                if (user != null)
                {
                    CurrentUser =
                        string.IsNullOrWhiteSpace(user.FullName)
                            ? user.Username
                            : user.FullName;

                    CurrentRole =
                        string.IsNullOrWhiteSpace(user.Role)
                            ? "مستخدم"
                            : user.Role;

                    WindowTitle =
                        string.IsNullOrWhiteSpace(user.CompanyName)
                            ? "شو تيك ERP V10"
                            : $"شو تيك ERP V10 - {user.CompanyName}";
                }

                TotalCustomers =
                    await _dataService.GetTotalCustomersAsync();

                TotalProducts =
                    await _dataService.GetTotalProductsAsync();

                PendingApprovals =
                    await _dataService.GetTotalPendingApprovalsAsync();

                var documents =
                    await _dataService.GetRecentDocumentsAsync(5);

                _recentDocuments.Clear();

                foreach (var document in documents)
                    _recentDocuments.Add(document);

                DbConnectionStatusText = "متصل";
                DbConnectionStatusColor = Brushes.LimeGreen;

                StatusMessage = "تم تحميل البيانات بنجاح.";
            }
            catch (Exception ex)
            {
                DbConnectionStatusText = "غير متصل";
                DbConnectionStatusColor = Brushes.Red;

                StatusMessage = "تعذر تحميل بيانات النظام.";

                _loggingService.LogError(
                    "MainWnVM",
                    "Initial data loading failed.",
                    ex);
            }
        }

        // ====================================================================
        // DISPOSAL
        // ====================================================================

        public void Dispose()
        {
            if (_disposed)
                return;

            _disposed = true;
            GC.SuppressFinalize(this);
        }
    }
}