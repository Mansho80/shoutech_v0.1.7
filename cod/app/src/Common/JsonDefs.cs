using System.Text.Json;

namespace ShouTech.App.Common
{
    internal static class JsonDefs
    {
        public static JsonSerializerOptions Indented { get; } = new()
        {
            WriteIndented = true
        };

        public static JsonSerializerOptions AppSetngRead { get; } = new()
        {
            PropertyNameCaseInsensitive = true,
            ReadCommentHandling = JsonCommentHandling.Skip,
            AllowTrailingCommas = true
        };
    }
}
