namespace ShouTech.Domain.Interfaces
{
    public static class DatabaseProviderNames
    {
        public const string PostgreSql = "PostgreSQL";
        public const string Sqlite = "SQLite";
        public const string MySql = "MySQL";

        public static string Normalize(string? provider)
        {
            var trimmed = provider?.Trim() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(trimmed))
                return string.Empty;

            if (string.Equals(trimmed, PostgreSql, StringComparison.OrdinalIgnoreCase)
                || string.Equals(trimmed, "postgres", StringComparison.OrdinalIgnoreCase)
                || string.Equals(trimmed, "pgsql", StringComparison.OrdinalIgnoreCase))
                return PostgreSql;

            if (string.Equals(trimmed, Sqlite, StringComparison.OrdinalIgnoreCase)
                || string.Equals(trimmed, "sqlite3", StringComparison.OrdinalIgnoreCase))
                return Sqlite;

            if (string.Equals(trimmed, MySql, StringComparison.OrdinalIgnoreCase)
                || string.Equals(trimmed, "mariadb", StringComparison.OrdinalIgnoreCase))
                return MySql;

            return trimmed;
        }

        public static bool IsSupported(string? provider) =>
            string.Equals(Normalize(provider), PostgreSql, StringComparison.OrdinalIgnoreCase) ||
            string.Equals(Normalize(provider), Sqlite, StringComparison.OrdinalIgnoreCase);

        public static bool IsLegacy(string? provider) =>
            string.Equals(Normalize(provider), MySql, StringComparison.OrdinalIgnoreCase);

        public static bool IsCoreImplemented(string? provider) => IsSupported(provider);

        public static void EnsureCoreImplementation(string? provider)
        {
            var normalized = Normalize(provider);
            if (IsLegacy(normalized))
                throw new NotSupportedException(
                    $"Database provider '{provider}' is retained only for legacy code paths. Choose {Sqlite} or {PostgreSql}.");

            if (!IsSupported(normalized))
                throw new NotSupportedException(
                    $"Unsupported database provider '{provider}'. Choose {Sqlite} or {PostgreSql}.");
            if (!IsCoreImplemented(normalized))
                throw new NotSupportedException($"Core support is unavailable for database provider '{provider}'.");
        }
    }

    public interface IDatabaseProvider
    {
        string GetConnectionString(string companyCode);
        bool TestConnection(string companyCode);
    }
}