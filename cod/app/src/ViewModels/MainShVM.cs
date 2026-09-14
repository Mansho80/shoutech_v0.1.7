using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.Input;
using ShouTech.App.Common;
using ShouTech.App.Localization;
using ShouTech.App.Navigation;
using ShouTech.App.Services;
using ShouTech.App.Views;

namespace ShouTech.App.ViewModels
{
    /// <summary>
    /// Main shell ViewModel — orchestrates navigation, theme, status bar, and system actions.
    /// </summary>
    public sealed class MainShVM : BaseVM, IDisposable
    {
        private readonly INavServ _navigation;
        private readonly IThmServ _theme;
        private readonly ILogServ _logging;
        private readonly IBkpServ _backup;
        private readonly IDataServ _data;
        private readonly ILocSvc _localization;
        private readonly DispatcherTimer _clockTimer;
        private readonly Window? _ownerWindow; // ✅ حقل جديد لتخزين النافذة المالكة

        private object? _currentContent;
        private string _statusMessage = string.Empty;
        private string _currentTime = AppFormat.FormatTime(DateTime.Now);
        private string _currentUser = string.Empty;
        private string _currentUsername = string.Empty;
        private string _userRoleLabel = string.Empty;
        private UsrAccLvl _userAccessLevel = UsrAccLvl.User;
        private bool _isReadOnlyUser;
        private string _companyName = string.Empty;
        private string _currentDatabase = string.Empty;
        private string _titleCompanyName = string.Empty;
        private string _windowTitle = string.Empty;
        private string _versionLabel = string.Empty;
        private string _themeToggleLabel = "الوضع الليلي";
        private string _themeToggleIcon = "☾";
        private string _themeToggleTooltip = string.Empty;
        private bool _isDkTheme = true;
        private bool _isReady = true;
        private string _bottomUserDisplay = string.Empty;

        #region Properties

        public object? CurrentContent
        {
            get => _currentContent;
            private set => SetProperty(ref _currentContent, value);
        }

        public string StatusMessage
        {
            get => _statusMessage;
            private set => SetProperty(ref _statusMessage, value);
        }

        public string CurrentTime
        {
            get => _currentTime;
            private set => SetProperty(ref _currentTime, value);
        }

        public string CurrentUser
        {
            get => _currentUser;
            private set => SetProperty(ref _currentUser, value);
        }

        public string CurrentUsername
        {
            get => _currentUsername;
            private set => SetProperty(ref _currentUsername, value);
        }

        public string UserRoleLabel
        {
            get => _userRoleLabel;
            private set => SetProperty(ref _userRoleLabel, value);
        }

        public UsrAccLvl UsrAccLvl
        {
            get => _userAccessLevel;
            private set
            {
                if (SetProperty(ref _userAccessLevel, value))
                {
                    OnPropertyChanged(nameof(IsAdministratorUser));
                    OnPropertyChanged(nameof(IsViewerUser));
                }
            }
        }

        public bool IsReadOnlyUser
        {
            get => _isReadOnlyUser;
            private set => SetProperty(ref _isReadOnlyUser, value);
        }

        public bool IsAdministratorUser => UsrAccLvl == UsrAccLvl.Administrator || UsrSession.IsAdministrator;
        public bool IsViewerUser => UsrAccLvl == UsrAccLvl.Viewer || UsrSession.IsViewer;

        public string BottomUserDisplay
        {
            get => _bottomUserDisplay;
            private set => SetProperty(ref _bottomUserDisplay, value);
        }

        public string CompanyName
        {
            get => _companyName;
            private set => SetProperty(ref _companyName, value);
        }

        public string CurrentDatabase
        {
            get => _currentDatabase;
            private set => SetProperty(ref _currentDatabase, value);
        }

        public string WindowTitle
        {
            get => _windowTitle;
            private set => SetProperty(ref _windowTitle, value);
        }

        public string VersionLabel
        {
            get => _versionLabel;
            private set => SetProperty(ref _versionLabel, value);
        }

        public string ThemeToggleLabel
        {
            get => _themeToggleLabel;
            private set => SetProperty(ref _themeToggleLabel, value);
        }

        public string ThemeToggleIcon
        {
            get => _themeToggleIcon;
            private set => SetProperty(ref _themeToggleIcon, value);
        }

        public string ThemeToggleTooltip
        {
            get => _themeToggleTooltip;
            private set => SetProperty(ref _themeToggleTooltip, value);
        }

        public bool IsDkTheme
        {
            get => _isDkTheme;
            private set => SetProperty(ref _isDkTheme, value);
        }

        public bool IsReady
        {
            get => _isReady;
            private set => SetProperty(ref _isReady, value);
        }

        public ObservableCollection<DockedWinItem> DockedWindows { get; } = new();

        public Window? OwnerWindow => _ownerWindow;

        #endregion

        #region Commands

        public ICommand ToggleThemeCommand { get; }
        public ICommand ShowDashboardCommand { get; }
        public ICommand SaveCommand { get; }
        public ICommand UndoCommand { get; }
        public ICommand RedoCommand { get; }
        public ICommand PrintCommand { get; }
        public ICommand FindCommand { get; }
        public ICommand SettingsCommand { get; }
        public ICommand ReportsCommand { get; }
        public ICommand ImportCommand { get; }
        public ICommand ExportCommand { get; }
        public ICommand ExitCommand { get; }
        public ICommand RestoreDockedWindowCommand { get; }

        #endregion

        #region Constructors

        /// <summary>
        /// المُنشئ الافتراضي (للتوافق مع الكود القديم)
        /// </summary>
        public MainShVM() : this(null)
        {
        }

        /// <summary>
        /// المُنشئ الرئيسي الذي يستقبل النافذة المالكة (MWin)
        /// ✅ تم إضافة هذا المُنشئ لحل مشكلة CS1729
        /// </summary>
        /// <param name="ownerWindow">النافذة الرئيسية (MWin)</param>
        public MainShVM(Window? ownerWindow)
        {
            _ownerWindow = ownerWindow;

            _navigation = AppHost.Navigation;
            _theme = AppHost.Theme;
            _logging = AppHost.Logging;
            _backup = AppHost.Backup;
            _data = AppHost.Data;
            _localization = AppHost.Localization;

            // تهيئة الأوامر
            ToggleThemeCommand = new RelayCommand(ToggleTheme);
            ShowDashboardCommand = new RelayCommand(ShowDashboard);
            SaveCommand = new RelayCommand(() => StatusMessage = StatBarEn.Save);
            UndoCommand = new RelayCommand(() => StatusMessage = StatBarEn.Undo);
            RedoCommand = new RelayCommand(() => StatusMessage = StatBarEn.Redo);
            PrintCommand = new RelayCommand(() => StatusMessage = StatBarEn.Print);
            FindCommand = new RelayCommand(() => StatusMessage = StatBarEn.Search);
            SettingsCommand = new RelayCommand(() => NavigateToModule(Loc.Get("Tools.Options"), "Tools"));
            ReportsCommand = new RelayCommand(() => NavigateToModule(Loc.Get("Reports.Statistics"), "Reports"));
            ImportCommand = new RelayCommand(() => NavigateToModule(Loc.Get("Menu.Import"), "File"));
            ExportCommand = new RelayCommand(() => NavigateToModule(Loc.Get("Menu.Export"), "File"));
            ExitCommand = new RelayCommand(ExecuteExit);
            RestoreDockedWindowCommand = new RelayCommand<DockedWinItem>(RestoreDockedWindow);

            // تهيئة المظهر
            _isDkTheme = _theme.GetCurrentTheme();
            UpdateThemeLabels();
            RefreshLocalizedStrings();

            // الاشتراك في الأحداث
            _theme.ThemeChanged += OnThemeChanged;
            _localization.LanguageChanged += OnLanguageChanged;

            // الساعة
            _clockTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _clockTimer.Tick += (_, _) => CurrentTime = AppFormat.FormatTime(DateTime.Now);
            _clockTimer.Start();

            // تطبيق جلسة المستخدم إن وجدت
            if (UsrSession.Current != null)
                ApplyUsrSession(UsrSession.Current);

            // عرض لوحة التحكم
            ShowDashboard();
            _ = LoadSessionAsync();
        }

        #endregion

        #region Window Management (Docking)

        public void DockWindow(string title, Window window)
        {
            foreach (var existing in DockedWindows)
            {
                if (ReferenceEquals(existing.Window, window))
                    return;
            }

            DockedWindows.Add(new DockedWinItem { Title = title, Window = window });
            LayoutDockedWindows(_ownerWindow?.ActualWidth ?? 0);
        }

        public void UndockWindow(DockedWinItem item)
        {
            DockedWindows.Remove(item);
            LayoutDockedWindows(_ownerWindow?.ActualWidth ?? 0);
        }

        public void LayoutDockedWindows(double availableWidth)
        {
            if (DockedWindows.Count == 0)
                return;

            var width = Math.Max(220d, availableWidth - 24d);
            const double desiredCardWidth = 190d;
            const double minimumCardWidth = 140d;
            const double gap = 6d;

            var count = DockedWindows.Count;
            var canFitSideBySide = count * desiredCardWidth + Math.Max(0, count - 1) * gap <= width;

            if (canFitSideBySide)
            {
                var cardWidth = desiredCardWidth;
                var total = count * cardWidth + Math.Max(0, count - 1) * gap;
                var start = Math.Max(0, (width - total) / 2);

                for (var i = 0; i < count; i++)
                {
                    var item = DockedWindows[i];
                    item.ItemWidth = cardWidth;
                    item.Left = start + i * (cardWidth + gap);
                    item.ZIndex = i;
                }

                return;
            }

            // Not enough room for every card at the preferred width: preserve a
            // visible slice of each earlier card and overlap progressively.
            var card = Math.Min(desiredCardWidth, Math.Max(minimumCardWidth, width));
            var maxLeft = Math.Max(0, width - card);
            var step = count <= 1 ? 0 : maxLeft / (count - 1);
            step = Math.Max(18d, step);

            if (count > 1 && step * (count - 1) > maxLeft)
                step = maxLeft / (count - 1);

            for (var i = 0; i < count; i++)
            {
                var item = DockedWindows[i];
                item.ItemWidth = card;
                item.Left = Math.Min(maxLeft, i * step);
                item.ZIndex = i;
            }
        }

        public void RemoveDockedWindow(Window window)
        {
            for (var i = DockedWindows.Count - 1; i >= 0; i--)
            {
                if (ReferenceEquals(DockedWindows[i].Window, window))
                    DockedWindows.RemoveAt(i);
            }

            LayoutDockedWindows(_ownerWindow?.ActualWidth ?? 0);
        }

        private void RestoreDockedWindow(DockedWinItem? item)
        {
            if (item == null)
                return;

            ShellWinDock.Restore(item, this);
        }

        #endregion

        #region Navigation & Ribbon Actions

        public void HandleRibbonAction(string? label, string? actionKey, string? tabName, string? tabHeader)
        {
            if (string.IsNullOrWhiteSpace(label) && string.IsNullOrWhiteSpace(actionKey))
                return;

            if (TryHandleSystemAction(actionKey, label))
                return;

            if (TryHandleWindowAction(actionKey, label))
                return;

            var module = RibModMap.ResolveModule(tabName, tabHeader);
            NavigateToModule(label ?? actionKey ?? string.Empty, module);
        }

        public void ShowDashboard()
        {
            CurrentContent = _navigation.NavigateTo("dashboard");
            StatusMessage = StatBarEn.Dashboard;
        }

        private void NavigateToModule(string label, string module)
        {
            CurrentContent = _navigation.NavigateToModule(label, module);
            StatusMessage = StatBarEn.ModuleName(module);
        }

        #endregion

        #region System Actions (Ribbon)

        private bool TryHandleSystemAction(string? actionKey, string? label)
        {
            var key = actionKey ?? label ?? string.Empty;

            switch (key)
            {
                case "Menu.New":
                case "جديد":
                case "New":
                case "Nouveau":
                case "Yeni":
                    OpenNewCompanyWizard();
                    return true;

                case "Menu.Exit":
                case "Exit.Exit":
                case "خروج":
                    ExecuteExit();
                    return true;

                case "Exit.ExitAndShutdown":
                case "خروج وإطفاء الحاسب":
                    var result = MessageBox.Show(
                        Loc.Get("Messages.ConfirmExit"),
                        Loc.Get("Buttons.OK"),
                        MessageBoxButton.YesNo,
                        MessageBoxImage.Question);

                    if (result == MessageBoxResult.Yes)
                    {
                        ExecuteExit();
                        try { System.Diagnostics.Process.Start("shutdown", "/s /t 0"); } catch { }
                    }
                    return true;

                case "Help.About":
                case "حول البرنامج":
                    MessageBox.Show(
                        $"{Loc.Get("Application.Title")}\n{Loc.Get("Shell.VersionLabel")}\n© 2026 ShouTech Software\n\n{Loc.Get("Shell.Tagline")}",
                        Loc.Get("Help.About"),
                        MessageBoxButton.OK,
                        MessageBoxImage.Information);
                    StatusMessage = StatBarEn.About;
                    return true;

                case "استعادة شركة":
                case "Restore company":
                case "Restore Company":
                case "Tools.RestoreCompany":
                case "Restaurer une société":
                case "Şirket geri yükleme":
                    OpenRestoreCompanyWindow();
                    return true;

                case "Tools.Backup":
                case "النسخ الاحتياطي":
                    try
                    {
                        StatusMessage = StatBarEn.Loading;
                        var backupResult = _backup.PerformRotatedBackup();
                        StatusMessage = backupResult.Success
                            ? StatBarEn.SaveSuccess
                            : StatBarEn.OperationFailed;
                    }
                    catch (Exception ex)
                    {
                        StatusMessage = StatBarEn.OperationFailed;
                        _logging.LogError("Backup", "Ribbon backup failed", ex);
                    }
                    return true;

                case "Shell.ThemeDark":
                case "الوضع الليلي":
                    _theme.SetTheme(true);
                    return true;

                case "Shell.ThemeLight":
                case "الوضع النهاري":
                    _theme.SetTheme(false);
                    return true;

                case "Shell.ToggleTheme":
                case "تبديل المظهر":
                    _theme.ToggleTheme();
                    return true;
            }

            return false;
        }

        private bool TryHandleWindowAction(string? actionKey, string? label)
        {
            var key = actionKey ?? label ?? string.Empty;

            switch (key)
            {
                case "Exit.SwitchCompany":
                case "تبديل الشركة":
                case "View.InfoWindow":
                case "نافذة المعلومات":
                case "Menu.Open":
                case "فتح":
                case "Open":
                case "Ouvrir":
                case "Aç":
                case "File.Open":
                    OpenCompanyManagementWindow();
                    return true;

                case "View.CompanyInfo":
                case "معلومات الشركة":
                    OpenNewCompanyWizard();
                    return true;
            }

            return false;
        }



        private void OpenRestoreCompanyWindow()
        {
            var existing = FindOpenWindow<RestoreCoWin>();
            if (existing != null)
            {
                WinMgr.BringToFront(existing);
                StatusMessage = "تم فتح استعادة الشركة";
                return;
            }

            var window = new RestoreCoWin();
            var shellHost = _ownerWindow ?? System.Windows.Application.Current?.MainWindow;
            WinMgr.ShowIndependent(window, shellHost);
            StatusMessage = "استعادة شركة";
        }

        public void FreezeForCompanySwitch()
        {
            if (_ownerWindow is MWin shell)
            {
                shell.FreezeForCompanySwitch();
                return;
            }

            if (System.Windows.Application.Current?.MainWindow is MWin main)
                main.FreezeForCompanySwitch();
        }

        public void UnfreezeAfterCompanyLogin()
        {
            if (_ownerWindow is MWin shell)
            {
                shell.UnfreezeAfterCompanyLogin();
                return;
            }

            if (System.Windows.Application.Current?.MainWindow is MWin main)
                main.UnfreezeAfterCompanyLogin();
        }

        private void OpenCompanyManagementWindow()
        {
            var existing = FindOpenWindow<ComWin>();
            if (existing != null)
            {
                WinMgr.BringToFront(existing);
                StatusMessage = "تم فتح نافذة الشركات";
                return;
            }

            var window = new ComWin(ComWinMode.Management);
            var shellHost = _ownerWindow ?? System.Windows.Application.Current?.MainWindow;
            WinMgr.ShowIndependent(window, shellHost);
            StatusMessage = "تم فتح إدارة الشركات";
        }

        private void OpenStandaloneWindow<TWindow>(Func<TWindow> factory, string statusMessage)
            where TWindow : Window
        {
            var existing = FindOpenWindow<TWindow>();
            if (existing != null)
            {
                WinMgr.BringToFront(existing);
                StatusMessage = statusMessage;
                return;
            }

            var window = factory();
            var shellHost = _ownerWindow ?? System.Windows.Application.Current?.MainWindow;
            WinMgr.ShowIndependent(window, shellHost);
            StatusMessage = statusMessage;
        }

        private static TWindow? FindOpenWindow<TWindow>()
            where TWindow : Window
        {
            var windows = System.Windows.Application.Current?.Windows;
            if (windows == null)
                return null;

            foreach (var window in windows)
            {
                if (window is TWindow typedWindow)
                    return typedWindow;
            }

            return null;
        }

        #endregion

        #region Theme Management

        private void ToggleTheme()
        {
            _theme.ToggleTheme();
        }

        private void OnThemeChanged(object? sender, bool isDark)
        {
            IsDkTheme = isDark;
            UpdateThemeLabels();
            StatusMessage = isDark ? StatBarEn.DarkMode : StatBarEn.LightMode;
        }

        private void UpdateThemeLabels()
        {
            ThemeToggleLabel = IsDkTheme ? "الوضع النهاري" : "الوضع الليلي";
            ThemeToggleIcon = IsDkTheme ? "☀" : "☾";
            ThemeToggleTooltip = IsDkTheme
                ? Loc.Get("Shell.ToggleThemeLight")
                : Loc.Get("Shell.ToggleThemeDark");
        }

        #endregion

        #region Language Management

        private void OnLanguageChanged(object? sender, EventArgs e)
        {
            RefreshLocalizedStrings();
            UpdateThemeLabels();
            _navigation.ClearCache();
            ShowDashboard();
            RefreshStatusBar();
            UiLoczr.ScheduleApplyToAllWindows();
        }

        private void RefreshLocalizedStrings()
        {
            // The shell caption is intentionally brand-only. Company/user details belong in the status bar.
            WindowTitle = "ShouTech";

            UserRoleLabel = ResolveRoleLabel(UsrAccLvl);
            RefreshStatusBar();
        }

        #endregion

        #region User Session

        private async Task LoadSessionAsync()
        {
            try
            {
                IsReady = false;
                StatusMessage = StatBarEn.Loading;

                var user = await AppHost.Auth.GetCurrentUserAsync();
                if (user != null)
                    ApplyUsrSession(user);
                else if (AppState.CurrentUser != null)
                    ApplyUsrSession(MapFromAppState(AppState.CurrentUser));

                RefreshStatusBar();
                IsReady = true;
            }
            catch (Exception ex)
            {
                _logging.LogError("MainShell", "LoadSessionAsync", ex);
                StatusMessage = StatBarEn.Ready;
                IsReady = true;
            }
        }

        /// <summary>Rehydrates the existing shell after a successful company session handoff.</summary>
        public void RefreshAfterCompanySession()
        {
            try
            {
                _navigation.ClearCache();
                CurrentContent = null;
                var user = AppHost.Auth.GetCurrentUserAsync().GetAwaiter().GetResult();
                if (user != null)
                    ApplyUsrSession(user);
                else if (AppState.CurrentUser != null)
                    ApplyUsrSession(MapFromAppState(AppState.CurrentUser));
                IsReady = true;
                ShowDashboard();
                RefreshStatusBar();
            }
            catch (Exception ex)
            {
                _logging.LogError("MainShell", "RefreshAfterCompanySession", ex);
            }
        }

        private void ApplyUsrSession(Services.UserInfo user)
        {
            CurrentUser = user.FullName ?? string.Empty;
            CurrentUsername = user.Username ?? string.Empty;
            UsrAccLvl = user.AccessLevel;
            IsReadOnlyUser = user.IsReadOnly;
            UserRoleLabel = ResolveRoleLabel(user.AccessLevel);
            _titleCompanyName = user.CompanyName ?? Loc.Get("Shell.DefaultCompany") ?? "شركة";
            WindowTitle = "ShouTech";
            RefreshStatusBar();

            if (user.IsReadOnly)
                StatusMessage = StatBarEn.ViewerMode;
        }

        private static string ResolveRoleLabel(UsrAccLvl accessLevel) => accessLevel switch
        {
            UsrAccLvl.Administrator => AppHost.Localization.GetString("Shell.RoleAdministrator"),
            UsrAccLvl.Viewer => AppHost.Localization.GetString("Shell.RoleViewer"),
            _ => AppHost.Localization.GetString("Shell.RoleUser")
        };

        private static Services.UserInfo MapFromAppState(Services.UserInfo user) => new()
        {
            Username = user.Username ?? string.Empty,
            FullName = user.FullName ?? string.Empty,
            Role = user.Role ?? string.Empty,
            RoleCode = user.RoleCode ?? string.Empty,
            AccessLevel = user.AccessLevel,
            IsSuperAdmin = user.IsSuperAdmin,
            IsAuthenticated = user.IsAuthenticated,
            CompanyName = !string.IsNullOrWhiteSpace(AppState.CurrentCompanyDisplayName)
                ? AppState.CurrentCompanyDisplayName
                : (AppState.CurrentCompanyCode ?? string.Empty)
        };

        private static string ResolveCurrentDatabaseDisplay()
        {
            try
            {
                var provider = DatabaseRuntime.GetProvider();
                var connection = DatabaseRuntime.GetConnectionString();

                if (string.Equals(provider, "SQLite", StringComparison.OrdinalIgnoreCase))
                {
                    var dataSource = DatabaseRuntime.GetSqliteDataSource(connection);
                    if (!string.IsNullOrWhiteSpace(dataSource))
                        return Path.GetFileName(dataSource);
                }

                if (!string.IsNullOrWhiteSpace(connection))
                {
                    foreach (var part in connection.Split(';'))
                    {
                        var pair = part.Split('=', 2, StringSplitOptions.TrimEntries);
                        if (pair.Length == 2 &&
                            pair[0].Equals("Database", StringComparison.OrdinalIgnoreCase) &&
                            !string.IsNullOrWhiteSpace(pair[1]))
                            return pair[1].Trim();
                    }
                }

                return provider;
            }
            catch
            {
                return DatabaseRuntime.GetProvider();
            }
        }

        private void RefreshStatusBar()
        {
            VersionLabel = StatBarEn.Version;
            CurrentDatabase = ResolveCurrentDatabaseDisplay();
            var activeCompanyName = AppState.CurrentCompanyDisplayName;
            if (string.IsNullOrWhiteSpace(activeCompanyName) && !string.IsNullOrWhiteSpace(_titleCompanyName))
                activeCompanyName = _titleCompanyName;
            CompanyName = string.IsNullOrWhiteSpace(activeCompanyName)
                ? StatBarEn.DefaultCompany
                : activeCompanyName;
            if (!string.IsNullOrWhiteSpace(CurrentUsername))
                BottomUserDisplay = StatBarEn.BuildUserDisplay(CurrentUsername, CurrentUser, UsrAccLvl);

            if (IsReady)
                StatusMessage = IsReadOnlyUser ? StatBarEn.ViewerMode : StatBarEn.Ready;
        }

        #endregion

        #region ✅ التعديل الجوهري: فتح معالج إنشاء الشركة مع تمرير المالك

        /// <summary>
        /// فتح معالج إنشاء شركة جديدة مع تمرير النافذة المالكة
        /// ✅ تم تعديل هذه الدالة لحل مشكلة اختفاء النافذة (المشكلة 1 و 2)
        /// </summary>
        /// <summary>
        /// File → New: create an additional company without tearing down the shell.
        /// On cancel: only close the wizard (no company window, no app shutdown).
        /// On success: optional management company picker in Management mode.
        /// </summary>
        public void OpenNewCompanyWizard()
        {
            var owner = _ownerWindow ?? System.Windows.Application.Current?.MainWindow;

            if (!ConfirmCompanyWizardWindowClose())
                return;

            // Prepare a clean shell: all secondary company/operational windows close before the wizard.
            CloseAllSecondaryWindowsForCompanyWizard(owner);

            if (owner != null)
            {
                owner.IsEnabled = false;
            }

            try
            {
                var wizard = new StpWiz(StpWizMode.NewCompany, owner);
                var dialogResult = wizard.ShowDialog();

                if (wizard.CompletedSuccessfully || dialogResult == true)
                {
                    StatusMessage = "تم إنشاء الشركة بنجاح";
                    // Management mode only — Cancel/Escape must not call Application.Shutdown.
                    OpenCompanyManagementWindow();
                }
                else
                {
                    StatusMessage = "تم إلغاء إنشاء الشركة";
                }
            }
            catch (Exception ex)
            {
                StatusMessage = "تعذر فتح معالج إنشاء الشركة";
                _logging.LogError("CompanyWizard", "OpenNewCompanyWizard failed", ex);
                try
                {
                    System.Windows.MessageBox.Show(
                        ex.Message,
                        "Company wizard",
                        System.Windows.MessageBoxButton.OK,
                        System.Windows.MessageBoxImage.Error);
                }
                catch { }
            }
            finally
            {
                if (owner != null)
                {
                    owner.IsEnabled = true;
                    try { owner.Activate(); } catch { }
                }
            }
        }

        private static bool ConfirmCompanyWizardWindowClose()
        {
            var openSecondaryCount = 0;
            try
            {
                openSecondaryCount = System.Windows.Application.Current?.Windows
                    .OfType<Window>()
                    .Count(w => w != null && w.IsVisible && w is not MWin && w is not StpWiz) ?? 0;
            }
            catch { }

            if (openSecondaryCount == 0)
                return true;

            var isArabic = (ShouTech.App.App.CurrentLanguageCode ?? "ar")
                .StartsWith("ar", StringComparison.OrdinalIgnoreCase);

            var message = isArabic
                ? "سيتم إغلاق جميع النوافذ المفتوحة قبل بدء معالج إنشاء الشركة الجديدة.\n\nهل تريد المتابعة؟"
                : "All open windows will be closed before the new-company wizard starts.\n\nDo you want to continue?";

            var title = isArabic ? "تأكيد بدء معالج الشركات" : "Confirm company wizard";

            return System.Windows.MessageBox.Show(
                message,
                title,
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning,
                MessageBoxResult.No) == MessageBoxResult.Yes;
        }

        private void CloseAllSecondaryWindowsForCompanyWizard(Window? shellOwner)
        {
            try
            {
                foreach (var item in DockedWindows.ToList())
                {
                    try { item.Window?.Close(); } catch { }
                }
                DockedWindows.Clear();
            }
            catch { }

            try
            {
                foreach (Window window in System.Windows.Application.Current.Windows.OfType<Window>().ToList())
                {
                    if (window is MWin || window is StpWiz || ReferenceEquals(window, shellOwner))
                        continue;

                    try { window.Close(); } catch { }
                }
            }
            catch { }
        }

        /// <summary>
        /// Full tear-down path reserved for first-run / forced company switch flows only.
        /// Not used from File → New to avoid crash on wizard cancel.
        /// </summary>
        private void PrepareForCompanyCreation()
        {
            foreach (var item in DockedWindows.ToList())
            {
                if (item.Window != null && item.Window.IsVisible)
                    item.Window.Close();
            }

            DockedWindows.Clear();
            CurrentContent = null;
            _navigation.ClearCache();

            AppState.CurrentCompanyCode = null;
            AppState.CurrentUser = null;
            System.Windows.Application.Current?.Properties.Remove("SelectedCompany");
            AppState.InactiveMainWindow = _ownerWindow;

            try
            {
                AppHost.Auth.LogoutAsync().GetAwaiter().GetResult();
            }
            catch { }

            if (_ownerWindow != null)
            {
                _ownerWindow.IsEnabled = false;
                _ownerWindow.Activate();
            }
        }

        #endregion

        #region Exit & Disposal

        private static void ExecuteExit()
        {
            System.Windows.Application.Current.Shutdown();
        }

        public void Dispose()
        {
            _clockTimer.Stop();
            _theme.ThemeChanged -= OnThemeChanged;
            _localization.LanguageChanged -= OnLanguageChanged;
        }

        #endregion
    }
}