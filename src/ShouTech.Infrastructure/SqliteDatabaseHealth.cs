using System.Diagnostics;
using System.IO;
using Microsoft.Data.Sqlite;
using ShouTech.Domain.Interfaces;

namespace ShouTech.Infrastructure;

public sealed class SqliteDatabaseHealth : IDatabaseHealth
{
    private readonly string _connectionString;
    private readonly TimeSpan _timeout;

    public SqliteDatabaseHealth(string connectionString, TimeSpan? timeout = null)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new ArgumentException("A database connection string is required.", nameof(connectionString));

        _connectionString = NormalizeReadWriteConnection(connectionString);
        _timeout = timeout ?? TimeSpan.FromSeconds(5);
    }

    public async Task<DatabaseHealthResult> CheckAsync(CancellationToken cancellationToken = default)
    {
        var stopwatch = Stopwatch.StartNew();
        try
        {
            await using var connection = new SqliteConnection(_connectionString);
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(_timeout);
            await connection.OpenAsync(timeout.Token).ConfigureAwait(false);
            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT 1";
            await command.ExecuteScalarAsync(timeout.Token).ConfigureAwait(false);
            return new DatabaseHealthResult(true, DatabaseProviderNames.Sqlite, "Database connection is healthy.", stopwatch.Elapsed);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return new DatabaseHealthResult(false, DatabaseProviderNames.Sqlite, "Database connection timed out.", stopwatch.Elapsed);
        }
        catch (Exception ex)
        {
            return new DatabaseHealthResult(false, DatabaseProviderNames.Sqlite, ex.Message, stopwatch.Elapsed);
        }
    }

    private static string NormalizeReadWriteConnection(string connectionString)
    {
        var builder = new SqliteConnectionStringBuilder(connectionString);
        if (string.Equals(builder.DataSource, ":memory:", StringComparison.Ordinal))
            return builder.ToString();

        if (!string.IsNullOrWhiteSpace(builder.DataSource))
        {
            var fullPath = Path.GetFullPath(builder.DataSource);
            if (!File.Exists(fullPath))
                throw new FileNotFoundException("SQLite database file was not found.", fullPath);

            builder.DataSource = fullPath;
            builder.Mode = SqliteOpenMode.ReadWrite;
        }

        return builder.ToString();
    }
}
