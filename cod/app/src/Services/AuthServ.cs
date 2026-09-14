using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using Npgsql;
using ShouTech.App.Common;
using ShouTech.App.Configuration;

namespace ShouTech.App.Services
{
    public sealed class AuthServ : IAuthSvc
    {
        private sealed record CredentialProfile(
            string Id,
            string FullName,
            string Email,
            string Role,
            string RoleCode,
            UsrAccLvl AccessLevel,
            bool IsSuperAdmin);

        private sealed record DbUserCredential(
            string UserId,
            string Username,
            string PasswordHash,
            string PasswordSalt,
            string FullName,
            string Email,
            string CompanyCode,
            string CompanyName);

        private static readonly Dictionary<string, CredentialProfile> Profiles = new(System.StringComparer.OrdinalIgnoreCase)
        {
            ["admin"] = new("USR-001", "مدير النظام", "admin@shoutech.com", "Administrator", "ROLE_SUPERADMIN", UsrAccLvl.Administrator, true),
            ["user"] = new("USR-002", "مستخدم تشغيل", "user@shoutech.com", "User", "ROLE_USER", UsrAccLvl.User, false),
            ["viewer"] = new("USR-003", "مستخدم عرض", "viewer@shoutech.com", "Viewer", "ROLE_VIEWER", UsrAccLvl.Viewer, false),
        };

        private UserInfo? _currentUser;

        public bool IsAuthenticated => _currentUser?.IsAuthenticated == true;

        public async Task<AuthResult> LoginAsync(string username, string password)
        {
            var normalizedUser = username?.Trim() ?? string.Empty;
            var hasUsername = !string.IsNullOrWhiteSpace(normalizedUser);

            if (string.IsNullOrEmpty(password))
            {
                return new AuthResult
                {
                    Success = false,
                    Message = "اسم المستخدم أو كلمة المرور غير صحيحة"
                };
            }

            var companyCode = AppState.CurrentCompanyCode ?? string.Empty;

            if (!string.IsNullOrWhiteSpace(companyCode))
            {
                if (hasUsername)
                {
                    var localCompany = await CoLocalStore.FindUserCompanyAsync(companyCode, normalizedUser, password);
                    if (localCompany != null)
                    {
                        _currentUser = BuildCompanyAdminUser(normalizedUser, localCompany);
                        SyncSession(_currentUser);
                        return new AuthResult
                        {
                            Success = true,
                            Message = "تم تسجيل الدخول بنجاح",
                            User = _currentUser
                        };
                    }

                    var dbUser = await TryLoginFromDatabaseAsync(companyCode, normalizedUser, password);
                    if (dbUser != null)
                    {
                        _currentUser = dbUser;
                        SyncSession(_currentUser);
                        return new AuthResult
                        {
                            Success = true,
                            Message = "تم تسجيل الدخول بنجاح",
                            User = _currentUser
                        };
                    }
                }
                else
                {
                    var localCompany = await CoLocalStore.FindCompanyAdminByPasswordAsync(companyCode, password);
                    if (localCompany != null)
                    {
                        var companyAdmin = localCompany.AdminUsername?.Trim();
                        if (!string.IsNullOrWhiteSpace(companyAdmin))
                        {
                            _currentUser = BuildCompanyAdminUser(companyAdmin, localCompany);
                            SyncSession(_currentUser);
                            return new AuthResult
                            {
                                Success = true,
                                Message = "تم تسجيل الدخول بنجاح",
                                User = _currentUser
                            };
                        }
                    }

                    var dbUser = await TryLoginFromDatabaseByPasscodeAsync(companyCode, password);
                    if (dbUser != null)
                    {
                        _currentUser = dbUser;
                        SyncSession(_currentUser);
                        return new AuthResult
                        {
                            Success = true,
                            Message = "تم تسجيل الدخول بنجاح",
                            User = _currentUser
                        };
                    }
                }
            }

            if (!hasUsername)
            {
                normalizedUser = password.Trim();
            }

            if (!Profiles.TryGetValue(normalizedUser, out var profile) || password != normalizedUser)
            {
                return new AuthResult
                {
                    Success = false,
                    Message = "اسم المستخدم أو كلمة المرور غير صحيحة"
                };
            }

            _currentUser = BuildUserInfo(normalizedUser, profile);
            SyncSession(_currentUser);

            return new AuthResult
            {
                Success = true,
                Message = "تم تسجيل الدخول بنجاح",
                User = _currentUser
            };
        }

        public Task LogoutAsync()
        {
            _currentUser = null;
            UsrSession.Clear();
            AppState.CurrentUser = null;
            return Task.CompletedTask;
        }

        public Task<UserInfo?> GetCurrentUserAsync() => Task.FromResult(_currentUser);

        public void SetCurrentUser(UserInfo user)
        {
            _currentUser = user;
            SyncSession(user);
        }

        private static UserInfo BuildCompanyAdminUser(string username, StoredCoRec company)
        {
            return new UserInfo
            {
                Id = company.CompanyId.ToString(),
                Username = username,
                FullName = company.AdminFullName,
                Email = company.Email,
                Role = "Administrator",
                RoleCode = "ROLE_COMPANY_ADMIN",
                AccessLevel = UsrAccLvl.Administrator,
                IsSuperAdmin = true,
                CompanyId = company.Code,
                CompanyName = company.Name,
                IsAuthenticated = true,
                LastLogin = System.DateTime.Now
            };
        }

        private static async Task<UserInfo?> TryLoginFromDatabaseAsync(string companyCode, string username, string password)
        {
            var provider = DatabaseRuntime.GetProvider();
            if (DatabaseRuntime.IsSqlite(provider))
                return await TryLoginFromSqliteAsync(companyCode, username, password);
            try
            {
                var connectionString = DatabaseRuntime.GetConnectionString();
                if (string.IsNullOrWhiteSpace(connectionString))
                    return null;

                await using var connection = new NpgsqlConnection(connectionString);
                await connection.OpenAsync();

                const string sql = """
                    SELECT
                        u."UserID", u."Username", u."PasswordHash", u."PasswordSalt",
                        u."FullNameAR", u."FullNameEN", u."Email",
                        c."CompanyCode", c."CompanyNameAR"
                    FROM public."Users" AS u
                    INNER JOIN public."Companies" AS c ON c."CompanyID" = u."CompanyID"
                    WHERE c."CompanyCode" = @CompanyCode
                      AND u."Username" = @Username
                      AND u."IsActive" = TRUE
                      AND u."IsDeleted" = FALSE
                      AND c."IsActive" = TRUE
                      AND c."IsDeleted" = FALSE
                    LIMIT 1;
                    """;

                await using var command = new NpgsqlCommand(sql, connection);
                command.Parameters.AddWithValue("@CompanyCode", companyCode);
                command.Parameters.AddWithValue("@Username", username);

                await using var reader = await command.ExecuteReaderAsync();
                if (!await reader.ReadAsync())
                    return null;

                var hash = reader["PasswordHash"]?.ToString() ?? string.Empty;
                var salt = reader["PasswordSalt"]?.ToString() ?? string.Empty;

                if (!PwdHash.Verify(password, hash, salt))
                    return null;

                return new UserInfo
                {
                    Id = reader["UserID"]?.ToString() ?? string.Empty,
                    Username = username,
                    FullName = reader["FullNameAR"]?.ToString() ?? username,
                    Email = reader["Email"]?.ToString() ?? string.Empty,
                    Role = "Administrator",
                    RoleCode = "ROLE_COMPANY_ADMIN",
                    AccessLevel = UsrAccLvl.Administrator,
                    IsSuperAdmin = true,
                    CompanyId = reader["CompanyCode"]?.ToString() ?? companyCode,
                    CompanyName = reader["CompanyNameAR"]?.ToString() ?? GetCompanyName(),
                    IsAuthenticated = true,
                    LastLogin = System.DateTime.Now
                };
            }
            catch
            {
                return null;
            }
        }

        private static async Task<UserInfo?> TryLoginFromDatabaseByPasscodeAsync(string companyCode, string password)
        {
            var provider = DatabaseRuntime.GetProvider();
            if (DatabaseRuntime.IsSqlite(provider))
                return await TryLoginFromSqliteByPasscodeAsync(companyCode, password);
            try
            {
                var connectionString = DatabaseRuntime.GetConnectionString();
                if (string.IsNullOrWhiteSpace(connectionString))
                    return null;

                await using var connection = new NpgsqlConnection(connectionString);
                await connection.OpenAsync();

                const string sql = """
                    SELECT
                        u."UserID", u."Username", u."PasswordHash", u."PasswordSalt",
                        u."FullNameAR", u."Email",
                        c."CompanyCode", c."CompanyNameAR"
                    FROM public."Users" AS u
                    INNER JOIN public."Companies" AS c ON c."CompanyID" = u."CompanyID"
                    WHERE c."CompanyCode" = @CompanyCode
                      AND u."IsActive" = TRUE
                      AND u."IsDeleted" = FALSE
                      AND c."IsActive" = TRUE
                      AND c."IsDeleted" = FALSE;
                    """;

                await using var command = new NpgsqlCommand(sql, connection);
                command.Parameters.AddWithValue("@CompanyCode", companyCode);

                await using var reader = await command.ExecuteReaderAsync();
                var matches = new List<DbUserCredential>();

                while (await reader.ReadAsync())
                {
                    var hash = reader["PasswordHash"]?.ToString() ?? string.Empty;
                    var salt = reader["PasswordSalt"]?.ToString() ?? string.Empty;

                    if (!PwdHash.Verify(password, hash, salt))
                        continue;

                    matches.Add(new DbUserCredential(
                        UserId: reader["UserID"]?.ToString() ?? string.Empty,
                        Username: reader["Username"]?.ToString() ?? string.Empty,
                        PasswordHash: hash,
                        PasswordSalt: salt,
                        FullName: reader["FullNameAR"]?.ToString() ?? string.Empty,
                        Email: reader["Email"]?.ToString() ?? string.Empty,
                        CompanyCode: reader["CompanyCode"]?.ToString() ?? companyCode,
                        CompanyName: reader["CompanyNameAR"]?.ToString() ?? GetCompanyName()));
                }

                if (matches.Count != 1)
                    return null;

                var matched = matches[0];
                return new UserInfo
                {
                    Id = matched.UserId,
                    Username = matched.Username,
                    FullName = string.IsNullOrWhiteSpace(matched.FullName) ? matched.Username : matched.FullName,
                    Email = matched.Email,
                    Role = "Administrator",
                    RoleCode = "ROLE_COMPANY_ADMIN",
                    AccessLevel = UsrAccLvl.Administrator,
                    IsSuperAdmin = true,
                    CompanyId = matched.CompanyCode,
                    CompanyName = matched.CompanyName,
                    IsAuthenticated = true,
                    LastLogin = System.DateTime.Now
                };
            }
            catch
            {
                return null;
            }
        }

        private static async Task<UserInfo?> TryLoginFromSqliteAsync(string companyCode, string username, string password)
        {
            var cs = DatabaseRuntime.GetConnectionString();
            if (string.IsNullOrWhiteSpace(cs)) return null;
            await using var db = new SqliteConnection(cs);
            await db.OpenAsync();
            await using var cmd = new SqliteCommand("""
                SELECT u.user_id, u.username, u.password_hash, u.password_salt, u.full_name_ar, u.email,
                       c.company_code, c.company_name_ar
                FROM users u INNER JOIN companies c ON c.company_id=u.company_id
                WHERE c.company_code=@company AND u.username=@username
                  AND u.is_active=1 AND u.is_deleted=0
                  AND c.is_active=1 AND c.is_deleted=0 LIMIT 1
                """, db);
            cmd.Parameters.AddWithValue("@company", companyCode);
            cmd.Parameters.AddWithValue("@username", username);
            await using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync() || !PwdHash.Verify(password, reader["password_hash"]?.ToString() ?? "", reader["password_salt"]?.ToString() ?? ""))
                return null;
            return BuildDatabaseUser(reader["user_id"], username, reader["full_name_ar"], reader["email"], reader["company_code"], reader["company_name_ar"]);
        }

        private static async Task<UserInfo?> TryLoginFromSqliteByPasscodeAsync(string companyCode, string password)
        {
            var cs = DatabaseRuntime.GetConnectionString();
            if (string.IsNullOrWhiteSpace(cs)) return null;
            await using var db = new SqliteConnection(cs);
            await db.OpenAsync();
            await using var cmd = new SqliteCommand("""
                SELECT u.user_id, u.username, u.password_hash, u.password_salt, u.full_name_ar, u.email,
                       c.company_code, c.company_name_ar
                FROM users u INNER JOIN companies c ON c.company_id=u.company_id
                WHERE c.company_code=@company AND u.is_active=1 AND u.is_deleted=0
                  AND c.is_active=1 AND c.is_deleted=0
                """, db);
            cmd.Parameters.AddWithValue("@company", companyCode);
            await using var reader = await cmd.ExecuteReaderAsync();
            UserInfo? match = null;
            while (await reader.ReadAsync())
            {
                if (!PwdHash.Verify(password, reader["password_hash"]?.ToString() ?? "", reader["password_salt"]?.ToString() ?? ""))
                    continue;
                if (match != null) return null;
                match = BuildDatabaseUser(reader["user_id"], reader["username"], reader["full_name_ar"], reader["email"], reader["company_code"], reader["company_name_ar"]);
            }
            return match;
        }

        private static UserInfo BuildDatabaseUser(object id, object username, object fullName, object email, object companyCode, object companyName) => new()
        {
            Id = id.ToString() ?? string.Empty, Username = username.ToString() ?? string.Empty,
            FullName = fullName.ToString() ?? string.Empty, Email = email.ToString() ?? string.Empty,
            Role = "Administrator", RoleCode = "ROLE_COMPANY_ADMIN", AccessLevel = UsrAccLvl.Administrator,
            IsSuperAdmin = true, CompanyId = companyCode.ToString() ?? string.Empty,
            CompanyName = companyName.ToString() ?? string.Empty, IsAuthenticated = true, LastLogin = DateTime.Now
        };

        private static UserInfo BuildUserInfo(string username, CredentialProfile profile)
        {
            return new UserInfo
            {
                Id = profile.Id,
                Username = username,
                FullName = profile.FullName,
                Email = profile.Email,
                Role = profile.Role,
                RoleCode = profile.RoleCode,
                AccessLevel = profile.AccessLevel,
                IsSuperAdmin = profile.IsSuperAdmin,
                CompanyId = AppState.CurrentCompanyCode ?? "MAIN",
                CompanyName = GetCompanyName(),
                IsAuthenticated = true,
                LastLogin = System.DateTime.Now
            };
        }

        private static void SyncSession(UserInfo user)
        {
            UsrSession.Apply(user);

            AppState.CurrentUser = user;
        }

        private static string GetCompanyName()
        {
            if (!string.IsNullOrWhiteSpace(AppState.CurrentCompanyName))
                return AppState.CurrentCompanyName!;

            if (System.Windows.Application.Current?.Properties["SelectedCompany"] is ShouTech.App.Views.CompanyItem company
                && !string.IsNullOrWhiteSpace(company.NameAr))
                return company.NameAr;

            return "الشركة الرئيسية";
        }
    }
}
