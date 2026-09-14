using System.Windows;

namespace ShouTech.App.Localization
{
    /// <summary>
    /// Attached properties for declarative UI localization keys.
    /// </summary>
    public static class LocProps
    {
        public static readonly DependencyProperty KeyProperty =
            DependencyProperty.RegisterAttached(
                "Key",
                typeof(string),
                typeof(LocProps),
                new PropertyMetadata(null));

        public static readonly DependencyProperty IconProperty =
            DependencyProperty.RegisterAttached(
                "Icon",
                typeof(string),
                typeof(LocProps),
                new PropertyMetadata(null));

        public static readonly DependencyProperty ToolTipKeyProperty =
            DependencyProperty.RegisterAttached(
                "ToolTipKey",
                typeof(string),
                typeof(LocProps),
                new PropertyMetadata(null));

        public static readonly DependencyProperty WindowKeyProperty =
            DependencyProperty.RegisterAttached(
                "WindowKey",
                typeof(string),
                typeof(LocProps),
                new PropertyMetadata(null));

        public static void SetKey(DependencyObject element, string? value) => element.SetValue(KeyProperty, value);
        public static string? GetKey(DependencyObject element) => (string?)element.GetValue(KeyProperty);

        public static void SetIcon(DependencyObject element, string? value) => element.SetValue(IconProperty, value);
        public static string? GetIcon(DependencyObject element) => (string?)element.GetValue(IconProperty);

        public static void SetToolTipKey(DependencyObject element, string? value) => element.SetValue(ToolTipKeyProperty, value);
        public static string? GetToolTipKey(DependencyObject element) => (string?)element.GetValue(ToolTipKeyProperty);

        public static void SetWindowKey(DependencyObject element, string? value) => element.SetValue(WindowKeyProperty, value);
        public static string? GetWindowKey(DependencyObject element) => (string?)element.GetValue(WindowKeyProperty);
    }
}
