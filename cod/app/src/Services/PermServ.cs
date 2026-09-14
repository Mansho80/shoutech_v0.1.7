using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using Npgsql;

namespace ShouTech.App.Services;

public sealed class PermServ : IPermServ
{
    private readonly HashSet<string> _perms = new(StringComparer.OrdinalIgnoreCase);
    private string? _currentUserId;
    private bool _isSuperAdmin;

    public bool Has(string permissionKey)
    {
        if (string.IsNullOrWhiteSpace(permissionKey))
            return false;
        return _isSuperAdmin || _perms.Contains(permissionKey.Trim());
    }

    public bool HasAll(params string[] permissionKeys)
    {
        if (permissionKeys == null || permissionKeys.Length == 0)
            return true;
        foreach (var key in permissionKeys)
            if (!Has(key))
                return false;
        return true;
    }

    public bool HasAny(params string[] permissionKeys)
    {
        if (permissionKeys == null || permissionKeys.Length == 0)
            return false;
        foreach (var key in permissionKeys)
            if (Has(key))
                return true;
        return false;
    }

    public async Task LoadForUserAsync(string userId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(userId))
            throw new ArgumentException("UserId is required.", nameof(userId));

        var connectionString = DatabaseRuntime.GetConnectionString();
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new InvalidOperationException("Permission loading requires SHOUTECH_CONNECTION_STRING.");

        _perms.Clear();
        _isSuperAdmin = false;
        _currentUserId = userId.Trim();

        var provider = DatabaseRuntime.GetProvider();
        if (DatabaseRuntime.IsSqlite(provider))
        {
            await LoadSqliteAsync(connectionString, ct).ConfigureAwait(false);
            return;
        }

        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct).ConfigureAwait(false);
        const string sql = """
            SELECT u."IsSuperAdmin", p."PermissionCode"
            FROM sec."Users" AS u
            LEFT JOIN sec."UserRoles" AS ur ON ur."UserID" = u."UserID"
            LEFT JOIN sec."Roles" AS r ON r."RoleID" = ur."RoleID"
                AND r."IsActive" = TRUE AND r."IsDeleted" = FALSE
            LEFT JOIN sec."RolePermissions" AS rp ON rp."RoleID" = r."RoleID"
            LEFT JOIN sec."Permissions" AS p ON p."PermissionID" = rp."PermissionID"
                AND p."IsActive" = TRUE
            WHERE u."IsActive" = TRUE AND u."IsDeleted" = FALSE
              AND (u."Username" = @UserId OR u."UserID" =
                  CASE WHEN @UserId ~ '^[0-9]+$' THEN CAST(@UserId AS integer) END);
            """;

        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("@UserId", _currentUserId);
        await using var reader = await command.ExecuteReaderAsync(ct).ConfigureAwait(false);
        var found = false;
        while (await reader.ReadAsync(ct).ConfigureAwait(false))
        {
            found = true;
            _isSuperAdmin |= reader.GetBoolean(0);
            if (!reader.IsDBNull(1))
                _perms.Add(reader.GetString(1));
        }

        if (!found)
        {
            _currentUserId = null;
            throw new UnauthorizedAccessException("The user is inactive, deleted, or does not exist.");
        }
    }

    public void Clear()
    {
        _perms.Clear();
        _currentUserId = null;
        _isSuperAdmin = false;
    }

    public IReadOnlyCollection<string> GetCurrentPermissions() => _perms;

    private async Task LoadSqliteAsync(string connectionString, CancellationToken ct)
    {
        SqliteSchemaBootstrapper.EnsureDatabase(connectionString);
        await using var connection = new SqliteConnection(connectionString);
        await connection.OpenAsync(ct).ConfigureAwait(false);
        await using var command = new SqliteCommand("""
            SELECT u.is_super_admin, p.permission_code
            FROM users u
            LEFT JOIN user_roles ur ON ur.user_id=u.user_id
            LEFT JOIN roles r ON r.role_id=ur.role_id AND r.is_active=1 AND r.is_deleted=0
            LEFT JOIN role_permissions rp ON rp.role_id=r.role_id
            LEFT JOIN permissions p ON p.permission_id=rp.permission_id AND p.is_active=1
            WHERE u.is_active=1 AND u.is_deleted=0
              AND (u.username=@user_id OR u.user_id=@user_id)
            """, connection);
        command.Parameters.AddWithValue("@user_id", _currentUserId);
        await using var reader = await command.ExecuteReaderAsync(ct).ConfigureAwait(false);
        var found = false;
        while (await reader.ReadAsync(ct).ConfigureAwait(false))
        {
            found = true;
            _isSuperAdmin |= !reader.IsDBNull(0) && Convert.ToInt32(reader.GetValue(0), CultureInfo.InvariantCulture) != 0;
            if (!reader.IsDBNull(1)) _perms.Add(reader.GetString(1));
        }
        if (!found)
        {
            _currentUserId = null;
            throw new UnauthorizedAccessException("The user is inactive, deleted, or does not exist.");
        }
    }

}
