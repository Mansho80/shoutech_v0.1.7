using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading;
using System.Windows;
using System.Windows.Markup;

namespace ShouTech.App.Services
{
    public static class LangDirSv
    {
        private static readonly HashSet<string> RtlLanguageCodes = new(StringComparer.OrdinalIgnoreCase)
        {
            "ar", "ku", "he", "fa", "ur"
        };

        public const string DefaultLanguageCode = "en";

        public static bool IsRtl(string? languageCode)
        {
            if (string.IsNullOrWhiteSpace(languageCode))
                return false;

            var code = languageCode.Split('-')[0];
            return RtlLanguageCodes.Contains(code);
        }

        public static FlowDirection GetFlowDirection(string? languageCode)
            => IsRtl(languageCode) ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;

        public static void ApplyCulture(string languageCode)
        {
            var normalized = NormalizeLanguageCode(languageCode);
            try
            {
                var culture = CultureInfo.GetCultureInfo(normalized);
                Thread.CurrentThread.CurrentCulture = culture;
                Thread.CurrentThread.CurrentUICulture = culture;
                CultureInfo.DefaultThreadCurrentCulture = culture;
                CultureInfo.DefaultThreadCurrentUICulture = culture;
            }
            catch (CultureNotFoundException)
            {
                // Keep previous culture — never crash on unsupported OS locale packs.
            }
        }

        public static void ApplyToWindow(Window window, string? languageCode = null)
        {
            var code = languageCode ?? App.CurrentLanguageCode;
            window.FlowDirection = GetFlowDirection(code);

            try
            {
                var culture = CultureInfo.GetCultureInfo(NormalizeLanguageCode(code));
                window.Language = XmlLanguage.GetLanguage(culture.IetfLanguageTag);
            }
            catch (CultureNotFoundException)
            {
                // Keep existing window language if culture code is invalid.
            }
        }

        public static void ApplyToAllWindows(string languageCode)
        {
            if (System.Windows.Application.Current is null)
                return;

            foreach (Window window in System.Windows.Application.Current.Windows)
            {
                try { ApplyToWindow(window, languageCode); }
                catch { /* avoid layout re-entrancy crash on a single window */ }
            }
        }

        public static string NormalizeLanguageCode(string? languageCode)
        {
            if (string.IsNullOrWhiteSpace(languageCode))
                return DefaultLanguageCode;

            return languageCode.Split('-')[0].ToLowerInvariant();
        }
    }
}
