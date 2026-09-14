// shoutech_erp_v0.1.6/cod/app/src/Services/AccServ.cs
using System;
using System.Threading;
using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    /// <summary>
    /// Enterprise Accounting service (Journal entries).
    /// Protected by License + Permissions.
    /// </summary>
    public sealed class AccServ : IAccServ
    {
        private readonly ILicServ _lic;
        private readonly IPermServ _perm;

        public AccServ(ILicServ lic, IPermServ perm)
        {
            _lic = lic ?? throw new ArgumentNullException(nameof(lic));
            _perm = perm ?? throw new ArgumentNullException(nameof(perm));
        }

        public async Task<Guid> CreateJournalAsync(DateOnly entryDate, string description, string userId, CancellationToken ct = default)
        {
            await _lic.EnsureCanWriteAsync(ct);
            await _lic.EnsureModuleAsync(ModKey.Acc, ct);

            if (!_perm.Has(PermKey.AccCreate))
                throw new UnauthorizedAccessException("You do not have permission to create journal entries.");

            if (string.IsNullOrWhiteSpace(description))
                throw new ArgumentException("Description is required.");

            return Guid.NewGuid();
        }

        public async Task AddJournalLineAsync(
            Guid journalId, Guid accountId, decimal debit, decimal credit,
            string? costCenter, string? note, string userId, CancellationToken ct = default)
        {
            await _lic.EnsureCanWriteAsync(ct);
            await _lic.EnsureModuleAsync(ModKey.Acc, ct);

            if (!_perm.Has(PermKey.AccCreate))
                throw new UnauthorizedAccessException("You do not have permission to modify journal entries.");

            if (debit < 0 || credit < 0)
                throw new ArgumentException("Debit and Credit cannot be negative.");
            if (debit > 0 && credit > 0)
                throw new ArgumentException("A line cannot have both debit and credit.");
            if (debit == 0 && credit == 0)
                throw new ArgumentException("Either debit or credit must have a value.");
        }

        public async Task PostJournalAsync(Guid journalId, string userId, CancellationToken ct = default)
        {
            await _lic.EnsureCanWriteAsync(ct);
            await _lic.EnsureModuleAsync(ModKey.Acc, ct);

            if (!_perm.Has(PermKey.AccPost))
                throw new UnauthorizedAccessException("You do not have permission to post journal entries.");

            // TODO: التحقق من توازن القيد قبل الترحيل
            // if (totalDebit != totalCredit) throw ...
        }

        public async Task SoftDeleteDraftJournalAsync(Guid journalId, string userId, CancellationToken ct = default)
        {
            await _lic.EnsureCanWriteAsync(ct);
            await _lic.EnsureModuleAsync(ModKey.Acc, ct);

            if (!_perm.Has(PermKey.AccDelete))
                throw new UnauthorizedAccessException("You do not have permission to delete journal entries.");

            // TODO: التأكد أن القيد غير مرحّل قبل الحذف
        }
    }
}