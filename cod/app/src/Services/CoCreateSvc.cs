using System.Data;
using System.Globalization;
using System.IO;
using Microsoft.Data.Sqlite;
using Npgsql;
using NpgsqlTypes;
using ShouTech.App.Common;
using ShouTech.App.Configuration;

namespace ShouTech.App.Services
{
    public sealed class CoCreateSvc : ICoCreateSvc
    {
        public async Task<CoCreateResult> CreateAsync(NewCoReq request)
        {
            var companyId = Guid.NewGuid();
            var code = await ResolveCompanyCodeAsync();
            var pwdHashResult = PwdHash.Create(request.AdminPassword);
            var hash = pwdHashResult.Hash;
            var salt = pwdHashResult.Salt;
            var fullName = string.IsNullOrWhiteSpace(request.AdminFullName)
                ? request.AdminUsername
                : request.AdminFullName;

            var record = new StoredCoRec
            {
                CompanyId = companyId,
                Code = code,
                Name = request.CompanyNameAr.Trim(),
                NameEn = string.IsNullOrWhiteSpace(request.CompanyNameEn)
                    ? request.CompanyNameAr.Trim()
                    : request.CompanyNameEn.Trim(),
                Email = request.Email.Trim(),
                Phone = request.Phone.Trim(),
                Mobile = request.Mobile.Trim(),
                AddressLine1 = request.AddressLine1?.Trim() ?? string.Empty,
				AddressLine2 = request.AddressLine2?.Trim() ?? string.Empty,
				City = request.City?.Trim() ?? string.Empty,
				Country = request.Country?.Trim() ?? string.Empty,
                License = request.License.Trim(),
                Notes = request.Notes.Trim(),
                FiscalYearStart = request.FiscalYearStart.Date,
                FiscalYearEnd = request.FiscalYearEnd.Date,
                CurrencyCode = request.CurrencyCode,
                DecimalPlaces = request.DecimalPlaces,
                CalendarType = request.CalendarType,
                NumberGrouping = request.NumberGrouping,
                AdminUsername = request.AdminUsername.Trim(),
                AdminPasswordHash = hash,
                AdminPasswordSalt = salt,
                AdminFullName = fullName,
                DatabaseProvider = string.IsNullOrWhiteSpace(request.DatabaseProvider) ? "SQLite" : request.DatabaseProvider.Trim(),
                DbPath = request.DbPath.Trim(),
                BackupPath = request.BackupPath.Trim(),
                AltDbPath = request.AltDbPath.Trim(),
                AltBackupPath = request.AltBackupPath.Trim(),
                AutoBackup = request.AutoBackup,
                BackupSchedule = request.BackupSchedule.Trim(),
                BackupTime = request.BackupTime.Trim()
            };

            var savedToDb = await TrySaveToDatabaseAsync(record, request);
            await CoLocalStore.SaveCompanyAsync(record);

            return new CoCreateResult
            {
                Success = true,
                CompanyCode = code,
                CompanyNameAr = record.Name,
                SavedToDatabase = savedToDb,
                SavedLocally = true,
                Message = savedToDb
                    ? "تم إنشاء الشركة وتسجيلها في قاعدة البيانات."
                    : "تم إنشاء الشركة وحفظها محلياً (قاعدة البيانات غير متاحة)."
            };
        }

        private static async Task<string> ResolveCompanyCodeAsync()
        {
            var localCode = await CoLocalStore.GenerateNextCodeAsync();
            var dbCode = await TryGenerateDbCodeAsync();

            if (string.IsNullOrWhiteSpace(dbCode))
                return localCode;

            if (int.TryParse(localCode, out var localNum) &&
                int.TryParse(dbCode, out var dbNum))
            {
                return Math.Max(localNum, dbNum).ToString("000", CultureInfo.InvariantCulture);
            }

            return dbCode;
        }

        private static async Task<string?> TryGenerateDbCodeAsync()
        {
            try
            {
                var connectionString = ResolveConnectionString();
                if (string.IsNullOrWhiteSpace(connectionString))
                    return null;

                var provider = DatabaseRuntime.GetProvider();
                if (DatabaseRuntime.IsSqlite(provider))
                    return await TryGenerateSqliteCodeAsync(connectionString);

                await using var connection = new NpgsqlConnection(connectionString);
                await connection.OpenAsync();

                const string sql = """
                    SELECT MAX(
                        CASE
                            WHEN "CompanyCode" ~ '^[0-9]+$' THEN "CompanyCode"::integer
                        END)
                    FROM public."Companies"
                    WHERE "IsDeleted" = FALSE;
                    """;

                await using var command = new NpgsqlCommand(sql, connection);
                var value = await command.ExecuteScalarAsync();
                var max = value is int i ? i : value is decimal d ? (int)d : 0;
                return (max + 1).ToString("000", CultureInfo.InvariantCulture);
            }
            catch
            {
                return null;
            }
        }

        private static async Task<bool> TrySaveToDatabaseAsync(StoredCoRec record, NewCoReq request)
        {
            try
            {
                var connectionString = ResolveConnectionString();
                if (string.IsNullOrWhiteSpace(connectionString))
                    return false;

                var provider = DatabaseRuntime.GetProvider();
                if (DatabaseRuntime.IsSqlite(provider))
                    return await TrySaveToSqliteAsync(record, connectionString);

                await using var connection = new NpgsqlConnection(connectionString);
                await connection.OpenAsync();
                await using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    const string insertCompany = """
                        INSERT INTO public."Companies"
                        (
                            "CompanyID", "CompanyCode", "CompanyNameAR", "CompanyNameEN",
                            "Email", "Phone", "Mobile", "AddressLine1", "CommercialRegistration",
                            "CurrencyCode", "LanguageCode", "IsActive", "IsDeleted"
                        )
                        VALUES
                        (
                            @CompanyId, @Code, @NameAr, @NameEn,
                            @Email, @Phone, @Mobile, @Address, @License,
                            @Currency, 'ar-SY', TRUE, FALSE
                        );
                        """;

                    await using (var cmd = new NpgsqlCommand(insertCompany, connection, transaction))
                    {
                        cmd.Parameters.Add("@CompanyId", NpgsqlDbType.Uuid).Value = record.CompanyId;
                        cmd.Parameters.Add("@Code", NpgsqlDbType.Varchar).Value = record.Code;
                        cmd.Parameters.Add("@NameAr", NpgsqlDbType.Varchar).Value = record.Name;
                        cmd.Parameters.Add("@NameEn", NpgsqlDbType.Varchar).Value = record.NameEn;
                        cmd.Parameters.Add("@Email", NpgsqlDbType.Varchar).Value = NullIfEmpty(record.Email);
                        cmd.Parameters.Add("@Phone", NpgsqlDbType.Varchar).Value = NullIfEmpty(record.Phone);
                        cmd.Parameters.Add("@Mobile", NpgsqlDbType.Varchar).Value = NullIfEmpty(record.Mobile);
                        cmd.Parameters.Add("@Address", NpgsqlDbType.Varchar).Value = NullIfEmpty(record.AddressLine1);
                        cmd.Parameters.Add("@License", NpgsqlDbType.Varchar).Value = NullIfEmpty(record.License);
                        cmd.Parameters.Add("@Currency", NpgsqlDbType.Char).Value = record.CurrencyCode;
                        await cmd.ExecuteNonQueryAsync();
                    }

                    var fiscalYear = record.FiscalYearStart.Year;
                    var dbName = string.IsNullOrWhiteSpace(record.DbPath)
                        ? $"SHOUTECH_{record.Code}_{fiscalYear}"
                        : Path.GetFileName(record.DbPath.TrimEnd('\\', '/'));

                    const string insertFiscal = """
                        INSERT INTO public."FiscalYears"
                        (
                            "CompanyID", "FiscalYear", "DatabaseName", "StartDate", "EndDate", "IsCurrent", "IsClosed"
                        )
                        VALUES
                        (
                            @CompanyId, @FiscalYear, @DbName, @StartDate, @EndDate, TRUE, FALSE
                        );
                        """;

                    await using (var cmd = new NpgsqlCommand(insertFiscal, connection, transaction))
                    {
                        cmd.Parameters.Add("@CompanyId", NpgsqlDbType.Uuid).Value = record.CompanyId;
                        cmd.Parameters.Add("@FiscalYear", NpgsqlDbType.Integer).Value = fiscalYear;
                        cmd.Parameters.Add("@DbName", NpgsqlDbType.Varchar).Value = dbName;
                        cmd.Parameters.Add("@StartDate", NpgsqlDbType.Date).Value = record.FiscalYearStart;
                        cmd.Parameters.Add("@EndDate", NpgsqlDbType.Date).Value = record.FiscalYearEnd;
                        await cmd.ExecuteNonQueryAsync();
                    }

                    const string insertUser = """
                        INSERT INTO public."Users"
                        (
                            "CompanyID", "Username", "PasswordHash", "PasswordSalt",
                            "FullNameAR", "FullNameEN", "Email", "MustChangePassword", "IsActive", "IsDeleted"
                        )
                        VALUES
                        (
                            @CompanyId, @Username, @Hash, @Salt,
                            @FullName, @FullName, @Email, FALSE, TRUE, FALSE
                        );
                        """;

                    await using (var cmd = new NpgsqlCommand(insertUser, connection, transaction))
                    {
                        cmd.Parameters.Add("@CompanyId", NpgsqlDbType.Uuid).Value = record.CompanyId;
                        cmd.Parameters.Add("@Username", NpgsqlDbType.Varchar).Value = record.AdminUsername;
                        cmd.Parameters.Add("@Hash", NpgsqlDbType.Varchar).Value = record.AdminPasswordHash;
                        cmd.Parameters.Add("@Salt", NpgsqlDbType.Varchar).Value = record.AdminPasswordSalt;
                        cmd.Parameters.Add("@FullName", NpgsqlDbType.Varchar).Value = record.AdminFullName;
                        cmd.Parameters.Add("@Email", NpgsqlDbType.Varchar).Value = NullIfEmpty(record.Email);
                        await cmd.ExecuteNonQueryAsync();
                    }

                    await transaction.CommitAsync();
                    return true;
                }
                catch
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            }
            catch (Exception ex)
            {
                AppHost.Logging.LogWarning("CoCreateSvc", $"Database save failed: {ex.Message}");
                return false;
            }
        }

        private static async Task<string?> TryGenerateSqliteCodeAsync(string connectionString)
        {
            SqliteSchemaBootstrapper.EnsureDatabase(connectionString);
            await using var connection = new SqliteConnection(connectionString);
            await connection.OpenAsync();
            await using var command = new SqliteCommand(
                "SELECT COALESCE(MAX(CAST(company_code AS INTEGER)), 0) FROM companies WHERE is_deleted=0", connection);
            var max = Convert.ToInt32(await command.ExecuteScalarAsync(), CultureInfo.InvariantCulture);
            return (max + 1).ToString("000", CultureInfo.InvariantCulture);
        }

        private static async Task<bool> TrySaveToSqliteAsync(StoredCoRec record, string connectionString)
        {
            SqliteSchemaBootstrapper.EnsureDatabase(connectionString);
            await using var connection = new SqliteConnection(connectionString);
            await connection.OpenAsync();
            await using SqliteTransaction transaction = (SqliteTransaction)await connection.BeginTransactionAsync();
            try
            {
                await ExecuteSqliteAsync(connection, transaction, """
                    INSERT INTO companies
                        (company_id, company_code, company_name_ar, company_name_en, email, phone, mobile, address_line1,
                         commercial_registration, currency_code, language_code)
                    VALUES (@id, @code, @name, @nameEn, @email, @phone, @mobile, @address, @license, @currency, 'ar-SY')
                    """, ("id", record.CompanyId.ToString()), ("code", record.Code), ("name", record.Name),
                    ("nameEn", record.NameEn), ("email", NullIfEmpty(record.Email)), ("phone", NullIfEmpty(record.Phone)),
                    ("mobile", NullIfEmpty(record.Mobile)), ("address", NullIfEmpty(record.AddressLine1)),
                    ("license", NullIfEmpty(record.License)), ("currency", record.CurrencyCode));
                var fiscalYear = record.FiscalYearStart.Year;
                await ExecuteSqliteAsync(connection, transaction, """
                    INSERT INTO fiscal_years (company_id, fiscal_year, database_name, start_date, end_date)
                    VALUES (@companyId, @year, @dbName, @start, @end)
                    """, ("companyId", record.CompanyId.ToString()), ("year", fiscalYear),
                    ("dbName", string.IsNullOrWhiteSpace(record.DbPath) ? $"SHOUTECH_{record.Code}_{fiscalYear}" : Path.GetFileName(record.DbPath.TrimEnd('\\', '/'))),
                    ("start", record.FiscalYearStart.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)),
                    ("end", record.FiscalYearEnd.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)));
                await ExecuteSqliteAsync(connection, transaction, """
                    INSERT INTO users
                        (user_id, company_id, username, password_hash, password_salt, full_name, full_name_ar, full_name_en, email, is_super_admin)
                    VALUES (@userId, @companyId, @username, @hash, @salt, @fullName, @fullName, @fullName, @email, 1)
                    """, ("userId", Guid.NewGuid().ToString()), ("companyId", record.CompanyId.ToString()),
                    ("username", record.AdminUsername), ("hash", record.AdminPasswordHash), ("salt", record.AdminPasswordSalt),
                    ("fullName", record.AdminFullName), ("email", NullIfEmpty(record.Email)));
                await transaction.CommitAsync();
                return true;
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        private static async Task ExecuteSqliteAsync(SqliteConnection connection, SqliteTransaction transaction,
            string sql, params (string Name, object Value)[] values)
        {
            await using var command = new SqliteCommand(sql, connection, transaction);
            foreach (var (name, value) in values)
                command.Parameters.AddWithValue("@" + name, value);
            await command.ExecuteNonQueryAsync();
        }

        private static object NullIfEmpty(string value)
            => string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim();

        private static string? ResolveConnectionString()
        {
            return DatabaseRuntime.GetConnectionString();
        }
    }
}
