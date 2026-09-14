using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Controls.Ribbon;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shell;
using WpfApp = System.Windows.Application;

namespace ShouTech.App.Services
{
    /// <summary>
    /// Applies the shared ShouTech visual shell and seamless custom window chrome.
    /// The chrome intentionally uses the same theme surface as the window content.
    /// </summary>
    public static class ShlChrHlpr
    {
        private const double ChromeHeight = 34d;
        private const string ChromeInstalledKey = "ShouTech.ChromeInstalled";

        public static void Apply(Window? window)
        {
            if (window == null)
                return;

            ApplySharedSurface(window);
            ApplyCustomChrome(window);
            ApplyTitleBarTheme(window);

            if (window.FindName("RibbonControl") is Ribbon ribbon)
                ClearRibbonLocalThemeOverrides(ribbon);
        }

        private static void ApplySharedSurface(Window window)
        {
            window.SetResourceReference(Window.BackgroundProperty, "BackgroundBrush");
            window.SetResourceReference(Window.ForegroundProperty, "TextBrush");
        }

        private static void ApplyCustomChrome(Window window)
        {
            if (window.FindName("WindowChromeBar") is FrameworkElement)
                return;

            if (window.Resources[ChromeInstalledKey] is bool installed && installed)
                return;

            if (window.IsLoaded)
                return;

            if (window.Content is not UIElement originalContent)
                return;

            window.Content = null;

            var root = new Grid
            {
                Background = ResolveBrush(window, "BackgroundBrush")
            };
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(ChromeHeight) });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

            var chrome = BuildTitleBar(window);
            Grid.SetRow(chrome, 0);

            Grid.SetRow(originalContent, 1);
            root.Children.Add(chrome);
            root.Children.Add(originalContent);

            window.Content = root;
            window.WindowStyle = WindowStyle.None;
            window.ResizeMode = ResizeMode.CanResize;
            // AllowsTransparency is immutable after the native window handle is created.
            // Every ShouTech window declares it before Show(); never mutate it here.
            WindowChrome.SetWindowChrome(window, CreateWindowChrome());
            window.Resources[ChromeInstalledKey] = true;
        }

        private static Grid BuildTitleBar(Window window)
        {
            var bar = new Grid
            {
                Height = ChromeHeight,
                Background = ResolveBrush(window, "BackgroundBrush"),
                FlowDirection = FlowDirection.LeftToRight
            };
            bar.MouseLeftButtonDown += OnTitleBarMouseLeftButtonDown;

            bar.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            bar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var title = new TextBlock
            {
                Text = window.Title,
                Foreground = ResolveBrush(window, "TextBrush"),
                FontFamily = new System.Windows.Media.FontFamily("Tahoma"),
                FontSize = 13,
                FontWeight = FontWeights.SemiBold,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(12, 0, 8, 0)
            };
            Grid.SetColumn(title, 0);
            bar.Children.Add(title);

            var buttons = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                VerticalAlignment = VerticalAlignment.Stretch
            };
            Grid.SetColumn(buttons, 1);

            buttons.Children.Add(CreateWindowButton(window, "─", "تصغير", OnMinimizeClick));
            buttons.Children.Add(CreateWindowButton(window, "□", "تكبير", OnMaximizeClick));
            buttons.Children.Add(CreateWindowButton(window, "×", "إغلاق", OnCloseClick, true));
            bar.Children.Add(buttons);

            window.StateChanged += (_, _) => UpdateMaximizeButton(window, buttons.Children[1] as Button);
            window.SizeChanged += (_, _) => UpdateMaximizeButton(window, buttons.Children[1] as Button);

            return bar;
        }

        private static Button CreateWindowButton(Window window, string content, string tooltip,
            RoutedEventHandler click, bool close = false)
        {
            var button = new Button
            {
                Width = 46,
                Height = ChromeHeight,
                Padding = new Thickness(0),
                BorderThickness = new Thickness(0),
                Background = Brushes.Transparent,
                Foreground = ResolveBrush(window, "TextBrush"),
                FontFamily = new System.Windows.Media.FontFamily("Segoe UI Symbol"),
                FontSize = 14,
                Content = content,
                ToolTip = tooltip,
                Cursor = Cursors.Hand
            };

            button.Click += click;

            // The custom title bar lives inside WindowChrome\'s caption area.
            // Explicitly mark caption buttons as hit-testable client elements so
            // their Click events are not swallowed by the native non-client frame.
            WindowChrome.SetIsHitTestVisibleInChrome(button, true);

            var template = new ControlTemplate(typeof(Button));
            var border = new FrameworkElementFactory(typeof(Border));
            border.Name = "ChromeButtonBorder";
            border.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Control.BackgroundProperty));

            var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
            presenter.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            presenter.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            presenter.SetValue(TextElement.ForegroundProperty, new TemplateBindingExtension(Control.ForegroundProperty));
            border.AppendChild(presenter);
            template.VisualTree = border;

            var hover = new Trigger { Property = UIElement.IsMouseOverProperty, Value = true };
            hover.Setters.Add(new Setter(Border.BackgroundProperty,
                close ? new SolidColorBrush(Color.FromRgb(196, 43, 28)) : ResolveBrush(window, "ShellRibbonHoverBrush"),
                "ChromeButtonBorder"));
            if (close)
                hover.Setters.Add(new Setter(Control.ForegroundProperty, Brushes.White));
            template.Triggers.Add(hover);
            button.Template = template;

            return button;
        }

        private static void UpdateMaximizeButton(Window window, Button? button)
        {
            if (button == null)
                return;

            var maximized = window.WindowState == WindowState.Maximized;
            button.Content = maximized ? "❐" : "□";
            button.ToolTip = maximized ? "استعادة" : "تكبير";
        }

        private static void OnTitleBarMouseLeftButtonDown(object? sender, MouseButtonEventArgs e)
        {
            if (sender is not FrameworkElement element || e.ChangedButton != MouseButton.Left)
                return;

            // Native-style caption buttons must never bubble into DragMove().
            if (FindAncestor<Button>(e.OriginalSource as DependencyObject) is not null)
                return;

            if (element.TemplatedParent is Window window)
            {
                if (e.ClickCount == 2)
                {
                    ToggleWindowState(window);
                    return;
                }

                if (window.WindowState != WindowState.Maximized)
                {
                    try { window.DragMove(); } catch (InvalidOperationException) { }
                }
            }
            else if (Window.GetWindow(element) is Window owner)
            {
                if (e.ClickCount == 2)
                {
                    ToggleWindowState(owner);
                    return;
                }

                if (owner.WindowState != WindowState.Maximized)
                {
                    try { owner.DragMove(); } catch (InvalidOperationException) { }
                }
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

                current = VisualTreeHelper.GetParent(current);
            }

            return null;
        }

        private static void OnMinimizeClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button button && Window.GetWindow(button) is Window window)
                window.WindowState = WindowState.Minimized;
        }

        private static void OnMaximizeClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button button && Window.GetWindow(button) is Window window)
                ToggleWindowState(window);
        }

        private static void OnCloseClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button button && Window.GetWindow(button) is Window window)
                window.Close();
        }

        private static void ToggleWindowState(Window window)
        {
            window.WindowState = window.WindowState == WindowState.Maximized
                ? WindowState.Normal
                : WindowState.Maximized;
        }

        private static WindowChrome CreateWindowChrome() => new()
        {
            CaptionHeight = ChromeHeight,
            ResizeBorderThickness = new Thickness(6),
            GlassFrameThickness = new Thickness(0),
            CornerRadius = new CornerRadius(0),
            UseAeroCaptionButtons = false
        };

        private static Brush ResolveBrush(FrameworkElement element, string key)
        {
            return element.TryFindResource(key) as Brush
                   ?? Brushes.Transparent;
        }

        private static void ClearRibbonLocalThemeOverrides(DependencyObject root)
        {
            switch (root)
            {
                case Ribbon ribbon:
                    ribbon.ClearValue(Control.BackgroundProperty);
                    ribbon.ClearValue(Control.ForegroundProperty);
                    ribbon.ClearValue(Control.BorderBrushProperty);
                    ribbon.ClearValue(Ribbon.MouseOverBackgroundProperty);
                    ribbon.ClearValue(Ribbon.PressedBackgroundProperty);
                    ribbon.ClearValue(Ribbon.CheckedBackgroundProperty);
                    ribbon.ClearValue(Ribbon.FocusedBackgroundProperty);
                    break;
                case RibbonTab tab:
                    tab.ClearValue(Control.BackgroundProperty);
                    tab.ClearValue(Control.ForegroundProperty);
                    break;
                case RibbonGroup group:
                    group.ClearValue(Control.BackgroundProperty);
                    group.ClearValue(Control.ForegroundProperty);
                    break;
                case RibbonButton button:
                    button.ClearValue(Control.BackgroundProperty);
                    button.ClearValue(Control.ForegroundProperty);
                    break;
            }

            var childCount = VisualTreeHelper.GetChildrenCount(root);
            for (var i = 0; i < childCount; i++)
                ClearRibbonLocalThemeOverrides(VisualTreeHelper.GetChild(root, i));
        }

        private static void ApplyTitleBarTheme(Window window)
        {
            if (!OperatingSystem.IsWindows())
                return;

            var handle = new WindowInteropHelper(window).Handle;
            if (handle == IntPtr.Zero)
                return;

            var useDark = IsLightTheme() ? 0 : 1;
            var attr20Result = DwmSetWindowAttribute(handle, 20, ref useDark, sizeof(int));
            if (attr20Result != 0)
                _ = DwmSetWindowAttribute(handle, 19, ref useDark, sizeof(int));
        }

        private static bool IsLightTheme()
        {
            return WpfApp.Current?.TryFindResource("ThemeName") is string theme
                && theme.Equals("Light", StringComparison.OrdinalIgnoreCase);
        }

        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int pvAttribute, int cbAttribute);
    }
}
