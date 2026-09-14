using System;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;

namespace ShouTech.App.Services;

public interface ICloudBackupUploader
{
    Task UploadAsync(string backupPath, CancellationToken ct = default);
}

/// <summary>
/// Provider-neutral HTTPS uploader. It is disabled unless both endpoint and
/// bearer token are explicitly configured through environment variables.
/// </summary>
public sealed class HttpCloudBackupUploader : ICloudBackupUploader
{
    private readonly HttpClient _httpClient;
    private readonly Uri _endpoint;
    private readonly string _token;

    public HttpCloudBackupUploader(HttpClient httpClient, Uri endpoint, string token)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _endpoint = endpoint ?? throw new ArgumentNullException(nameof(endpoint));
        if (!_endpoint.Scheme.Equals(Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("Cloud backup endpoint must use HTTPS.", nameof(endpoint));
        _token = string.IsNullOrWhiteSpace(token) ? throw new ArgumentException("Token is required.", nameof(token)) : token;
    }

    public async Task UploadAsync(string backupPath, CancellationToken ct = default)
    {
        if (!File.Exists(backupPath))
            throw new FileNotFoundException("Backup file not found.", backupPath);

        var fileName = Path.GetFileName(backupPath);
        var contentHash = await ComputeHashAsync(backupPath, ct).ConfigureAwait(false);
        for (var attempt = 1; attempt <= 3; attempt++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Put, _endpoint);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _token);
            request.Headers.Add("Idempotency-Key", fileName);
            request.Headers.Add("X-Backup-SHA256", contentHash);
            await using var stream = File.OpenRead(backupPath);
            request.Content = new StreamContent(stream);
            request.Content.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
            using var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct)
                .ConfigureAwait(false);
            if (response.IsSuccessStatusCode)
                return;
            if (attempt == 3 || ((int)response.StatusCode < 500 && response.StatusCode != System.Net.HttpStatusCode.RequestTimeout))
                response.EnsureSuccessStatusCode();
            await Task.Delay(TimeSpan.FromSeconds(attempt), ct).ConfigureAwait(false);
        }
    }

    private static async Task<string> ComputeHashAsync(string path, CancellationToken ct)
    {
        await using var stream = File.OpenRead(path);
        using var sha = SHA256.Create();
        var hash = await sha.ComputeHashAsync(stream, ct).ConfigureAwait(false);
        return Convert.ToHexString(hash);
    }
}
