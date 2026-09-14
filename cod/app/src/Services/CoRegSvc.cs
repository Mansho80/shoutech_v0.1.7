using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using Npgsql;
using ShouTech.App.Configuration;

namespace ShouTech.App.Services
{
    /// <summary>
    /// Company registry: database + local index (companies.json).
    /// </summary>
    public class CoRegSvc : ICoRegSvc
    {
        public async Task<List<CompanyInfo>> GetCompaniesAsync()
        {
            var merged = new Dictionary<string, CompanyInfo>(StringComparer.OrdinalIgnoreCase);

            foreach (var company in await LoadFromDatabaseAsync())
            {
                if (!string.IsNullOrWhiteSpace(company.Code))
                    merged[company.Code] = company;
            }

            foreach (var local in await CoLocalStore.LoadAsync())
            {
                if (string.IsNullOrWhiteSpace(local.Code) || merged.ContainsKey(local.Code))
                    continue;

                merged[local.Code] = new CompanyInfo
                {
                    Code = local.Code,
                    Name = local.Name,
                    NameEn = local.NameEn,
                    Database = string.IsNullOrWhiteSpace(local.DbPath) ? "LOCAL" : local.DbPath,
                    Enabled = local.Enabled,
                    IsDefault = false
                };
            }

            if (merged.Count > 0)
                return merged.Values.OrderBy(c => c.Code).ToList();

            return AppCfgSvc.Current?.MultiCompany?.Companies?
                .Where(c => c?.Enabled == true)
                .ToList() ?? new List<CompanyInfo>();
        }

        public async Task<bool> HasCompaniesAsync()
        {
            var companies = await GetCompaniesAsync();
            return companies.Any(c => c?.Enabled == true);
        }

        /// <summary>
        /// Rebuild local index from database + keep local-only entries that are still enabled.
        /// Returns the number of indexed companies.
        /// </summary>
        public static async Task<int> RebuildCompanyIndexAsync()
        {
            var fromDb = await LoadFromDatabaseAsync();
            var localAll = await CoLocalStore.LoadAllAsync();
            var byCode = new Dictionary<string, StoredCoRec>(StringComparer.OrdinalIgnoreCase);

            // Keep disabled (soft-removed from window) entries so Restore still sees them.
            foreach (var c in localAll)
                byCode[c.Code] = c;

            foreach (var db in fromDb)
            {
                if (string.IsNullOrWhiteSpace(db.Code))
                    continue;

                if (byCode.TryGetValue(db.Code, out var existing))
                {
                    existing.Name = db.Name ?? existing.Name;
                    existing.NameEn = db.NameEn ?? existing.NameEn;
                    // Active in DB → must be enabled in index
                    existing.Enabled = true;
                }
                else
                {
                    byCode[db.Code] = new StoredCoRec
                    {
                        Code = db.Code,
                        Name = db.Name ?? db.Code,
                        NameEn = db.NameEn ?? db.Name ?? db.Code,
                        Enabled = true
                    };
                }
            }

            var list = byCode.Values.OrderBy(c => c.Code).ToList();
            await CoLocalStore.ReplaceIndexAsync(list);
            return list.Count;
        }

        /// <summary>
        /// Soft-delete in database (is_deleted) then remove from local index.
        /// </summary>
        public static async Task<bool> DeleteCompanyFullyAsync(string companyCode)
        {
            if (string.IsNullOrWhiteSpace(companyCode))
                return false;

            var deletedInDb = await TrySoftDeleteInDatabaseAsync(companyCode);
            await CoLocalStore.RemoveFromIndexAsync(companyCode);
            return deletedInDb;
        }

        private static async Task<bool> TrySoftDeleteInDatabaseAsync(string companyCode)
        {
            try
            {
                var connectionString = ResolveConnectionString();
                if (string.IsNullOrWhiteSpace(connectionString))
                    return false;

                var provider = DatabaseRuntime.GetProvider();
                if (DatabaseRuntime.IsSqlite(provider))
                {
                    SqliteSchemaBootstrapper.EnsureDatabase(connectionString);
                    await using var connection = new SqliteConnection(connectionString);
                    await connection.OpenAsync();
                    await using var cmd = new SqliteCommand(
                        "UPDATE companies SET is_deleted=1, is_active=0 WHERE company_code=@code",
                        connection);
                    cmd.Parameters.AddWithValue("@code", companyCode);
                    return await cmd.ExecuteNonQueryAsync() > 0;
                }

                if (DatabaseRuntime.IsPostgreSql(provider))
                {
                    await using var connection = new NpgsqlConnection(connectionString);
                    await connection.OpenAsync();
                    await using var cmd = new NpgsqlCommand("""
                        UPDATE public."Companies"
                        SET "IsDeleted" = TRUE, "IsActive" = FALSE
                        WHERE "CompanyCode" = @code
                        """, connection);
                    cmd.Parameters.AddWithValue("code", companyCode);
                    return await cmd.ExecuteNonQueryAsync() > 0;
                }
            }
            catch
            {
                return false;
            }

            return false;
        }


        /// <summary>
        /// Soft-deleted companies still present in the database.
        /// </summary>
        public static async Task<List<CompanyInfo>> GetDeletedCompaniesAsync()
        {
            var merged = new Dictionary<string, CompanyInfo>(StringComparer.OrdinalIgnoreCase);

            // 1) Soft-deleted rows in database
            try
            {
                var connectionString = ResolveConnectionString();
                if (!string.IsNullOrWhiteSpace(connectionString))
                {
                    var provider = DatabaseRuntime.GetProvider();
                    if (DatabaseRuntime.IsSqlite(provider))
                    {
                        SqliteSchemaBootstrapper.EnsureDatabase(connectionString);
                        await using var connection = new SqliteConnection(connectionString);
                        await connection.OpenAsync();
                        await using var command = new SqliteCommand("""
                            SELECT company_code, company_name_ar, company_name_en
                            FROM companies
                            WHERE is_deleted=1
                            ORDER BY company_name_ar
                            LIMIT 1000
                            """, connection);
                        await using var reader = await command.ExecuteReaderAsync();
                        while (await reader.ReadAsync())
                        {
                            var code = reader["company_code"]?.ToString() ?? string.Empty;
                            if (string.IsNullOrWhiteSpace(code)) continue;
                            merged[code] = new CompanyInfo
                            {
                                Code = code,
                                Name = reader["company_name_ar"]?.ToString() ?? string.Empty,
                                NameEn = reader["company_name_en"]?.ToString() ?? string.Empty,
                                Enabled = false,
                                IsDefault = false
                            };
                        }
                    }
                    else if (DatabaseRuntime.IsPostgreSql(provider))
                    {
                        await using var connection = new NpgsqlConnection(connectionString);
                        await connection.OpenAsync();
                        await using var command = new NpgsqlCommand("""
                            SELECT "CompanyCode", "CompanyNameAR", "CompanyNameEN"
                            FROM public."Companies"
                            WHERE COALESCE("IsDeleted", FALSE) = TRUE
                            ORDER BY "CompanyNameAR"
                            LIMIT 1000;
                            """, connection);
                        await using var reader = await command.ExecuteReaderAsync();
                        while (await reader.ReadAsync())
                        {
                            var code = reader["CompanyCode"]?.ToString() ?? string.Empty;
                            if (string.IsNullOrWhiteSpace(code)) continue;
                            merged[code] = new CompanyInfo
                            {
                                Code = code,
                                Name = reader["CompanyNameAR"]?.ToString() ?? string.Empty,
                                NameEn = reader["CompanyNameEN"]?.ToString() ?? string.Empty,
                                Enabled = false,
                                IsDefault = false
                            };
                        }
                    }
                }
            }
            catch
            {
                // continue with local disabled entries
            }

            // 2) Local index entries marked Enabled=false (delete from window)
            try
            {
                foreach (var local in await CoLocalStore.LoadDisabledAsync())
                {
                    if (string.IsNullOrWhiteSpace(local.Code) || merged.ContainsKey(local.Code))
                        continue;
                    merged[local.Code] = new CompanyInfo
                    {
                        Code = local.Code,
                        Name = local.Name,
                        NameEn = local.NameEn,
                        Enabled = false,
                        IsDefault = false
                    };
                }
            }
            catch
            {
            }

            return merged.Values
                .OrderBy(c => c.Name)
                .ToList();
        }

        /// <summary>
        /// Restore a soft-deleted company: clear delete flags and re-index.
        /// </summary>
        public static async Task<bool> RestoreCompanyAsync(string companyCode)
        {
            if (string.IsNullOrWhiteSpace(companyCode))
                return false;

            _ = await TryRestoreInDatabaseAsync(companyCode);
            await CoLocalStore.RestoreInIndexAsync(companyCode);
            // Rebuild merges active DB rows; preserves restored local entry.
            await RebuildCompanyIndexAsync();
            // If only local-disabled (never soft-deleted in DB), still success.
            return true;
        }

        private static async Task<bool> TryRestoreInDatabaseAsync(string companyCode)
        {
            try
            {
                var connectionString = ResolveConnectionString();
                if (string.IsNullOrWhiteSpace(connectionString))
                    return false;

                var provider = DatabaseRuntime.GetProvider();
                if (DatabaseRuntime.IsSqlite(provider))
                {
                    SqliteSchemaBootstrapper.EnsureDatabase(connectionString);
                    await using var connection = new SqliteConnection(connectionString);
                    await connection.OpenAsync();
                    await using var cmd = new SqliteCommand(
                        "UPDATE companies SET is_deleted=0, is_active=1 WHERE company_code=@code AND is_deleted=1",
                        connection);
                    cmd.Parameters.AddWithValue("@code", companyCode);
                    return await cmd.ExecuteNonQueryAsync() > 0;
                }

                if (DatabaseRuntime.IsPostgreSql(provider))
                {
                    await using var connection = new NpgsqlConnection(connectionString);
                    await connection.OpenAsync();
                    await using var cmd = new NpgsqlCommand("""
                        UPDATE public."Companies"
                        SET "IsDeleted" = FALSE, "IsActive" = TRUE
                        WHERE "CompanyCode" = @code AND COALESCE("IsDeleted", FALSE) = TRUE
                        """, connection);
                    cmd.Parameters.AddWithValue("code", companyCode);
                    return await cmd.ExecuteNonQueryAsync() > 0;
                }
            }
            catch
            {
                return false;
            }

            return false;
        }


        /// <summary>
        /// Update company profile fields in database + local index (enterprise in-place edit).
        /// </summary>
        public static async Task<bool> UpdateCompanyProfileAsync(StoredCoRec profile)
        {
            if (profile == null || string.IsNullOrWhiteSpace(profile.Code))
                return false;

            var dbOk = await TryUpdateInDatabaseAsync(profile);

            // Always persist metadata to local index for offline / registry views.
            var existingList = await CoLocalStore.LoadAsync();
            var existing = existingList.FirstOrDefault(c =>
                string.Equals(c.Code, profile.Code, StringComparison.OrdinalIgnoreCase));

            if (existing != null)
            {
                existing.Name = profile.Name;
                existing.NameEn = profile.NameEn;
                existing.TaxNumber = profile.TaxNumber;
                existing.Email = profile.Email;
                existing.Phone = profile.Phone;
                existing.Mobile = profile.Mobile;
                existing.AddressLine1 = profile.AddressLine1;
                existing.City = profile.City;
                existing.Country = profile.Country;
                existing.CurrencyCode = profile.CurrencyCode;
                existing.License = profile.License;
                await CoLocalStore.SaveCompanyAsync(existing);
            }
            else
            {
                profile.Enabled = true;
                await CoLocalStore.SaveCompanyAsync(profile);
            }

            return dbOk || true; // local save succeeded
        }

        private static async Task<bool> TryUpdateInDatabaseAsync(StoredCoRec profile)
        {
            try
            {
                var connectionString = ResolveConnectionString();
                if (string.IsNullOrWhiteSpace(connectionString))
                    return false;

                var provider = DatabaseRuntime.GetProvider();
                if (DatabaseRuntime.IsSqlite(provider))
                {
                    SqliteSchemaBootstrapper.EnsureDatabase(connectionString);
                    await using var connection = new SqliteConnection(connectionString);
                    await connection.OpenAsync();
                    await using var cmd = new SqliteCommand("""
                        UPDATE companies SET
                            company_name_ar = @nameAr,
                            company_name_en = @nameEn,
                            email = @email,
                            phone = @phone,
                            mobile = @mobile,
                            address_line1 = @address,
                            commercial_registration = @tax,
                            currency_code = @currency
                        WHERE company_code = @code AND is_deleted = 0
                        """, connection);
                    cmd.Parameters.AddWithValue("@nameAr", profile.Name ?? "");
                    cmd.Parameters.AddWithValue("@nameEn", profile.NameEn ?? profile.Name ?? "");
                    cmd.Parameters.AddWithValue("@email", (object?)profile.Email ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@phone", (object?)profile.Phone ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@mobile", (object?)profile.Mobile ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@address", (object?)profile.AddressLine1 ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@tax", (object?)(profile.TaxNumber ?? profile.License) ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@currency", string.IsNullOrWhiteSpace(profile.CurrencyCode) ? "USD" : profile.CurrencyCode);
                    cmd.Parameters.AddWithValue("@code", profile.Code);
                    return await cmd.ExecuteNonQueryAsync() > 0;
                }

                if (DatabaseRuntime.IsPostgreSql(provider))
                {
                    await using var connection = new NpgsqlConnection(connectionString);
                    await connection.OpenAsync();
                    await using var cmd = new NpgsqlCommand("""
                        UPDATE public."Companies" SET
                            "CompanyNameAR" = @nameAr,
                            "CompanyNameEN" = @nameEn,
                            "Email" = @email,
                            "Phone" = @phone,
                            "Mobile" = @mobile,
                            "AddressLine1" = @address,
                            "CommercialRegistration" = @tax,
                            "CurrencyCode" = @currency
                        WHERE "CompanyCode" = @code AND COALESCE("IsDeleted", FALSE) = FALSE
                        """, connection);
                    cmd.Parameters.AddWithValue("nameAr", profile.Name ?? "");
                    cmd.Parameters.AddWithValue("nameEn", profile.NameEn ?? profile.Name ?? "");
                    cmd.Parameters.AddWithValue("email", (object?)profile.Email ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("phone", (object?)profile.Phone ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("mobile", (object?)profile.Mobile ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("address", (object?)profile.AddressLine1 ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("tax", (object?)(profile.TaxNumber ?? profile.License) ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("currency", string.IsNullOrWhiteSpace(profile.CurrencyCode) ? "USD" : profile.CurrencyCode);
                    cmd.Parameters.AddWithValue("code", profile.Code);
                    return await cmd.ExecuteNonQueryAsync() > 0;
                }
            }
            catch
            {
                return false;
            }

            return false;
        }

        private static string? ResolveConnectionString()
        {
            try
            {
                return DatabaseRuntime.GetConnectionString();
            }
            catch
            {
                var connectionString = AppCfgSvc.Current?.ConnectionStrings?
                    .FirstOrDefault(kvp => kvp.Key.Equals("Default", StringComparison.OrdinalIgnoreCase)).Value?.ConnectionString;
                if (string.IsNullOrWhiteSpace(connectionString))
                    connectionString = AppCfgSvc.Current?.ConnectionStrings?.Values?.FirstOrDefault()?.ConnectionString;
                return connectionString;
            }
        }

        private static async Task<List<CompanyInfo>> LoadFromDatabaseAsync()
        {
            var result = new List<CompanyInfo>();
            try
            {
                var connectionString = ResolveConnectionString();
                if (string.IsNullOrWhiteSpace(connectionString))
                    return result;

                var provider = DatabaseRuntime.GetProvider();
                if (DatabaseRuntime.IsSqlite(provider))
                    return await LoadFromSqliteAsync(connectionString);

                if (DatabaseRuntime.IsPostgreSql(provider))
                    return await LoadFromPostgreSqlAsync(connectionString);
            }
            catch
            {
                return result;
            }

            return result;
        }

        private static async Task<List<CompanyInfo>> LoadFromPostgreSqlAsync(string connectionString)
        {
            var result = new List<CompanyInfo>();
            try
            {
                await using var connection = new NpgsqlConnection(connectionString);
                await connection.OpenAsync();
                await using var command = new NpgsqlCommand("""
                    SELECT "CompanyCode", "CompanyNameAR", "CompanyNameEN"
                    FROM public."Companies"
                    WHERE COALESCE("IsDeleted", FALSE) = FALSE AND COALESCE("IsActive", TRUE) = TRUE
                    ORDER BY "CompanyNameAR"
                    LIMIT 1000;
                    """, connection);
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    var code = reader["CompanyCode"]?.ToString() ?? string.Empty;
                    result.Add(new CompanyInfo
                    {
                        Code = code,
                        Name = reader["CompanyNameAR"]?.ToString() ?? string.Empty,
                        NameEn = reader["CompanyNameEN"]?.ToString() ?? string.Empty,
                        Database = connection.Database,
                        Enabled = true,
                        IsDefault = string.Equals(code, AppCfgSvc.Current?.MultiCompany?.DefaultCompanyCode, StringComparison.OrdinalIgnoreCase)
                    });
                }
            }
            catch
            {
            }
            return result;
        }

        private static async Task<List<CompanyInfo>> LoadFromSqliteAsync(string connectionString)
        {
            var result = new List<CompanyInfo>();
            try
            {
                SqliteSchemaBootstrapper.EnsureDatabase(connectionString);
                await using var connection = new SqliteConnection(connectionString);
                await connection.OpenAsync();
                await using var command = new SqliteCommand("""
                    SELECT company_code, company_name_ar, company_name_en
                    FROM companies WHERE is_deleted=0 AND is_active=1
                    ORDER BY company_name_ar LIMIT 1000
                    """, connection);
                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    var code = reader["company_code"]?.ToString() ?? string.Empty;
                    result.Add(new CompanyInfo
                    {
                        Code = code,
                        Name = reader["company_name_ar"]?.ToString() ?? string.Empty,
                        NameEn = reader["company_name_en"]?.ToString() ?? string.Empty,
                        Database = connection.DataSource,
                        Enabled = true,
                        IsDefault = string.Equals(code, AppCfgSvc.Current?.MultiCompany?.DefaultCompanyCode, StringComparison.OrdinalIgnoreCase)
                    });
                }
            }
            catch
            {
            }
            return result;
        }
    }
}
