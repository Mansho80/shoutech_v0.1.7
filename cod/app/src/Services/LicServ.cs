// shoutech_erp_v0.1.6/cod/app/src/Services/LicServ.cs
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    public interface ILicenseValidationProvider
    {
        Task<LicResult> ValidateAsync(CancellationToken ct = default);
    }

    /// <summary>
    /// Adapter boundary for the future SecEng native component. The native
    /// ABI is intentionally not guessed; production remains fail-closed until
    /// a signed provider is installed and registered.
    /// </summary>
    public sealed class SecEngLicenseProvider : ILicenseValidationProvider
    {
        public Task<LicResult> ValidateAsync(CancellationToken ct = default)
        {
            throw new InvalidOperationException(
                "SecEng license provider is not installed. Configure the signed native provider before production use.");
        }
    }

    /// <summary>
    /// Enterprise license gate.
    /// Controls Viewer mode + dynamic modules visibility/access.
    /// Native dongle/signature validation will be plugged later via P/Invoke.
    /// </summary>
    public sealed class LicServ : ILicServ
    {
        private LicResult _last = new()
        {
            Status = LicStat.NotFound,
            Edition = LicEd.Demo,
            Message = "No license loaded"
        };

        private readonly HashSet<string> _coreModules = new(StringComparer.OrdinalIgnoreCase)
        {
            ModKey.Acc, ModKey.Inv, ModKey.Sales, ModKey.Purch
        };
        private readonly ILicenseValidationProvider? _provider;

        public LicServ(ILicenseValidationProvider? provider = null)
        {
            _provider = provider;
        }

        public LicEd CurrentEdition => _last.Edition;
        public bool CanWrite => _last.CanWrite;

        public async Task<LicResult> ValidateAsync(CancellationToken ct = default)
        {
            var environment = Environment.GetEnvironmentVariable("SHOUTECH_ENVIRONMENT");
            if (!string.Equals(environment, "Development", StringComparison.OrdinalIgnoreCase))
            {
                if (_provider != null)
                    return _last = await _provider.ValidateAsync(ct).ConfigureAwait(false);

                _last = new LicResult
                {
                    Status = LicStat.NotFound,
                    Edition = LicEd.Demo,
                    Message = "No license provider is configured for this environment."
                };
                return _last;
            }

            // Development-only license for offline UI work. Production must use
            // the native security provider and never reaches this branch.
            await Task.Yield();

            var modules = new HashSet<string>(_coreModules, StringComparer.OrdinalIgnoreCase);

            _last = new LicResult
            {
                Status = LicStat.Valid,
                Edition = LicEd.Core,
                ExpiresAt = DateTime.UtcNow.AddYears(1),
                MaxDevices = 3,
                ActiveDevices = 1,
                Message = "License valid (Core)",
                Modules = modules
            };

            return _last;
        }

        public async Task<LicResult> RefreshAsync(CancellationToken ct = default)
        {
            return await ValidateAsync(ct);
        }

        public bool IsModuleEnabled(string moduleKey)
        {
            if (string.IsNullOrWhiteSpace(moduleKey))
                return false;

            // Core modules are always allowed when license is usable and not pure Viewer
            if (_coreModules.Contains(moduleKey))
                return _last.IsUsable && _last.Edition != LicEd.Viewer;

            return _last.Modules.Contains(moduleKey);
        }

        public async Task EnsureUsableAsync(CancellationToken ct = default)
        {
            var r = await ValidateAsync(ct);
            if (!r.IsUsable)
                throw new UnauthorizedAccessException(r.Message ?? "License is not valid.");
        }

        public async Task EnsureCanWriteAsync(CancellationToken ct = default)
        {
            var r = await ValidateAsync(ct);

            if (!r.IsUsable)
                throw new UnauthorizedAccessException(r.Message ?? "License is not valid.");

            if (!r.CanWrite)
                throw new UnauthorizedAccessException("Read-only license (Viewer). Writing is not allowed.");
        }

        public async Task EnsureModuleAsync(string moduleKey, CancellationToken ct = default)
        {
            var r = await ValidateAsync(ct);

            if (!r.IsUsable)
                throw new UnauthorizedAccessException(r.Message ?? "License is not valid.");

            if (!IsModuleEnabled(moduleKey))
                throw new UnauthorizedAccessException($"Module '{moduleKey}' is not licensed.");
        }
    }
}