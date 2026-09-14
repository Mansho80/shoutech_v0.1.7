using ShouTech.Domain.Entities;

namespace ShouTech.Domain.Interfaces;

public interface IJournalRepository
{
    Task SaveDraftAsync(Guid companyId, JournalEntry entry, string userId, CancellationToken cancellationToken = default);
    Task PostAsync(Guid companyId, Guid journalEntryId, string userId, CancellationToken cancellationToken = default);
    Task ReverseAsync(Guid companyId, Guid journalEntryId, string userId, string? details = null, CancellationToken cancellationToken = default);
}
