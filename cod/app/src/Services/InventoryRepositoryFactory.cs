namespace ShouTech.App.Services;

public static class InventoryRepositoryFactory
{
    public static IInvRepo Create(string provider, string connectionString)
    {
        var normalized = ShouTech.Domain.Interfaces.DatabaseProviderNames.Normalize(provider);
        ShouTech.Domain.Interfaces.DatabaseProviderNames.EnsureCoreImplementation(normalized);
        return normalized switch
        {
            ShouTech.Domain.Interfaces.DatabaseProviderNames.Sqlite => new SqliteInvRepo(connectionString),
            ShouTech.Domain.Interfaces.DatabaseProviderNames.PostgreSql => new SqlInvRepo(connectionString),
            _ => throw new NotSupportedException($"Unsupported database provider '{provider}'.")
        };
    }
}
