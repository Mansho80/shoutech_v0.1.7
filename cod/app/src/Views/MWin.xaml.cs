using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Ribbon;
using System.Windows.Input;
using System.Windows.Media;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Collections.Specialized;
using System.Windows.Interop;
using ShouTech.App.Configuration;
using ShouTech.App.Services;
using ShouTech.App.ViewModels;
using ShouTech.App.Localization;

namespace ShouTech.App.Views
{
    public partial class MWin : RibbonWindow
    {
        private string _currentTab = string.Empty;

        public MWin()
        {
            DataContext = new MainShVM(this);

            try
            {
                InitializeComponent();
                SourceInitialized += OnSourceInitialized;
                ApplyWindowPreferences();
                if (DataContext is MainShVM viewModel)
                    viewModel.DockedWindows.CollectionChanged += OnDockedWindowsChanged;
                SizeChanged += OnMainWindowSizeChanged;
                // The main shell always opens at the current monitor work area.
                WindowState = WindowState.Maximized;
                ApplyUiDirection();
                UpdateWindowChromeState();
                RefreshLocalizedText();
                // Apply localization keys to ribbon/menu so hardcoded Arabic XAML labels are replaced.
                try { LangDirSv.ApplyToWindow(this); } catch { /* non-fatal */ }
                try { UiLoczr.ApplyToWindow(this); } catch { /* non-fatal */ }
                AppServiceHost.Localization.LanguageChanged += OnLanguageChanged;
                StateChanged += (_, _) => UpdateWindowChromeState();
                Closed += (_, _) =>
                {
                    AppServiceHost.Localization.LanguageChanged -= OnLanguageChanged;
                    if (DataContext is MainShVM viewModel)
                    {
                        viewModel.DockedWindows.CollectionChanged -= OnDockedWindowsChanged;
                        viewModel.Dispose();
                    }
                };
            }
            catch (Exception ex)
            {
                MessageBox.Show($"خطأ: {ex.Message}", "ShouTech ERP", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }


        private void OnMainWindowSizeChanged(object sender, SizeChangedEventArgs e)
        {
            if (DataContext is MainShVM viewModel)
                viewModel.LayoutDockedWindows(InternalWindowDock.ActualWidth);
        }

        private void OnDockedWindowsChanged(object? sender, NotifyCollectionChangedEventArgs e)
        {
            if (DataContext is not MainShVM viewModel)
                return;

            InternalWindowDock.Visibility = viewModel.DockedWindows.Count > 0
                ? Visibility.Visible
                : Visibility.Collapsed;

            Dispatcher.BeginInvoke(new Action(() =>
                viewModel.LayoutDockedWindows(InternalWindowDock.ActualWidth)));
        }

        private void OnLanguageChanged(object? sender, EventArgs e)
        {
            try { LangDirSv.ApplyToWindow(this); } catch { }
            ApplyUiDirection();
            RefreshLocalizedText();
            try { UiLoczr.ApplyToWindow(this); } catch { }
        }


        private void ApplyUiDirection()
        {
            var direction = LanguageDirectionService.GetFlowDirection(
                AppHost.Localization.GetCurrentLanguage());

            FlowDirection = direction;
            MainMenu.FlowDirection = direction;
            MainToolBar.FlowDirection = direction;
            RibbonControl.FlowDirection = direction;
            MainStatusBar.FlowDirection = direction;
        }

        private void OnTitleBarMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            if (e.ChangedButton != MouseButton.Left)
                return;

            if (e.OriginalSource is DependencyObject source &&
                FindAncestor<Button>(source) is not null)
            {
                return;
            }

            var pointer = e.GetPosition(this);

            if (e.ClickCount == 2)
            {
                ToggleWindowState();
                return;
            }

            // Match native Windows behavior: dragging the top edge of a maximized
            // window restores it and keeps the pointer attached to the same spot.
            if (WindowState == WindowState.Maximized)
            {
                var screenPoint = PointToScreen(pointer);
                var restore = RestoreBounds;
                var restoreWidth = restore.Width > 0 ? restore.Width : 1200;
                var restoreHeight = restore.Height > 0 ? restore.Height : 700;
                var ratioX = ActualWidth > 0 ? pointer.X / ActualWidth : 0.5;
                var grabY = Math.Max(0, Math.Min(pointer.Y, 34));

                WindowState = WindowState.Normal;
                Width = restoreWidth;
                Height = restoreHeight;
                Left = screenPoint.X - (restoreWidth * ratioX);
                Top = screenPoint.Y - grabY;
            }

            try
            {
                DragMove();
            }
            catch (InvalidOperationException)
            {
                // DragMove can fail during shutdown or a state transition.
            }
        }

        private static T? FindAncestor<T>(DependencyObject? element)
            where T : DependencyObject
        {
            var current = element;

            while (current is not null)
            {
                if (current is T match)
                    return match;

                current = System.Windows.Media.VisualTreeHelper.GetParent(current);
            }

            return null;
        }

        private void OnMinimizeClick(object sender, RoutedEventArgs e)
        {
            WindowState = WindowState.Minimized;
        }

        private void OnMaximizeClick(object sender, RoutedEventArgs e)
        {
            ToggleWindowState();
        }

        private void OnCloseClick(object sender, RoutedEventArgs e)
        {
            Close();
        }

        private void ToggleWindowState()
        {
            WindowState = WindowState == WindowState.Maximized
                ? WindowState.Normal
                : WindowState.Maximized;

            UpdateWindowChromeState();
        }

        private void UpdateWindowChromeState()
        {
            if (MaximizeButton == null)
                return;

            var maximized = WindowState == WindowState.Maximized;
            MaximizeButton.Content = maximized ? "❐" : "□";
            MaximizeButton.ToolTip = maximized ? "استعادة" : "تكبير";
        }

        /// <summary>
        /// تحديث نصوص القائمة الرئيسية حسب اللغة الحالية.
        /// يعتمد على مفاتيح Menu.* الموجودة أصلاً في ملفات الترجمة (Ar/En/Fr/Tr.json).
        /// </summary>
        private void RefreshLocalizedText()
        {
            string L(string key, string fallback) => AppServiceHost.Localization.GetString($"Menu.{key}", fallback);

            if (MenuFile != null) MenuFile.Header = L("File", "ملف");
            if (MenuInventory != null) MenuInventory.Header = L("Inventory", "مستودعات");
            if (MenuAccounts != null) MenuAccounts.Header = L("Accounts", "حسابات");
            if (MenuBonds != null) MenuBonds.Header = L("Bonds", "سندات");
            if (MenuInvoices != null) MenuInvoices.Header = L("Invoices", "فواتير");
            if (MenuPOS != null) MenuPOS.Header = L("POS", "نقاط بيع");
            if (MenuOrders != null) MenuOrders.Header = L("Orders", "طلبيات");
            if (MenuCustomers != null) MenuCustomers.Header = L("Customers", "عملاء");
            if (MenuSalesRep != null) MenuSalesRep.Header = L("SalesRep", "مندوب");
            if (MenuManufacturing != null) MenuManufacturing.Header = L("Manufacturing", "تصنيع");
            if (MenuBanks != null) MenuBanks.Header = L("Banks", "بنوك");
            if (MenuReports != null) MenuReports.Header = L("Reports", "تقارير");
            if (MenuTools != null) MenuTools.Header = L("Tools", "أدوات");
            if (MenuOtherTools != null) MenuOtherTools.Header = L("OtherTools", "أدوات أخرى");
            if (MenuView != null) MenuView.Header = L("View", "عرض");
            if (MenuExit != null) MenuExit.Header = L("Exit", "خروج");
            if (MenuHelp != null) MenuHelp.Header = L("Help", "مساعدة");
        }

        private void ApplyWindowPreferences()
        {
            try
            {
                var pref = UsrPref.Load();
                pref.ApplyToWindow(this);
            }
            catch
            {
                // Non-fatal
            }
        }

        protected override void OnClosed(EventArgs e)
        {
            try
            {
                var pref = UsrPref.Load();
                pref.SaveFromWindow(this);
                pref.Save();
            }
            catch
            {
                // Non-fatal
            }

            base.OnClosed(e);
        }

        private void OnSourceInitialized(object? sender, EventArgs e)
        {
            var source = PresentationSource.FromVisual(this) as HwndSource;
            source?.AddHook(WindowProc);
        }

        private static IntPtr WindowProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            const int WM_GETMINMAXINFO = 0x0024;
            const int MONITOR_DEFAULTTONEAREST = 0x00000002;

            if (msg != WM_GETMINMAXINFO)
                return IntPtr.Zero;

            var monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
            if (monitor == IntPtr.Zero)
                return IntPtr.Zero;

            var info = new MONITORINFO { cbSize = Marshal.SizeOf<MONITORINFO>() };
            if (!GetMonitorInfo(monitor, ref info))
                return IntPtr.Zero;

            var mmi = Marshal.PtrToStructure<MINMAXINFO>(lParam);
            mmi.ptMaxPosition.X = info.rcWork.Left - info.rcMonitor.Left;
            mmi.ptMaxPosition.Y = info.rcWork.Top - info.rcMonitor.Top;
            mmi.ptMaxSize.X = info.rcWork.Right - info.rcWork.Left;
            mmi.ptMaxSize.Y = info.rcWork.Bottom - info.rcWork.Top;
            mmi.ptMaxTrackSize.X = mmi.ptMaxSize.X;
            mmi.ptMaxTrackSize.Y = mmi.ptMaxSize.Y;
            Marshal.StructureToPtr(mmi, lParam, false);
            handled = true;
            return IntPtr.Zero;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int X; public int Y; }

        [StructLayout(LayoutKind.Sequential)]
        private struct MINMAXINFO
        {
            public POINT ptReserved;
            public POINT ptMaxSize;
            public POINT ptMaxPosition;
            public POINT ptMinTrackSize;
            public POINT ptMaxTrackSize;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        private struct MONITORINFO
        {
            public int cbSize;
            public RECT rcMonitor;
            public RECT rcWork;
            public uint dwFlags;
        }

        [DllImport("user32.dll")]
        private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint dwFlags);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        private static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);

        private void ShowRibbonTab(string tabName)
        {
            if (RibbonControl == null)
                return;

            foreach (RibbonTab tab in RibbonControl.Items)
                tab.Visibility = Visibility.Collapsed;

            if (_currentTab == tabName && RibbonControl.Visibility == Visibility.Visible)
            {
                RibbonControl.Visibility = Visibility.Collapsed;
                _currentTab = string.Empty;
                return;
            }

            if (FindName(tabName) is RibbonTab selectedTab)
            {
                selectedTab.Visibility = Visibility.Visible;
                selectedTab.IsSelected = true;
                RibbonControl.Visibility = Visibility.Visible;
                _currentTab = tabName;
            }
        }

        private void OnMenuFileClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabFile");
        private void OnMenuInventoryClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabInventory");
        private void OnMenuAccountsClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabAccounts");
        private void OnMenuBondsClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabBonds");
        private void OnMenuInvoicesClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabInvoices");
        private void OnMenuPOSClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabPOS");
        private void OnMenuOrdersClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabOrders");
        private void OnMenuCustomersClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabCustomers");
        private void OnMenuSalesRepClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabSalesRep");
        private void OnMenuManufacturingClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabManufacturing");
        private void OnMenuBanksClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabBanks");
        private void OnMenuReportsClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabReports");
        private void OnMenuToolsClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabTools");
        private void OnMenuOtherToolsClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabOtherTools");
        private void OnMenuViewClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabView");
        private void OnMenuExitClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabExit");
        private void OnMenuHelpClick(object sender, RoutedEventArgs e) => ShowRibbonTab("TabHelp");

        internal void FreezeForCompanySwitch()
        {
            // Keep the shell window visible. Only File -> Open remains interactive.
            MinimizeButton.IsEnabled = false;
            MaximizeButton.IsEnabled = false;
            CloseButton.IsEnabled = false;

            MainToolBar.IsEnabled = false;
            MainMenu.IsEnabled = false;

            foreach (var item in MainMenu.Items.OfType<MenuItem>())
                item.IsEnabled = false;

            foreach (var tab in RibbonControl.Items.OfType<RibbonTab>())
                tab.IsEnabled = ReferenceEquals(tab, TabFile);

            RibbonControl.IsEnabled = true;
            RibbonControl.Visibility = Visibility.Visible;
            foreach (var group in TabFile.Items.OfType<RibbonGroup>())
            {
                foreach (var button in GetVisualDescendants<RibbonButton>(group))
                    button.IsEnabled = ReferenceEquals(button, RibbonOpenCompanyButton);
            }

            TabFile.Visibility = Visibility.Visible;
            TabFile.IsSelected = true;

            // Freeze the operational/content surface and internal dock.
            if (Content is Grid root)
            {
                foreach (UIElement child in root.Children)
                {
                    var row = Grid.GetRow(child);
                    if (row >= 4)
                        child.IsEnabled = false;
                }
            }

            MainStatusBar.IsEnabled = false;
            InternalWindowDock.IsEnabled = false;
        }

        internal void UnfreezeAfterCompanyLogin()
        {
            MinimizeButton.IsEnabled = true;
            MaximizeButton.IsEnabled = true;
            CloseButton.IsEnabled = true;
            MainMenu.IsEnabled = true;
            MainToolBar.IsEnabled = true;
            RibbonControl.IsEnabled = true;
            MainStatusBar.IsEnabled = true;
            InternalWindowDock.IsEnabled = true;

            foreach (var item in MainMenu.Items.OfType<MenuItem>())
                item.IsEnabled = true;

            foreach (var tab in RibbonControl.Items.OfType<RibbonTab>())
                tab.IsEnabled = true;

            foreach (var button in GetVisualDescendants<RibbonButton>(RibbonControl))
                button.IsEnabled = true;

            RibbonControl.Visibility = Visibility.Collapsed;
            _currentTab = string.Empty;

            if (Content is Grid root)
            {
                foreach (UIElement child in root.Children)
                {
                    var row = Grid.GetRow(child);
                    if (row >= 4)
                        child.IsEnabled = true;
                }
            }
        }

        private static IEnumerable<T> GetVisualDescendants<T>(DependencyObject root)
            where T : DependencyObject
        {
            if (root == null) yield break;

            for (var i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
            {
                var child = VisualTreeHelper.GetChild(root, i);
                if (child is T match)
                    yield return match;

                foreach (var descendant in GetVisualDescendants<T>(child))
                    yield return descendant;
            }
        }

        private void OnRibbonButtonClick(object sender, RoutedEventArgs e)
        {
            CollapseRibbon();

            if (sender is not RibbonButton button)
                return;

            var tab = FindParentRibbonTab(button);
            if (DataContext is MainShVM viewModel)
                viewModel.HandleRibbonAction(button.Label, null, tab?.Name, tab?.Header?.ToString());
        }

        private void CollapseRibbon()
        {
            if (RibbonControl == null)
                return;

            RibbonControl.Visibility = Visibility.Collapsed;
            _currentTab = string.Empty;
        }

        private static RibbonTab? FindParentRibbonTab(DependencyObject? child)
        {
            while (child != null)
            {
                if (child is RibbonTab tab)
                    return tab;

                child = System.Windows.Media.VisualTreeHelper.GetParent(child);
            }

            return null;
        }

        private void SwitchLanguage(string languageCode)
        {
            try
            {
                var code = ShouTech.App.Services.LanguageDirectionService.NormalizeLanguageCode(languageCode);
                if (string.IsNullOrWhiteSpace(code))
                    return;

                // Apply language safely (culture + resources + deferred UI).
                App.SetApplicationLanguage(code);

                try
                {
                    var pref = UsrPref.Load();
                    pref.Lang = code;
                    pref.LangSet = true;
                    pref.Save();
                }
                catch
                {
                    // حفظ التفضيل غير حرج؛ اللغة مطبّقة بالفعل على الجلسة الحالية
                }

                // Refresh menu headers on this window after deferred culture switch.
                Dispatcher.BeginInvoke(
                    System.Windows.Threading.DispatcherPriority.Background,
                    new System.Action(RefreshLocalizedText));
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    $"تعذر تبديل اللغة: {ex.Message}",
                    "ShouTech ERP",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
            }
        }

        private void OnLanguageArabicClick(object sender, RoutedEventArgs e) => SwitchLanguage("ar");
        private void OnLanguageEnglishClick(object sender, RoutedEventArgs e) => SwitchLanguage("en");
        private void OnLanguageFrenchClick(object sender, RoutedEventArgs e) => SwitchLanguage("fr");
        private void OnLanguageTurkishClick(object sender, RoutedEventArgs e) => SwitchLanguage("tr");
    }
}
