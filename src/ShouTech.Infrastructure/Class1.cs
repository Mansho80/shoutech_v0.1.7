using Npgsql;
using ShouTech.Domain.Entities;
using ShouTech.Domain.Interfaces;

namespace ShouTech.Infrastructure;

/// <summary>PostgreSQL implementation of the journal repository.</summary>
public sealed class SqlJournalRepository : IJournalRepository
{
    private readonly string _connectionString;

    public SqlJournalRepository(string connectionString)
        => _connectionString = string.IsNullOrWhiteSpace(connectionString)
            ? throw new ArgumentException("A database connection string is required.", nameof(connectionString))
            : connectionString;

    public async Task SaveDraftAsync(Guid companyId, JournalEntry entry, string userId, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(entry);
        ValidateScope(companyId, entry.Id, userId);
        if (entry.Status != JournalEntryStatus.Draft)
            throw new InvalidOperationException("Only draft journal entries can be saved.");

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken).ConfigureAwait(false);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await using (var command = new NpgsqlCommand("""
                INSERT INTO journal_entries
                    (journal_entry_id, company_id, entry_date, description, status, created_by)
                VALUES (@id, @company_id, @entry_date, @description, 0, @created_by)
                """, connection, transaction))
            {
                command.Parameters.AddWithValue("id", entry.Id);
                command.Parameters.AddWithValue("company_id", companyId);
                command.Parameters.AddWithValue("entry_date", entry.EntryDate);
                command.Parameters.AddWithValue("description", entry.Description);
                command.Parameters.AddWithValue("created_by", userId.Trim());
                await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            }

            var lineNumber = 1;
            foreach (var line in entry.Lines)
            {
                await using var command = new NpgsqlCommand("""
                    INSERT INTO journal_entry_lines
                        (journal_entry_id, line_number, account_id, debit, credit, cost_center, note)
                    VALUES (@entry_id, @line_number, @account_id, @debit, @credit, @cost_center, @note)
                    """, connection, transaction);
                command.Parameters.AddWithValue("entry_id", entry.Id);
                command.Parameters.AddWithValue("line_number", lineNumber++);
                command.Parameters.AddWithValue("account_id", line.AccountId);
                command.Parameters.AddWithValue("debit", line.Debit);
                command.Parameters.AddWithValue("credit", line.Credit);
                command.Parameters.AddWithValue("cost_center", (object?)line.CostCenter ?? DBNull.Value);
                command.Parameters.AddWithValue("note", (object?)line.Note ?? DBNull.Value);
                await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            }
            await transaction.CommitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None).ConfigureAwait(false);
            throw;
        }
    }

    public Task PostAsync(Guid companyId, Guid journalEntryId, string userId, CancellationToken cancellationToken = default)
        => ChangeStatusAsync(companyId, journalEntryId, userId, false, null, cancellationToken);

    public Task ReverseAsync(Guid companyId, Guid journalEntryId, string userId, string? details = null, CancellationToken cancellationToken = default)
        => ChangeStatusAsync(companyId, journalEntryId, userId, true, details, cancellationToken);

    private async Task ChangeStatusAsync(Guid companyId, Guid id, string userId, bool reverse, string? details, CancellationToken ct)
    {
        ValidateScope(companyId, id, userId);
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(ct).ConfigureAwait(false);
        await using var transaction = await connection.BeginTransactionAsync(ct).ConfigureAwait(false);
        try
        {
            const string select = "SELECT status FROM journal_entries WHERE journal_entry_id=@id AND company_id=@company_id FOR UPDATE";
            await using var check = new NpgsqlCommand(select, connection, transaction);
            check.Parameters.AddWithValue("id", id);
            check.Parameters.AddWithValue("company_id", companyId);
            var status = await check.ExecuteScalarAsync(ct).ConfigureAwait(false);
            if (status is null)
                throw new KeyNotFoundException("Journal entry was not found for the company.");
            var current = Convert.ToInt32(status, System.Globalization.CultureInfo.InvariantCulture);
            var expected = reverse ? 1 : 0;
            if (current != expected)
                throw new InvalidOperationException(reverse ? "Only a posted journal entry can be reversed." : "Only an existing draft journal entry can be posted.");
            if (!reverse)
            {
                await using var balance = new NpgsqlCommand("""
                    SELECT COUNT(*) >= 2 AND COALESCE(SUM(debit),0)=COALESCE(SUM(credit),0)
                        AND COALESCE(SUM(debit),0)>0
                    FROM journal_entry_lines WHERE journal_entry_id=@id
                    """, connection, transaction);
                balance.Parameters.AddWithValue("id", id);
                if (!Convert.ToBoolean(await balance.ExecuteScalarAsync(ct).ConfigureAwait(false)))
                    throw new InvalidOperationException("Journal entry is not balanced or has no lines.");
            }
            await using var update = new NpgsqlCommand(reverse
                ? "UPDATE journal_entries SET status=2, reversed_by=@user_id, reversed_at=now() WHERE journal_entry_id=@id AND company_id=@company_id"
                : "UPDATE journal_entries SET status=1, posted_by=@user_id, posted_at=now() WHERE journal_entry_id=@id AND company_id=@company_id", connection, transaction);
            update.Parameters.AddWithValue("id", id);
            update.Parameters.AddWithValue("company_id", companyId);
            update.Parameters.AddWithValue("user_id", userId.Trim());
            await update.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
            await using var audit = new NpgsqlCommand("""
                INSERT INTO journal_audit_events (journal_entry_id, event_type, actor, details)
                VALUES (@id, @event_type, @actor, @details)
                """, connection, transaction);
            audit.Parameters.AddWithValue("id", id);
            audit.Parameters.AddWithValue("event_type", reverse ? 2 : 1);
            audit.Parameters.AddWithValue("actor", userId.Trim());
            audit.Parameters.AddWithValue("details", (object?)(details ?? (reverse ? null : "Journal entry posted.")) ?? DBNull.Value);
            await audit.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
            await transaction.CommitAsync(ct).ConfigureAwait(false);
        }
        catch { await transaction.RollbackAsync(CancellationToken.None).ConfigureAwait(false); throw; }
    }

    private static void ValidateScope(Guid companyId, Guid entryId, string userId)
    {
        if (companyId == Guid.Empty) throw new ArgumentException("Company is required.", nameof(companyId));
        if (entryId == Guid.Empty) throw new ArgumentException("Journal entry is required.", nameof(entryId));
        if (string.IsNullOrWhiteSpace(userId)) throw new ArgumentException("User is required.", nameof(userId));
    }
}
