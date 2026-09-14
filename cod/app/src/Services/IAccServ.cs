// shoutech_erp_v0.1.6/cod/app/src/Services/IAccServ.cs
using System;
using System.Threading;
using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    /// <summary>
    /// Enterprise Accounting service interface (Journal entries).
    /// </summary>
    public interface IAccServ
    {
        Task<Guid> CreateJournalAsync(DateOnly entryDate, string description, string userId, CancellationToken ct = default);
        Task AddJournalLineAsync(
            Guid journalId, Guid accountId, decimal debit, decimal credit,
            string? costCenter, string? note, string userId, CancellationToken ct = default);
        Task PostJournalAsync(Guid journalId, string userId, CancellationToken ct = default);
        Task SoftDeleteDraftJournalAsync(Guid journalId, string userId, CancellationToken ct = default);
    }
}