using System;
using System.Globalization;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using Microsoft.Data.Sqlite;
using ShouTech.App.Converters;
using ShouTech.App.Configuration;
using ShouTech.App.Services;
using ShouTech.Domain.Entities;
using ShouTech.Domain.Interfaces;
using ShouTech.Application.Services;
using ShouTech.Infrastructure;
using Xunit;

namespace Kern.Tests
{
    public class UnitTest1
    {
        [Fact]
        public void NullToVisibilityConverter_WhenConvertBackIsCalled_ShouldReturnFalseWithoutThrowing()
        {
            var converter = new NullToVisibilityConverter();

            var result = converter.ConvertBack(null!, typeof(bool), null!, CultureInfo.InvariantCulture);

            Assert.False((bool)result);
        }

        [Fact]
        public void PwdHash_ShouldVerifyOnlyTheOriginalPassword()
        {
            var password = "Test-only developer password 2026!";
            var stored = PwdHash.Create(password, iterations: 100_000);

            Assert.StartsWith("v1$PBKDF2-SHA512$100000$", stored.Hash);
            Assert.True(PwdHash.Verify(password, stored.Hash, stored.Salt));
            Assert.False(PwdHash.Verify("wrong password", stored.Hash, stored.Salt));
            Assert.False(PwdHash.NeedsRehash(stored.Hash, desiredIterations: 100_000));
        }

        [Fact]
        public void JournalEntry_ShouldAcceptBalancedLines()
        {
            var entry = new JournalEntry(new DateOnly(2026, 8, 21), "Opening balance");
            entry.AddLine(Guid.NewGuid(), debit: 1_000m, credit: 0m);
            entry.AddLine(Guid.NewGuid(), debit: 0m, credit: 1_000m);

            entry.EnsureBalanced();
        }

        [Fact]
        public void JournalEntry_ShouldRejectUnbalancedLines()
        {
            var entry = new JournalEntry(new DateOnly(2026, 8, 21), "Unbalanced entry");
            entry.AddLine(Guid.NewGuid(), debit: 1_000m, credit: 0m);
            entry.AddLine(Guid.NewGuid(), debit: 0m, credit: 900m);

            Assert.Throws<InvalidOperationException>(() => entry.EnsureBalanced());
        }

        [Fact]
        public void JournalLine_ShouldRejectDebitAndCreditOnTheSameLine()
        {
            Assert.Throws<ArgumentException>(() =>
                new JournalLine(Guid.NewGuid(), debit: 10m, credit: 10m));
        }

        [Fact]
        public void JournalEntry_ShouldSupportPostingAndReversalOnlyOnce()
        {
            var entry = new JournalEntry(new DateOnly(2026, 8, 21), "Reversible entry");
            entry.AddLine(Guid.NewGuid(), debit: 100m, credit: 0m);
            entry.AddLine(Guid.NewGuid(), debit: 0m, credit: 100m);

            entry.Post();
            Assert.Equal(JournalEntryStatus.Posted, entry.Status);

            entry.Reverse();
            Assert.Equal(JournalEntryStatus.Reversed, entry.Status);
            Assert.Throws<InvalidOperationException>(() => entry.Post());
        }

        [Fact]
        public void UserPreferences_ShouldNormalizeRegionalAndWindowSettings()
        {
            var preferences = new UsrPref
            {
                Lang = "fr-FR",
                Theme = "unknown",
                CurrencyCode = "sar-random",
                DateFormat = "invalid",
                DecimalDigits = 9,
                WinW = 100,
                WinH = 500
            };

            preferences.Normalize();

            Assert.Equal(LangDirSv.DefaultLanguageCode, preferences.Lang);
            Assert.Equal("Dark", preferences.Theme);
            Assert.Equal("SAR", preferences.CurrencyCode);
            Assert.Equal("dd/MM/yyyy", preferences.DateFormat);
            Assert.Equal(4, preferences.DecimalDigits);
            Assert.Equal(800, preferences.WinW);
            Assert.Equal(600, preferences.WinH);
        }

        [Fact]
        public async Task JournalService_ShouldPersistOnlyBalancedDrafts()
        {
            var repository = new InMemoryJournalRepository();
            var service = new JournalService(repository);
            var debitAccount = Guid.NewGuid();
            var creditAccount = Guid.NewGuid();

            var id = await service.CreateDraftAsync(
                Guid.NewGuid(),
                new DateOnly(2026, 8, 21),
                "Sale transaction",
                "user-001",
                new[]
                {
                    new JournalLineRequest(debitAccount, 250m, 0m),
                    new JournalLineRequest(creditAccount, 0m, 250m)
                });

            Assert.Equal(id, repository.SavedEntry?.Id);
            await Assert.ThrowsAsync<InvalidOperationException>(() => service.CreateDraftAsync(
                Guid.NewGuid(),
                new DateOnly(2026, 8, 21),
                "Invalid transaction",
                "user-001",
                new[] { new JournalLineRequest(debitAccount, 250m, 0m) }));
        }

        [Fact]
        public async Task DatabaseProviders_ShouldSupportOnlySqliteAndPostgreSql()
        {
            Assert.Equal(DatabaseProviderNames.Sqlite, DatabaseProviderNames.Normalize("sqlite3"));
            Assert.Equal(DatabaseProviderNames.PostgreSql, DatabaseProviderNames.Normalize("postgres"));
            Assert.False(DatabaseProviderNames.IsSupported(DatabaseProviderNames.MySql));
            Assert.True(DatabaseProviderNames.IsLegacy(DatabaseProviderNames.MySql));

            var provider = DatabaseProviderFactory.Create(DatabaseProviderNames.Sqlite, "Data Source=:memory:");
            Assert.True(provider.TestConnection("001"));

            var health = DatabaseHealthFactory.Create(DatabaseProviderNames.Sqlite, "Data Source=:memory:");
            var result = await health.CheckAsync();
            Assert.True(result.IsAvailable);
            Assert.Equal(DatabaseProviderNames.Sqlite, result.Provider);
        }

        [Fact]
        public async Task SqliteJournalRepository_ShouldPersistAndTransitionEntries()
        {
            var connectionString = CreateSharedSqliteConnectionString();
            await using var root = new SqliteConnection(connectionString);
            await root.OpenAsync();
            await using (var command = root.CreateCommand())
            {
                command.CommandText = """
                    CREATE TABLE journal_entries (
                        journal_entry_id TEXT PRIMARY KEY,
                        company_id TEXT NOT NULL,
                        entry_date TEXT NOT NULL,
                        description TEXT NOT NULL,
                        status INTEGER NOT NULL DEFAULT 0,
                        created_by TEXT NOT NULL,
                        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        posted_by TEXT,
                        posted_at TEXT,
                        reversed_by TEXT,
                        reversed_at TEXT
                    );
                    CREATE TABLE journal_entry_lines (
                        journal_entry_line_id INTEGER PRIMARY KEY AUTOINCREMENT,
                        journal_entry_id TEXT NOT NULL,
                        line_number INTEGER NOT NULL,
                        account_id TEXT NOT NULL,
                        debit NUMERIC NOT NULL DEFAULT 0,
                        credit NUMERIC NOT NULL DEFAULT 0,
                        cost_center TEXT,
                        note TEXT,
                        UNIQUE (journal_entry_id, line_number)
                    );
                    CREATE TABLE journal_audit_events (
                        journal_audit_event_id INTEGER PRIMARY KEY AUTOINCREMENT,
                        journal_entry_id TEXT NOT NULL,
                        event_type INTEGER NOT NULL,
                        actor TEXT NOT NULL,
                        details TEXT
                    );
                    """;
                await command.ExecuteNonQueryAsync();
            }

            var repository = new SqliteJournalRepository(connectionString);
            var service = new JournalService(repository);
            var companyId = Guid.NewGuid();
            var entryId = await service.CreateDraftAsync(
                companyId,
                new DateOnly(2026, 9, 4),
                "SQLite draft",
                "tester",
                new[]
                {
                    new JournalLineRequest(Guid.NewGuid(), 150m, 0m),
                    new JournalLineRequest(Guid.NewGuid(), 0m, 150m)
                });

            await repository.PostAsync(companyId, entryId, "tester");
            await repository.ReverseAsync(companyId, entryId, "tester", "Reversal");

            await using var verify = new SqliteConnection(connectionString);
            await verify.OpenAsync();
            await using var statusCommand = verify.CreateCommand();
            statusCommand.CommandText = "SELECT status FROM journal_entries WHERE journal_entry_id=@id";
            statusCommand.Parameters.AddWithValue("@id", entryId.ToString());
            Assert.Equal(2L, await statusCommand.ExecuteScalarAsync());

            await using var auditCommand = verify.CreateCommand();
            auditCommand.CommandText = "SELECT COUNT(*) FROM journal_audit_events WHERE journal_entry_id=@id";
            auditCommand.Parameters.AddWithValue("@id", entryId.ToString());
            Assert.Equal(2L, await auditCommand.ExecuteScalarAsync());
        }

        [Fact]
        public async Task SqliteInventoryRepository_ShouldCreateItemsAndTrackStock()
        {
            var connectionString = CreateSharedSqliteConnectionString();
            await using var root = new SqliteConnection(connectionString);
            await root.OpenAsync();
            await using (var command = root.CreateCommand())
            {
                command.CommandText = """
                    CREATE TABLE units_of_measure (
                        uom_id INTEGER PRIMARY KEY AUTOINCREMENT,
                        company_id TEXT NOT NULL,
                        uom_code TEXT NOT NULL,
                        is_active INTEGER NOT NULL DEFAULT 1,
                        is_deleted INTEGER NOT NULL DEFAULT 0,
                        UNIQUE(company_id, uom_code)
                    );
                    CREATE TABLE products (
                        product_id INTEGER PRIMARY KEY AUTOINCREMENT,
                        company_id TEXT NOT NULL,
                        product_code TEXT NOT NULL,
                        product_name_ar TEXT NOT NULL,
                        product_name_en TEXT,
                        category_id INTEGER NOT NULL,
                        primary_uom_id INTEGER NOT NULL,
                        default_sale_price NUMERIC NOT NULL DEFAULT 0,
                        default_purchase_price NUMERIC NOT NULL DEFAULT 0,
                        cost_price NUMERIC NOT NULL DEFAULT 0,
                        is_active INTEGER NOT NULL DEFAULT 1,
                        is_deleted INTEGER NOT NULL DEFAULT 0,
                        created_by TEXT NOT NULL,
                        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        updated_by TEXT,
                        updated_at TEXT,
                        deleted_by TEXT,
                        deleted_at TEXT,
                        UNIQUE(company_id, product_code)
                    );
                    CREATE TABLE stock_balances (
                        stock_balance_id INTEGER PRIMARY KEY AUTOINCREMENT,
                        company_id TEXT NOT NULL,
                        warehouse_id INTEGER NOT NULL,
                        product_id INTEGER NOT NULL,
                        available_qty NUMERIC NOT NULL DEFAULT 0,
                        last_cost NUMERIC,
                        last_updated TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        is_deleted INTEGER NOT NULL DEFAULT 0,
                        UNIQUE(company_id, warehouse_id, product_id)
                    );
                    CREATE TABLE stock_movements (
                        movement_id INTEGER PRIMARY KEY AUTOINCREMENT,
                        company_id TEXT NOT NULL,
                        movement_type TEXT NOT NULL,
                        warehouse_id_to INTEGER,
                        product_id INTEGER NOT NULL,
                        quantity NUMERIC NOT NULL,
                        unit_cost NUMERIC,
                        reference_table TEXT,
                        notes TEXT,
                        created_by TEXT NOT NULL,
                        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                    );
                    """;
                await command.ExecuteNonQueryAsync();
            }

            var companyId = Guid.NewGuid();
            var userId = Guid.NewGuid();
            await using (var seed = root.CreateCommand())
            {
                seed.CommandText = "INSERT INTO units_of_measure (company_id, uom_code) VALUES (@company, 'EA')";
                seed.Parameters.AddWithValue("@company", companyId.ToString());
                await seed.ExecuteNonQueryAsync();
            }

            var repository = new SqliteInvRepo(connectionString);
            var itemId = await repository.CreateItemAsync("ITEM-001", "منتج", null, 1, "EA", 10m, 15m, companyId, userId, CancellationToken.None);
            Assert.True(await repository.ItemCodeExistsAsync("ITEM-001", null, companyId, CancellationToken.None));

            await repository.PostStockInAsync(1, itemId, 5m, 10m, "PO-1", companyId, userId, CancellationToken.None);
            await repository.PostStockOutAsync(1, itemId, 2m, "SO-1", companyId, userId, CancellationToken.None);

            var available = await repository.GetAvailableQtyAsync(1, itemId, companyId, CancellationToken.None);
            Assert.Equal(3m, available);
        }

        private static string CreateSharedSqliteConnectionString()
            => new SqliteConnectionStringBuilder
            {
                DataSource = $"tests-{Guid.NewGuid():N}",
                Mode = SqliteOpenMode.Memory,
                Cache = SqliteCacheMode.Shared
            }.ToString();

        private sealed class InMemoryJournalRepository : IJournalRepository
        {
            public JournalEntry? SavedEntry { get; private set; }

            public Task SaveDraftAsync(Guid companyId, JournalEntry entry, string userId, CancellationToken cancellationToken = default)
            {
                SavedEntry = entry;
                return Task.CompletedTask;
            }

            public Task PostAsync(Guid companyId, Guid journalEntryId, string userId, CancellationToken cancellationToken = default) =>
                Task.CompletedTask;

            public Task ReverseAsync(Guid companyId, Guid journalEntryId, string userId, string? details = null, CancellationToken cancellationToken = default) =>
                Task.CompletedTask;
        }
    }
}
