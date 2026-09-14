using Microsoft.Data.Sqlite;
using Npgsql;
using ShouTech.Domain.Interfaces;

namespace ShouTech.Infrastructure;

/// <summary>Provider adapter used by callers that need a connection by company code.</summary>
public sealed class ConnectionStringDatabaseProvider : IDatabaseProvider
{
    private readonly string _defaultConnection;
    private readonly IReadOnlyDictionary<string, string> _connections;
    private readonly string _provider;

    public ConnectionStringDatabaseProvider(string provider, string defaultConnection,
        IReadOnlyDictionary<string, string>? connections = null)
    {
        _provider = DatabaseProviderNames.Normalize(provider);
        DatabaseProviderNames.EnsureCoreImplementation(_provider);
        _defaultConnection = string.IsNullOrWhiteSpace(defaultConnection)
            ? throw new ArgumentException("A database connection string is required.", nameof(defaultConnection))
            : defaultConnection;
        _connections = connections ?? new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    }

    public string GetConnectionString(string companyCode) =>
        !string.IsNullOrWhiteSpace(companyCode) && _connections.TryGetValue(companyCode.Trim(), out var value)
            ? value : _defaultConnection;

    public bool TestConnection(string companyCode)
    {
        try
        {
            var connectionString = GetConnectionString(companyCode);
            using System.Data.Common.DbConnection connection = _provider switch
            {
                var provider when provider.Equals(DatabaseProviderNames.Sqlite, StringComparison.OrdinalIgnoreCase)
                    => new SqliteConnection(connectionString),
                _ => new NpgsqlConnection(connectionString)
            };
            connection.Open();
            using var command = connection.CreateCommand();
            command.CommandText = "SELECT 1";
            command.ExecuteScalar();
            return true;
        }
        catch { return false; }
    }
}

public static class DatabaseProviderFactory
{
    public static IDatabaseProvider Create(string provider, string connectionString,
        IReadOnlyDictionary<string, string>? companyConnections = null) =>
        new ConnectionStringDatabaseProvider(provider, connectionString, companyConnections);
}
