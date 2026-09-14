namespace ShouTech.App.Common
{
    public sealed class ArabCurr
    {
        public required string Code { get; init; }
        public required string NameAr { get; init; }
        public required string Symbol { get; init; }

        public string Display => $"{NameAr} ({Code})";

        public static IReadOnlyList<ArabCurr> All { get; } =
        [
            new() { Code = "SYP", NameAr = "ليرة سورية", Symbol = "ل.س" },
            new() { Code = "SAR", NameAr = "ريال سعودي", Symbol = "ر.س" },
            new() { Code = "AED", NameAr = "درهم إماراتي", Symbol = "د.إ" },
            new() { Code = "KWD", NameAr = "دينار كويتي", Symbol = "د.ك" },
            new() { Code = "QAR", NameAr = "ريال قطري", Symbol = "ر.ق" },
            new() { Code = "BHD", NameAr = "دينار بحريني", Symbol = "د.ب" },
            new() { Code = "OMR", NameAr = "ريال عماني", Symbol = "ر.ع" },
            new() { Code = "JOD", NameAr = "دينار أردني", Symbol = "د.أ" },
            new() { Code = "EGP", NameAr = "جنيه مصري", Symbol = "ج.م" },
            new() { Code = "IQD", NameAr = "دينار عراقي", Symbol = "د.ع" },
            new() { Code = "LBP", NameAr = "ليرة لبنانية", Symbol = "ل.ل" },
            new() { Code = "MAD", NameAr = "درهم مغربي", Symbol = "د.م" },
            new() { Code = "TND", NameAr = "دينار تونسي", Symbol = "د.ت" },
            new() { Code = "DZD", NameAr = "دينار جزائري", Symbol = "د.ج" },
            new() { Code = "YER", NameAr = "ريال يمني", Symbol = "ر.ي" },
            new() { Code = "LYD", NameAr = "دينار ليبي", Symbol = "د.ل" },
            new() { Code = "SDG", NameAr = "جنيه سوداني", Symbol = "ج.س" },
            new() { Code = "TRY", NameAr = "ليرة تركية", Symbol = "₺" },
        ];
    }
}
