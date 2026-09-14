using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Controls.Ribbon;
using System.Windows.Documents;
using ShouTech.App.Services;
using WpfApp = System.Windows.Application;

namespace ShouTech.App.Localization
{
    /// <summary>
    /// Applies localized strings to open windows when the language changes.
    /// </summary>
    public static class UiLoczr
    {
        private static bool _initialized;

        private static readonly Dictionary<string, string> RibbonTabKeys = new()
        {
            ["TabFile"] = "Menu.File",
            ["TabInventory"] = "Menu.Inventory",
            ["TabAccounts"] = "Menu.Accounts",
            ["TabBonds"] = "Menu.Bonds",
            ["TabInvoices"] = "Menu.Invoices",
            ["TabPOS"] = "Menu.POS",
            ["TabOrders"] = "Menu.Orders",
            ["TabCustomers"] = "Menu.Customers",
            ["TabSalesRep"] = "Menu.SalesRep",
            ["TabManufacturing"] = "Menu.Manufacturing",
            ["TabBanks"] = "Menu.Banks",
            ["TabReports"] = "Menu.Reports",
            ["TabTools"] = "Menu.Tools",
            ["TabOtherTools"] = "Menu.OtherTools",
            ["TabView"] = "Menu.View",
            ["TabExit"] = "Menu.Exit",
            ["TabHelp"] = "Menu.Help"
        };

        public static void Initialize(ILocSvc localization)
        {
            if (_initialized)
                return;

            localization.LanguageChanged += (_, _) => ScheduleApplyToAllWindows();
            _initialized = true;
        }

        public static void ScheduleApplyToAllWindows()
        {
            if (WpfApp.Current?.Dispatcher == null)
            {
                ApplyToAllWindows();
                return;
            }

            WpfApp.Current.Dispatcher.BeginInvoke(
                System.Windows.Threading.DispatcherPriority.Loaded,
                new System.Action(ApplyToAllWindows));
        }

        public static void ApplyToAllWindows()
        {
            if (WpfApp.Current == null)
                return;

            // Per-window isolation: one failed window must not abort the rest.
            foreach (Window window in WpfApp.Current.Windows)
            {
                try { ApplyToWindow(window); }
                catch { /* non-fatal localization pass */ }
            }
        }

        public static void ApplyToWindow(Window window) => ApplyToRoot(window);

        public static void ApplyToRoot(DependencyObject root)
        {
            var localization = ResolveLocalization();
            if (localization == null)
                return;

            if (root is Window window)
            {
                var windowKey = LocProps.GetWindowKey(window);
                if (!string.IsNullOrWhiteSpace(windowKey))
                    window.Title = localization.GetString(windowKey, window.Title ?? string.Empty);
            }

            WalkTree(root, localization);
        }

        private static void WalkTree(DependencyObject parent, ILocSvc localization)
        {
            ApplyElement(parent, localization);

            foreach (var child in GetLogicalChildren(parent))
                WalkTree(child, localization);
        }

        private static IEnumerable<DependencyObject> GetLogicalChildren(DependencyObject parent)
        {
            if (parent is Ribbon ribbon)
            {
                foreach (var item in ribbon.Items)
                {
                    if (item is DependencyObject ribbonItem)
                        yield return ribbonItem;
                }

                yield break;
            }

            foreach (var child in LogicalTreeHelper.GetChildren(parent))
            {
                if (child is DependencyObject dependencyObject)
                    yield return dependencyObject;
            }
        }

        private static void ApplyElement(DependencyObject element, ILocSvc localization)
        {
            switch (element)
            {
                case RibbonTab tab when tab.Name is { Length: > 0 } name && RibbonTabKeys.TryGetValue(name, out var tabInfo):
                    tab.Header = localization.GetString(tabInfo, tabInfo);
                    break;

                case RibbonGroup group:
                    ApplyRibbonGroup(group, localization);
                    break;

                case RibbonButton ribbonButton:
                    ApplyRibbonButton(ribbonButton, localization);
                    break;

                case MenuItem menuItem:
                    ApplyMenuItem(menuItem, localization);
                    break;

                case TextBlock textBlock:
                    ApplyTextBlock(textBlock, localization);
                    break;

                case Button button:
                    ApplyButton(button, localization);
                    break;
            }
        }

        private static void ApplyRibbonGroup(RibbonGroup group, ILocSvc localization)
        {
            var key = ResolveElementKey(group, localization, group.Header?.ToString());
            if (string.IsNullOrWhiteSpace(key))
                return;

            group.Tag = key;
            group.Header = localization.GetString(key, group.Header?.ToString() ?? key);
        }

        private static void ApplyRibbonButton(RibbonButton button, ILocSvc localization)
        {
            var key = ResolveElementKey(button, localization, button.Label);
            if (string.IsNullOrWhiteSpace(key))
                return;

            button.Tag = key;
            button.Label = localization.GetString(key, button.Label ?? key);
        }

        private static void ApplyMenuItem(MenuItem menuItem, ILocSvc localization)
        {
            var key = LocProps.GetKey(menuItem);
            if (string.IsNullOrWhiteSpace(key))
                return;

            menuItem.Header = localization.GetString(key, menuItem.Header?.ToString() ?? key);
        }

        private static void ApplyTextBlock(TextBlock textBlock, ILocSvc localization)
        {
            var key = LocProps.GetKey(textBlock);
            if (string.IsNullOrWhiteSpace(key))
                return;

            textBlock.Text = localization.GetString(key, textBlock.Text);
        }

        private static void ApplyButton(Button button, ILocSvc localization)
        {
            var toolTipKey = LocProps.GetToolTipKey(button);
            if (!string.IsNullOrWhiteSpace(toolTipKey))
                button.ToolTip = localization.GetString(toolTipKey, button.ToolTip?.ToString() ?? toolTipKey);

            var key = LocProps.GetKey(button);
            if (!string.IsNullOrWhiteSpace(key))
                button.Content = localization.GetString(key, button.Content?.ToString() ?? key);
        }

        private static string? ResolveElementKey(FrameworkElement element, ILocSvc localization, string? currentText)
        {
            if (element.Tag is string tagKey && !string.IsNullOrWhiteSpace(tagKey))
                return tagKey;

            var attachedKey = LocProps.GetKey(element);
            if (!string.IsNullOrWhiteSpace(attachedKey))
                return attachedKey;

            if (localization is LocSvc svc && !string.IsNullOrWhiteSpace(currentText))
            {
                if (svc.TryResolveKeyFromArabicLabel(currentText, out var resolved))
                    return resolved;
            }

            return null;
        }


        private static ILocSvc? ResolveLocalization()
        {
            if (WpfApp.Current is App app)
                return app.Localization;

            return AppHost.Localization;
        }
    }
}
