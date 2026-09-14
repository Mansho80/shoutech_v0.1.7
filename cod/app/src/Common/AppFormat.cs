using System.Globalization;

namespace ShouTech.App.Common
{
    internal static class AppFormat
    {
        public static readonly CultureInfo Invariant = CultureInfo.InvariantCulture;

        public static string FormatTime(System.DateTime value) =>
            value.ToString("HH:mm:ss", Invariant);

        public static string FormatDate(System.DateTime value) =>
            value.ToString("dd/MM/yyyy", Invariant);

        public static string FormatDateTime(System.DateTime value) =>
            value.ToString("G", Invariant);

        public static string FormatTimestamp(System.DateTime value) =>
            value.ToString("yyyyMMdd_HHmmss", Invariant);

        public static string FormatNumber(int value) =>
            value.ToString("N0", Invariant);

        public static string Format(string format, object? arg0) =>
            string.Format(Invariant, format, arg0);
    }
}
