using System.IO;
using System.Linq;
using Microsoft.Data.Sqlite;
using ShouTech.App.Configuration;
using ShouTech.Domain.Interfaces;

namespace ShouTech.App.Services;

internal static class DatabaseRuntime
{
    private const string DefaultSqliteFileName = "shoutech_erp.sqlite3";

    public static string GetProvider()
    {
        var configured = AppCfgSvc.Current?.ConnectionStrings?
            .FirstOrDefault(item => item.Key.Equals("Default", StringComparison.OrdinalIgnoreCase))
            .Value?.Provider;
        var fallback = string.IsNullOrWhiteSpace(configured)
            ? AppCfgSvc.Current?.Database?.DefaultProvider
            : configured;
        if (string.IsNullOrWhiteSpace(fallback))
            fallback = Environment.GetEnvironmentVariable("SHOUTECH_DB_PROVIDER");
        return CoerceSupportedProvider(fallback, AppCfgSvc.Current?.Database?.DefaultProvider);
    }

    public static string? GetConnectionString()
    {
        var connection = AppCfgSvc.Current?.ConnectionStrings?
            .FirstOrDefault(item => item.Key.Equals("Default", StringComparison.OrdinalIgnoreCase))
            .Value?.ConnectionString;
        if (string.IsNullOrWhiteSpace(connection))
            connection = AppCfgSvc.Current?.ConnectionStrings?.Values?.FirstOrDefault()?.ConnectionString;
        if (string.IsNullOrWhiteSpace(connection))
            connection = Environment.GetEnvironmentVariable("SHOUTECH_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connection))
            return null;

        return IsSqlite()
            ? NormalizeSqliteConnectionString(connection)
            : connection.Trim();
    }

    public static bool IsSqlite(string? provider = null) =>
        string.Equals(DatabaseProviderNames.Normalize(provider ?? GetProvider()), DatabaseProviderNames.Sqlite, StringComparison.OrdinalIgnoreCase);

    public static bool IsPostgreSql(string? provider = null) =>
        string.Equals(DatabaseProviderNames.Normalize(provider ?? GetProvider()), DatabaseProviderNames.PostgreSql, StringComparison.OrdinalIgnoreCase);

    public static bool LooksLikeConnectionString(string? value)
    {
        var trimmed = value?.Trim();
        return !string.IsNullOrWhiteSpace(trimmed) && trimmed.Contains('=') && trimmed.Contains(';');
    }

    public static string NormalizeSqliteConnectionString(string sqlitePathOrConnectionString)
    {
        if (string.IsNullOrWhiteSpace(sqlitePathOrConnectionString))
            throw new ArgumentException("A SQLite path or connection string is required.", nameof(sqlitePathOrConnectionString));

        if (!LooksLikeConnectionString(sqlitePathOrConnectionString))
            return BuildSqliteConnectionStringFromPath(sqlitePathOrConnectionString.Trim());

        var builder = new SqliteConnectionStringBuilder(sqlitePathOrConnectionString.Trim());
        if (string.Equals(builder.DataSource, ":memory:", StringComparison.Ordinal)
            || builder.DataSource.StartsWith("file:", StringComparison.OrdinalIgnoreCase))
            return builder.ToString();

        builder.DataSource = Path.GetFullPath(builder.DataSource);
        if (builder.Mode == SqliteOpenMode.ReadOnly)
            return builder.ToString();

        builder.Mode = SqliteOpenMode.ReadWriteCreate;
        builder.Cache = SqliteCacheMode.Shared;
        return builder.ToString();
    }

    public static string? GetSqliteDataSource(string? sqlitePathOrConnectionString)
    {
        if (string.IsNullOrWhiteSpace(sqlitePathOrConnectionString))
            return null;

        if (!LooksLikeConnectionString(sqlitePathOrConnectionString))
            return Path.GetFullPath(sqlitePathOrConnectionString.Trim());

        var builder = new SqliteConnectionStringBuilder(sqlitePathOrConnectionString.Trim());
        return string.Equals(builder.DataSource, ":memory:", StringComparison.Ordinal)
            || builder.DataSource.StartsWith("file:", StringComparison.OrdinalIgnoreCase)
            ? builder.DataSource
            : Path.GetFullPath(builder.DataSource);
    }

    private static string BuildSqliteConnectionStringFromPath(string path)
    {
        var fullPath = Path.GetFullPath(Path.HasExtension(path)
            ? path
            : Path.Combine(path, DefaultSqliteFileName));
        return new SqliteConnectionStringBuilder
        {
            DataSource = fullPath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Shared
        }.ToString();
    }

    private static string CoerceSupportedProvider(string? provider, string? fallbackProvider)
    {
        var normalized = DatabaseProviderNames.Normalize(provider);
        if (DatabaseProviderNames.IsSupported(normalized))
            return normalized;
        if (DatabaseProviderNames.IsLegacy(normalized))
            return DatabaseProviderNames.PostgreSql;

        var fallback = DatabaseProviderNames.Normalize(fallbackProvider);
        return DatabaseProviderNames.IsSupported(fallback)
            ? fallback
            : DatabaseProviderNames.Sqlite;
    }
}
