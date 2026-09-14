using ShouTech.Domain.Interfaces;

namespace ShouTech.Infrastructure;

public static class DatabaseHealthFactory
{
    public static IDatabaseHealth Create(string provider, string connectionString, TimeSpan? timeout = null)
    {
        var normalized = DatabaseProviderNames.Normalize(provider);
        DatabaseProviderNames.EnsureCoreImplementation(normalized);
        return normalized switch
        {
            var sqlite when sqlite.Equals(DatabaseProviderNames.Sqlite, StringComparison.OrdinalIgnoreCase)
                => new SqliteDatabaseHealth(connectionString, timeout),
            _ => new SqlDatabaseHealth(connectionString, timeout)
        };
    }
}
