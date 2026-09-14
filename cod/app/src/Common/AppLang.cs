namespace ShouTech.App.Common
{
    public sealed class AppLang
    {
        public required string Code { get; init; }
        public required string NameAr { get; init; }

        public string Display => NameAr;

        public static IReadOnlyList<AppLang> All { get; } =
        [
            new() { Code = "ar-SY", NameAr = "العربية (سوريا)" },
            new() { Code = "ar-SA", NameAr = "العربية (السعودية)" },
            new() { Code = "ar-AE", NameAr = "العربية (الإمارات)" },
            new() { Code = "ar-EG", NameAr = "العربية (مصر)" },
            new() { Code = "en-US", NameAr = "English (US)" },
        ];
    }
}
