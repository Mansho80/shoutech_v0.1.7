using System;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Linq;
using System.Diagnostics;
using System.Data.Common;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using Microsoft.Data.SqlClient;
using ShouTech.App.Services.Online;

namespace ShouTech.App.Services;

public sealed class BkpServ : IBkpServ
{
    private static readonly byte[] Magic = Encoding.ASCII.GetBytes("STBK1");
    private readonly ILogServ _log;
    private readonly string? _connectionString;
    private readonly string _provider;
    private readonly byte[]? _encryptionKey;
    private readonly ICloudBackupUploader? _uploader;

    public BkpServ(ILicServ lic, IPermServ perm, ILogServ log)
        : this(log, ResolveConnectionString(), ResolveBackupKey())
    {
        _ = lic ?? throw new ArgumentNullException(nameof(lic));
        _ = perm ?? throw new ArgumentNullException(nameof(perm));
    }

    public BkpServ(ILogServ log, IDevInfoSv devInfo, ISyncServ sync)
        : this(log, devInfo, sync, CreateConfiguredUploader())
    {
    }

    public BkpServ(ILogServ log, IDevInfoSv devInfo, ISyncServ sync, ICloudBackupUploader? uploader)
        : this(log, ResolveConnectionString(), ResolveBackupKey(), uploader)
    {
        _ = devInfo ?? throw new ArgumentNullException(nameof(devInfo));
        _ = sync ?? throw new ArgumentNullException(nameof(sync));
    }

    internal BkpServ(ILogServ log, string? connectionString, byte[]? encryptionKey)
        : this(log, connectionString, encryptionKey, null)
    {
    }

    internal BkpServ(ILogServ log, string? connectionString, byte[]? encryptionKey, ICloudBackupUploader? uploader)
    {
        _log = log ?? throw new ArgumentNullException(nameof(log));
        _connectionString = connectionString;
        _provider = DatabaseRuntime.GetProvider();
        _encryptionKey = encryptionKey;
        _uploader = uploader;
    }

    public async Task<string> CreateBackupAsync(string companyCode, CancellationToken ct = default)
    {
        ValidateReady(companyCode);
        var root = GetBackupDirectory(companyCode);
        Directory.CreateDirectory(root);
        var stamp = DateTime.UtcNow.ToString(
            "yyyyMMdd_HHmmss",
            CultureInfo.InvariantCulture);
        var rawPath = Path.Combine(root, $"{companyCode}_FULL_{stamp}.bak.tmp");
        var outputPath = Path.Combine(root, $"{companyCode}_FULL_{stamp}.stbak");

        try
        {
            await CreateDatabaseBackupAsync(rawPath, ct).ConfigureAwait(false);
            await EncryptBackupAsync(rawPath, outputPath, ct).ConfigureAwait(false);
            File.Delete(rawPath);
            _log.LogInfo("Backup", $"Encrypted database backup created: {outputPath}");
            return outputPath;
        }
        catch
        {
            DeleteIfExists(rawPath);
            DeleteIfExists(outputPath);
            throw;
        }
    }

    public async Task RestoreBackupAsync(string backupFilePath, CancellationToken ct = default)
    {
        if (!await ValidateBackupAsync(backupFilePath, ct).ConfigureAwait(false))
            throw new InvalidDataException("Backup integrity validation failed.");

        _log.LogInfo("Backup", $"Backup validated for restore: {backupFilePath}");
    }

    public async Task<bool> ValidateBackupAsync(string backupFilePath, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(backupFilePath) || !File.Exists(backupFilePath) || _encryptionKey == null)
            return false;

        try
        {
            await using var input = File.OpenRead(backupFilePath);
            var magic = new byte[Magic.Length];
            await input.ReadExactlyAsync(magic, ct).ConfigureAwait(false);
            if (!magic.AsSpan().SequenceEqual(Magic))
                return false;

            var nonce = new byte[12];
            var tag = new byte[16];
            await input.ReadExactlyAsync(nonce, ct).ConfigureAwait(false);
            await input.ReadExactlyAsync(tag, ct).ConfigureAwait(false);
            var encrypted = new byte[input.Length - Magic.Length - nonce.Length - tag.Length];
            await input.ReadExactlyAsync(encrypted, ct).ConfigureAwait(false);
            var plaintext = new byte[encrypted.Length];
            using var aes = new AesGcm(_encryptionKey, 16);
            aes.Decrypt(nonce, encrypted, tag, plaintext);
            using var archive = new ZipArchive(new MemoryStream(plaintext), ZipArchiveMode.Read, leaveOpen: false);
            return archive.GetEntry("database.dump") != null;
        }
        catch (CryptographicException)
        {
            return false;
        }
        catch (InvalidDataException)
        {
            return false;
        }
    }

    public void PerformBackup() => _ = CreateBackupAsync("001");

    public BackupResult PerformRotatedBackup()
    {
        try
        {
            var path = CreateBackupAsync("001").GetAwaiter().GetResult();
            return new BackupResult { Success = true, LocalPath = path };
        }
        catch (Exception ex)
        {
            _log.LogError("Backup", "PerformRotatedBackup failed", ex);
            return new BackupResult { Success = false, Message = ex.Message };
        }
    }

    public bool IsBackupDue()
    {
        var root = GetBackupDirectory("001");
        if (!Directory.Exists(root))
            return true;

        var latest = Directory.GetFiles(root, "*.stbak")
            .Select(File.GetLastWriteTimeUtc)
            .DefaultIfEmpty(DateTime.MinValue)
            .Max();
        return latest == DateTime.MinValue || DateTime.UtcNow - latest >= TimeSpan.FromHours(24);
    }

    public async Task<BackupResult> RunOnlineBackupCycleAsync(bool force = false, CancellationToken ct = default)
    {
        try
        {
            if (!force && !IsBackupDue())
                return new BackupResult { Success = true, Message = "Backup is not due." };
            var path = await CreateBackupAsync("001", ct).ConfigureAwait(false);
            RotateBackups(GetBackupDirectory("001"), 30);
            var uploaded = await TryUploadRotatedBackupsAsync(ct).ConfigureAwait(false);
            return new BackupResult { Success = true, LocalPath = path, Uploaded = uploaded };
        }
        catch (Exception ex)
        {
            _log.LogError("Backup", "RunOnlineBackupCycleAsync failed", ex);
            return new BackupResult { Success = false, Message = ex.Message };
        }
    }

    public async Task<bool> TryUploadRotatedBackupsAsync(CancellationToken ct = default)
    {
        if (_uploader == null)
            return false;

        var files = Directory.Exists(GetBackupDirectory("001"))
            ? Directory.GetFiles(GetBackupDirectory("001"), "*.stbak")
            : Array.Empty<string>();
        foreach (var file in files.OrderByDescending(File.GetLastWriteTimeUtc))
        {
            await _uploader.UploadAsync(file, ct).ConfigureAwait(false);
            return true;
        }
        return false;
    }

    private async Task CreateDatabaseBackupAsync(string path, CancellationToken ct)
    {
        if (DatabaseRuntime.IsSqlite(_provider))
        {
            await CreateSqliteBackupAsync(path, ct).ConfigureAwait(false);
            return;
        }

        var dumpTool = Environment.GetEnvironmentVariable("SHOUTECH_PG_DUMP_PATH") ?? "pg_dump";
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = dumpTool,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };
        process.StartInfo.ArgumentList.Add("--format=custom");
        process.StartInfo.ArgumentList.Add("--no-owner");
        process.StartInfo.ArgumentList.Add("--file");
        process.StartInfo.ArgumentList.Add(path);
        process.StartInfo.ArgumentList.Add("--dbname");
        process.StartInfo.ArgumentList.Add(_connectionString!);
        if (!process.Start())
            throw new InvalidOperationException($"Unable to start {dumpTool}.");

        await process.WaitForExitAsync(ct).ConfigureAwait(false);
        var error = await process.StandardError.ReadToEndAsync(ct).ConfigureAwait(false);
        if (process.ExitCode != 0)
            throw new InvalidOperationException($"{dumpTool} failed with exit code {process.ExitCode}: {error.Trim()}");
    }

    private async Task CreateSqliteBackupAsync(string path, CancellationToken ct)
    {
        var sourcePath = DatabaseRuntime.GetSqliteDataSource(_connectionString);
        if (string.IsNullOrWhiteSpace(sourcePath) || string.Equals(sourcePath, ":memory:", StringComparison.Ordinal) || sourcePath.StartsWith("file:", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("SQLite backup requires a file-based database.");
        if (!File.Exists(sourcePath))
            throw new FileNotFoundException("SQLite database file was not found.", sourcePath);

        DeleteIfExists(path);
        await using var source = new SqliteConnection(new SqliteConnectionStringBuilder(DatabaseRuntime.NormalizeSqliteConnectionString(_connectionString!))
        {
            Mode = SqliteOpenMode.ReadWrite
        }.ToString());
        await source.OpenAsync(ct).ConfigureAwait(false);
        await using var destination = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = path,
            Mode = SqliteOpenMode.ReadWriteCreate
        }.ToString());
        await destination.OpenAsync(ct).ConfigureAwait(false);
        source.BackupDatabase(destination);
    }

    private async Task EncryptBackupAsync(string inputPath, string outputPath, CancellationToken ct)
    {
        var nonce = RandomNumberGenerator.GetBytes(12);
        var tag = new byte[16];
        var tempArchive = inputPath + ".zip";
        try
        {
            using (var archive = ZipFile.Open(tempArchive, ZipArchiveMode.Create))
                archive.CreateEntryFromFile(inputPath, "database.dump", CompressionLevel.Optimal);

            await using var input = File.OpenRead(tempArchive);
            await using var output = File.Create(outputPath);
            await output.WriteAsync(Magic, ct).ConfigureAwait(false);
            await output.WriteAsync(nonce, ct).ConfigureAwait(false);
            await output.WriteAsync(tag, ct).ConfigureAwait(false);
            using var aes = new AesGcm(_encryptionKey!, 16);
            var data = new byte[input.Length];
            await input.ReadExactlyAsync(data, ct).ConfigureAwait(false);
            var encrypted = new byte[data.Length];
            aes.Encrypt(nonce, data, encrypted, tag);
            output.Position = Magic.Length + nonce.Length;
            await output.WriteAsync(tag, ct).ConfigureAwait(false);
            await output.WriteAsync(encrypted, ct).ConfigureAwait(false);
        }
        finally
        {
            DeleteIfExists(tempArchive);
        }
    }

    private void ValidateReady(string companyCode)
    {
        if (string.IsNullOrWhiteSpace(companyCode))
            throw new ArgumentException("Company code is required.", nameof(companyCode));
        if (_connectionString == null)
            throw new InvalidOperationException("Database backup is unavailable: connection string is not configured.");
        if (_encryptionKey == null)
            throw new InvalidOperationException("Database backup is unavailable: SHOUTECH_BACKUP_KEY must be a 32-byte base64 key.");
    }

    private static string GetBackupDirectory(string companyCode) =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ShouTech", "ERP", "Backups", companyCode);

    private static string? ResolveConnectionString() => DatabaseRuntime.GetConnectionString();

    private static byte[]? ResolveBackupKey()
    {
        var value = Environment.GetEnvironmentVariable("SHOUTECH_BACKUP_KEY");
        if (string.IsNullOrWhiteSpace(value))
            return null;
        try
        {
            var key = Convert.FromBase64String(value);
            return key.Length == 32 ? key : null;
        }
        catch (FormatException)
        {
            return null;
        }
    }

    private static HttpCloudBackupUploader? CreateConfiguredUploader()
    {
        var endpoint = Environment.GetEnvironmentVariable("SHOUTECH_BACKUP_UPLOAD_ENDPOINT");
        var token = Environment.GetEnvironmentVariable("SHOUTECH_BACKUP_UPLOAD_TOKEN");
        return Uri.TryCreate(endpoint, UriKind.Absolute, out var uri) && !string.IsNullOrWhiteSpace(token)
            ? new HttpCloudBackupUploader(new HttpClient { Timeout = TimeSpan.FromMinutes(10) }, uri, token)
            : null;
    }

    private static void DeleteIfExists(string path)
    {
        if (File.Exists(path))
            File.Delete(path);
    }

    private static void RotateBackups(string root, int maxBackups)
    {
        if (!Directory.Exists(root))
            return;

        var backups = Directory.GetFiles(root, "*.stbak")
            .OrderByDescending(File.GetLastWriteTimeUtc)
            .Skip(maxBackups)
            .ToArray();
        foreach (var backup in backups)
            File.Delete(backup);
    }

}
