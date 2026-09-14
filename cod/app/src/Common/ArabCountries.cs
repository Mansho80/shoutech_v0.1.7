namespace ShouTech.App.Common
{
    public sealed class ArabCountry
    {
        public required string Code { get; init; }
        public required string NameAr { get; init; }
        public required string NameEn { get; init; }

        public string Display => NameAr;

        public static IReadOnlyList<ArabCountry> All { get; } =
        [
            new() { Code = "SY", NameAr = "سوريا", NameEn = "Syria" },
            new() { Code = "SA", NameAr = "المملكة العربية السعودية", NameEn = "Saudi Arabia" },
            new() { Code = "AE", NameAr = "الإمارات العربية المتحدة", NameEn = "United Arab Emirates" },
            new() { Code = "KW", NameAr = "الكويت", NameEn = "Kuwait" },
            new() { Code = "QA", NameAr = "قطر", NameEn = "Qatar" },
            new() { Code = "BH", NameAr = "البحرين", NameEn = "Bahrain" },
            new() { Code = "OM", NameAr = "عُمان", NameEn = "Oman" },
            new() { Code = "JO", NameAr = "الأردن", NameEn = "Jordan" },
            new() { Code = "EG", NameAr = "مصر", NameEn = "Egypt" },
            new() { Code = "IQ", NameAr = "العراق", NameEn = "Iraq" },
            new() { Code = "LB", NameAr = "لبنان", NameEn = "Lebanon" },
            new() { Code = "MA", NameAr = "المغرب", NameEn = "Morocco" },
            new() { Code = "TN", NameAr = "تونس", NameEn = "Tunisia" },
            new() { Code = "DZ", NameAr = "الجزائر", NameEn = "Algeria" },
            new() { Code = "YE", NameAr = "اليمن", NameEn = "Yemen" },
            new() { Code = "LY", NameAr = "ليبيا", NameEn = "Libya" },
            new() { Code = "SD", NameAr = "السودان", NameEn = "Sudan" },
            new() { Code = "PS", NameAr = "فلسطين", NameEn = "Palestine" },
            new() { Code = "TR", NameAr = "تركيا", NameEn = "Turkey" },
        ];
    }
}
