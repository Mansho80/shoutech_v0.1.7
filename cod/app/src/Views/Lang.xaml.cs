using System;
using System.Windows;
using System.Windows.Controls;
using ShouTech.App.Services;
using WpfApp = System.Windows.Application;

namespace ShouTech.App.Views
{
    /// <summary>
    /// First-run language picker. English default.
    /// Selecting Arabic previews full-window RTL; other languages use LTR.
    /// </summary>
    public partial class Lang : Window
    {
        public string Selected { get; private set; } = "en";

        public Lang()
        {
            InitializeComponent();
            try { ShlChrHlpr.Apply(this); } catch { }
            Loaded += OnLoaded;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            try
            {
                if (cmbLanguage != null && cmbLanguage.Items.Count > 0)
                {
                    cmbLanguage.SelectedIndex = 0;
                    if (cmbLanguage.Items[0] is ComboBoxItem first)
                    {
                        first.IsSelected = true;
                        cmbLanguage.SelectedItem = first;
                    }
                }

                Selected = "en";
                ApplyWindowDirection("en");
                cmbLanguage?.Focus();
            }
            catch
            {
                Selected = "en";
            }
        }

        private void OnLanguageSelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            try
            {
                var code = ReadSelectedCode();
                Selected = code;
                ApplyWindowDirection(code);
            }
            catch
            {
                // non-fatal
            }
        }

        /// <summary>
        /// Mirrors the entire language window for Arabic (RTL);
        /// LTR for English / French / Turkish.
        /// </summary>
        private void ApplyWindowDirection(string? languageCode)
        {
            try
            {
                LangDirSv.ApplyToWindow(this, languageCode);

                if (btnBar != null)
                {
                    btnBar.ClearValue(FrameworkElement.FlowDirectionProperty);
                    btnBar.HorizontalAlignment = HorizontalAlignment.Right;
                }

                if (btnOk != null)
                    Grid.SetColumn(btnOk, 0);
                if (btnCancel != null)
                    Grid.SetColumn(btnCancel, 2);
            }
            catch
            {
                // non-fatal
            }
        }

        private void OnOk(object sender, RoutedEventArgs e)
        {
            Selected = ReadSelectedCode();
            ApplyWindowDirection(Selected);
            SafeClose(dialogResult: true);
        }

        private void OnCancel(object sender, RoutedEventArgs e)
        {
            Selected = "en";
            SafeClose(dialogResult: false);
        }

        private string ReadSelectedCode()
        {
            try
            {
                if (cmbLanguage?.SelectedItem is ComboBoxItem item &&
                    item.Tag is string code &&
                    !string.IsNullOrWhiteSpace(code))
                {
                    return code.Trim().ToLowerInvariant();
                }

                return cmbLanguage?.SelectedIndex switch
                {
                    1 => "ar",
                    2 => "fr",
                    3 => "tr",
                    _ => "en"
                };
            }
            catch
            {
                return "en";
            }
        }

        private void SafeClose(bool dialogResult)
        {
            try { DialogResult = dialogResult; } catch { /* not a dialog */ }
            try { Close(); } catch { }

            if (!dialogResult)
            {
                try { WpfApp.Current?.Shutdown(); } catch { }
            }
        }
    }
}
