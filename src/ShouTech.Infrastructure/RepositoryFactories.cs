using ShouTech.Domain.Interfaces;

namespace ShouTech.Infrastructure;

public static class JournalRepositoryFactory
{
    public static IJournalRepository Create(string provider, string connectionString)
    {
        var normalized = DatabaseProviderNames.Normalize(provider);
        DatabaseProviderNames.EnsureCoreImplementation(normalized);
        return normalized switch
        {
            DatabaseProviderNames.Sqlite => new SqliteJournalRepository(connectionString),
            DatabaseProviderNames.PostgreSql => new SqlJournalRepository(connectionString),
            _ => throw new NotSupportedException($"Unsupported database provider '{provider}'.")
        };
    }
}
