using System.Diagnostics;
using Npgsql;
using ShouTech.Domain.Interfaces;

namespace ShouTech.Infrastructure;

/// <summary>PostgreSQL database connectivity check (name retained for compatibility).</summary>
public sealed class SqlDatabaseHealth : IDatabaseHealth
{
    private readonly string _connectionString;
    private readonly TimeSpan _timeout;
    public SqlDatabaseHealth(string connectionString, TimeSpan? timeout = null)
    {
        if (string.IsNullOrWhiteSpace(connectionString)) throw new ArgumentException("A database connection string is required.", nameof(connectionString));
        _connectionString = connectionString;
        _timeout = timeout ?? TimeSpan.FromSeconds(5);
    }
    public async Task<DatabaseHealthResult> CheckAsync(CancellationToken cancellationToken = default)
    {
        var stopwatch = Stopwatch.StartNew();
        try
        {
            await using var connection = new NpgsqlConnection(_connectionString);
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(_timeout);
            await connection.OpenAsync(timeout.Token).ConfigureAwait(false);
            await using var command = new NpgsqlCommand("SELECT 1", connection);
            await command.ExecuteScalarAsync(timeout.Token).ConfigureAwait(false);
            return new DatabaseHealthResult(true, DatabaseProviderNames.PostgreSql, "Database connection is healthy.", stopwatch.Elapsed);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            { return new DatabaseHealthResult(false, DatabaseProviderNames.PostgreSql, "Database connection timed out.", stopwatch.Elapsed); }
        catch (Exception ex) { return new DatabaseHealthResult(false, DatabaseProviderNames.PostgreSql, ex.Message, stopwatch.Elapsed); }
    }
}
