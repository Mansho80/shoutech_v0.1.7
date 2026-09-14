using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;

using ShouTech.App.Services;

namespace ShouTech.App.Converters
{
    public class LangFlwCv : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            var lang = value?.ToString()?.ToLowerInvariant() ?? LangDirSv.DefaultLanguageCode;
            return LangDirSv.IsRtl(lang)
                ? FlowDirection.RightToLeft
                : FlowDirection.LeftToRight;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
            => throw new NotSupportedException();
    }
}