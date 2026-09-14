// shoutech_erp_v0.1.6/cod/app/src/Services/ModMenuServ.cs
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    /// <summary>
    /// Builds the list of modules that should appear in the main ribbon/menu
    /// according to the current license (same behavior as local market leaders).
    /// </summary>
    public sealed class ModMenuServ
    {
        private readonly ILicServ _lic;

        public ModMenuServ(ILicServ lic)
        {
            _lic = lic ?? throw new ArgumentNullException(nameof(lic));
        }

        public async Task<IReadOnlyList<string>> GetVisibleModulesAsync(CancellationToken ct = default)
        {
            var result = await _lic.ValidateAsync(ct);
            var list = new List<string>();

            if (!result.IsUsable)
                return list;

            // Core modules – always shown for Core / Demo
            if (result.Edition is LicEd.Core or LicEd.Demo)
            {
                list.Add(ModKey.Acc);
                list.Add(ModKey.Inv);
                list.Add(ModKey.Sales);
                list.Add(ModKey.Purch);
            }

            // Optional modules – only if licensed
            void AddIf(string key)
            {
                if (_lic.IsModuleEnabled(key))
                    list.Add(key);
            }

            AddIf(ModKey.Hr);
            AddIf(ModKey.Mfg);
            AddIf(ModKey.Pos);
            AddIf(ModKey.Ai);
            AddIf(ModKey.AdvRpt);
            AddIf(ModKey.MultiCur);
            AddIf(ModKey.WhiteLabel);

            return list;
        }
    }
}