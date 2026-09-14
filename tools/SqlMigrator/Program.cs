#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using MySqlConnector;
using Npgsql;
using ShouTech.Domain.Interfaces;

internal static class Program
{
    private static async Task<int> Main()
    {
        var provider = DatabaseProviderNames.Normalize(
            Environment.GetEnvironmentVariable("SHOUTECH_DB_PROVIDER") ?? DatabaseProviderNames.Sqlite);
        if (!DatabaseProviderNames.IsSupported(provider))
        {
            Console.Error.WriteLine(
                $"Unsupported database provider '{provider}'. Choose {DatabaseProviderNames.Sqlite} or {DatabaseProviderNames.PostgreSql}.");
            return 2;
        }


        var connectionString = Environment.GetEnvironmentVariable("SHOUTECH_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            Console.Error.WriteLine("SHOUTECH_CONNECTION_STRING is not set.");
            return 2;
        }
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        string? migrationsPath = null;
        for (var i = 0; i < 10 && directory != null; i++)
        {
            var candidate = Path.Combine(directory.FullName, "dba",
                provider.Equals(DatabaseProviderNames.Sqlite, StringComparison.OrdinalIgnoreCase) ? Path.Combine("mig", "sqlite") : "mig");
            if (Directory.Exists(candidate))
            {
                migrationsPath = candidate;
                break;
            }
            directory = directory.Parent;
        }

        if (migrationsPath == null)
        {
            Console.Error.WriteLine("Migrations folder not found.");
            return 2;
        }

        var files = Directory.GetFiles(migrationsPath, "*.sql");
        if (provider.Equals(DatabaseProviderNames.PostgreSql, StringComparison.OrdinalIgnoreCase))
            files = files.Where(file =>
                Path.GetFileName(file).StartsWith("010_postgresql_", StringComparison.OrdinalIgnoreCase)
                || Path.GetFileName(file).StartsWith("008_postgresql_", StringComparison.OrdinalIgnoreCase)
                || Path.GetFileName(file).StartsWith("011_postgresql_", StringComparison.OrdinalIgnoreCase)).ToArray();
        Array.Sort(files, StringComparer.OrdinalIgnoreCase);

        try
        {
            if (provider.Equals(DatabaseProviderNames.PostgreSql, StringComparison.OrdinalIgnoreCase))
            {
                await using var connection = new NpgsqlConnection(connectionString);
                await connection.OpenAsync();
                await EnsureHistoryAsync(connection);
                foreach (var file in files)
                {
                    var sql = File.ReadAllText(file);
                    if (string.IsNullOrWhiteSpace(sql))
                        continue;
                    if (await IsAppliedAsync(connection, Path.GetFileName(file), sql))
                    {
                        Console.WriteLine($"Skipping {Path.GetFileName(file)} (already applied).");
                        continue;
                    }
                    Console.WriteLine($"Applying {Path.GetFileName(file)}...");
                    await using var command = new NpgsqlCommand(sql, connection);
                    command.CommandTimeout = 600;
                    await command.ExecuteNonQueryAsync();
                    await MarkAppliedAsync(connection, Path.GetFileName(file), sql);
                    Console.WriteLine("OK");
                }
            }
            else
            {
                await using var connection = new SqliteConnection(NormalizeSqliteConnectionString(connectionString));
                await connection.OpenAsync();
                await EnsureHistoryAsync(connection);
                foreach (var file in files)
                {
                    var sql = File.ReadAllText(file);
                    if (string.IsNullOrWhiteSpace(sql))
                        continue;
                    if (await IsAppliedAsync(connection, Path.GetFileName(file), sql))
                    {
                        Console.WriteLine($"Skipping {Path.GetFileName(file)} (already applied).");
                        continue;
                    }
                    Console.WriteLine($"Applying {Path.GetFileName(file)}...");
                    await using var command = connection.CreateCommand();
                    command.CommandTimeout = 600;
                    command.CommandText = sql;
                    await command.ExecuteNonQueryAsync();
                    await MarkAppliedAsync(connection, Path.GetFileName(file), sql);
                    Console.WriteLine("OK");
                }
            }

            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Migration failed: {ex.Message}");
            return 1;
        }
    }

    private static string ExpandSqlCmd(string sql, string baseDirectory)
    {
        var variables = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var output = new StringBuilder();

        foreach (var line in sql.Split('\n'))
        {
            var trimmed = line.Trim();
            if (trimmed.StartsWith(":setvar ", StringComparison.OrdinalIgnoreCase))
            {
                var parts = trimmed[8..].Trim().Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length == 2)
                    variables[parts[0]] = parts[1].Trim().Trim('"');
                continue;
            }

            if (trimmed.StartsWith(":r ", StringComparison.OrdinalIgnoreCase))
            {
                var includePath = Path.GetFullPath(Path.Combine(baseDirectory, trimmed[3..].Trim().Trim('"')));
                if (!File.Exists(includePath))
                    throw new FileNotFoundException("SQL include file not found.", includePath);
                output.AppendLine(ExpandSqlCmd(File.ReadAllText(includePath), Path.GetDirectoryName(includePath)!));
                continue;
            }

            output.AppendLine(line);
        }

        var expanded = output.ToString();
        foreach (var variable in variables)
            expanded = expanded.Replace($"$({variable.Key})", variable.Value, StringComparison.OrdinalIgnoreCase);
        return expanded;
    }

    private static IEnumerable<string> SplitBatches(string sql)
    {
        return sql.Split(new[] { "\r\nGO\r\n", "\nGO\n", "\r\nGO\r", "\nGO\r" },
            StringSplitOptions.RemoveEmptyEntries);
    }

    private static async Task EnsureHistoryAsync(System.Data.Common.DbConnection connection)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = connection switch
        {
            SqliteConnection => "CREATE TABLE IF NOT EXISTS __shoutech_schema_migrations (migration_id TEXT PRIMARY KEY, checksum TEXT NOT NULL, applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
            MySqlConnection => "CREATE TABLE IF NOT EXISTS __shoutech_schema_migrations (migration_id VARCHAR(255) PRIMARY KEY, checksum CHAR(64) NOT NULL, applied_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6))",
            _ => "CREATE TABLE IF NOT EXISTS __shoutech_schema_migrations (migration_id varchar(255) PRIMARY KEY, checksum varchar(64) NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())"
        };
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<bool> IsAppliedAsync(System.Data.Common.DbConnection connection, string id, string sql)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT checksum FROM __shoutech_schema_migrations WHERE migration_id=@id";
        var parameter = command.CreateParameter();
        parameter.ParameterName = "@id";
        parameter.Value = id;
        command.Parameters.Add(parameter);
        var value = await command.ExecuteScalarAsync();
        if (value == null || value == DBNull.Value)
            return false;
        var checksum = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(sql)));
        if (!string.Equals(value.ToString(), checksum, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException($"Migration '{id}' was changed after it was applied.");
        return true;
    }

    private static async Task MarkAppliedAsync(System.Data.Common.DbConnection connection, string id, string sql)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = "INSERT INTO __shoutech_schema_migrations (migration_id,checksum) VALUES (@id,@checksum)";
        var idParameter = command.CreateParameter();
        idParameter.ParameterName = "@id";
        idParameter.Value = id;
        command.Parameters.Add(idParameter);
        var checksumParameter = command.CreateParameter();
        checksumParameter.ParameterName = "@checksum";
        checksumParameter.Value = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(sql)));
        command.Parameters.Add(checksumParameter);
        await command.ExecuteNonQueryAsync();
    }

    private static string NormalizeSqliteConnectionString(string sqlitePathOrConnectionString)
    {
        if (string.IsNullOrWhiteSpace(sqlitePathOrConnectionString))
            throw new ArgumentException("A SQLite path or connection string is required.", nameof(sqlitePathOrConnectionString));
        if (!sqlitePathOrConnectionString.Contains('=') || !sqlitePathOrConnectionString.Contains(';'))
            return new SqliteConnectionStringBuilder
            {
                DataSource = Path.GetFullPath(sqlitePathOrConnectionString.Trim()),
                Mode = SqliteOpenMode.ReadWriteCreate,
                Cache = SqliteCacheMode.Shared
            }.ToString();

        var builder = new SqliteConnectionStringBuilder(sqlitePathOrConnectionString.Trim());
        if (!string.Equals(builder.DataSource, ":memory:", StringComparison.Ordinal)
            && !builder.DataSource.StartsWith("file:", StringComparison.OrdinalIgnoreCase))
            builder.DataSource = Path.GetFullPath(builder.DataSource);
        if (builder.Mode != SqliteOpenMode.ReadOnly)
            builder.Mode = SqliteOpenMode.ReadWriteCreate;
        return builder.ToString();
    }
}
