using Dapper;
using Microsoft.Data.Sqlite;
using Npgsql;

namespace ShouTech.App.Services;

public interface IInvRepo
{
    Task<IReadOnlyList<InventoryItem>> GetItemsAsync(string? search, Guid companyId, CancellationToken ct);
    Task<InventoryItem?> GetItemAsync(int id, Guid companyId, CancellationToken ct);
    Task<int> CreateItemAsync(string code, string name, string? name2, int categoryId,
        string unit, decimal cost, decimal price, Guid companyId, Guid userId, CancellationToken ct);
    Task UpdateItemAsync(int id, string name, string? name2, int categoryId, string unit,
        decimal cost, decimal price, Guid companyId, Guid userId, CancellationToken ct);
    Task SoftDeleteItemAsync(int id, Guid companyId, Guid userId, CancellationToken ct);
    Task<bool> ItemCodeExistsAsync(string code, int? excludeId, Guid companyId, CancellationToken ct);
    Task<long> PostStockInAsync(long warehouseId, int itemId, decimal qty, decimal cost,
        string? reference, Guid companyId, Guid userId, CancellationToken ct);
    Task<long> PostStockOutAsync(long warehouseId, int itemId, decimal qty,
        string? reference, Guid companyId, Guid userId, CancellationToken ct);
    Task<decimal> GetAvailableQtyAsync(long warehouseId, int itemId, Guid companyId, CancellationToken ct);
}

/// <summary>PostgreSQL implementation backed by the inventory tables.</summary>
public sealed class SqlInvRepo : IInvRepo
{
    private readonly string _connectionString;
    public SqlInvRepo(string connectionString)
        => _connectionString = string.IsNullOrWhiteSpace(connectionString)
            ? throw new ArgumentException("A database connection string is required.", nameof(connectionString))
            : connectionString;

    private NpgsqlConnection OpenConnection() => new(_connectionString);

    public async Task<IReadOnlyList<InventoryItem>> GetItemsAsync(string? search, Guid companyId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = """
            SELECT p.product_id Id, p.product_code Code, p.product_name_ar Name, p.product_name_en Name2,
                   p.category_id CategoryId, u.uom_code Unit, p.cost_price Cost, p.default_sale_price Price, p.is_active IsActive
            FROM products p INNER JOIN units_of_measure u ON u.uom_id=p.primary_uom_id
            WHERE p.company_id=@companyId AND p.is_deleted=false
              AND (@search IS NULL OR p.product_code ILIKE '%' || @search || '%' OR p.product_name_ar ILIKE '%' || @search || '%')
            ORDER BY p.product_code LIMIT 1000
            """;
        var rows = await db.QueryAsync<InventoryItem>(new CommandDefinition(sql, new { companyId, search = string.IsNullOrWhiteSpace(search) ? null : search.Trim() }, cancellationToken: ct));
        return rows.AsList();
    }

    public async Task<InventoryItem?> GetItemAsync(int id, Guid companyId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = """
            SELECT p.product_id Id, p.product_code Code, p.product_name_ar Name, p.product_name_en Name2,
                   p.category_id CategoryId, u.uom_code Unit, p.cost_price Cost, p.default_sale_price Price, p.is_active IsActive
            FROM products p INNER JOIN units_of_measure u ON u.uom_id=p.primary_uom_id
            WHERE p.product_id=@id AND p.company_id=@companyId AND p.is_deleted=false LIMIT 1
            """;
        return await db.QuerySingleOrDefaultAsync<InventoryItem>(new CommandDefinition(sql, new { id, companyId }, cancellationToken: ct));
    }

    public async Task<int> CreateItemAsync(string code, string name, string? name2, int categoryId,
        string unit, decimal cost, decimal price, Guid companyId, Guid userId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = """
            INSERT INTO products
                (company_id, product_code, product_name_ar, product_name_en, category_id, primary_uom_id,
                 default_sale_price, default_purchase_price, cost_price, created_by)
            SELECT @companyId, @code, @name, @name2, @categoryId, u.uom_id,
                   @price, @cost, @cost, @userId
            FROM units_of_measure u
            WHERE u.company_id = @companyId AND u.uom_code = @unit AND u.is_deleted = false AND u.is_active = true
            RETURNING product_id;
            """;
        var id = await db.ExecuteScalarAsync<int?>(new CommandDefinition(sql, new
        { companyId, code, name, name2, categoryId, unit, cost, price, userId }, cancellationToken: ct));
        return id ?? throw new InvalidOperationException("The specified unit was not found for the company.");
    }

    public async Task UpdateItemAsync(int id, string name, string? name2, int categoryId, string unit,
        decimal cost, decimal price, Guid companyId, Guid userId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = """
            UPDATE products p SET product_name_ar=@name, product_name_en=@name2, category_id=@categoryId,
                primary_uom_id=u.uom_id, cost_price=@cost, default_sale_price=@price,
                default_purchase_price=@cost, updated_by=@userId, updated_at=now()
            FROM units_of_measure u
            WHERE p.product_id=@id AND p.company_id=@companyId AND p.is_deleted=false
              AND u.company_id=p.company_id AND u.uom_code=@unit AND u.is_deleted=false AND u.is_active=true;
            """;
        var affected = await db.ExecuteAsync(new CommandDefinition(sql,
            new { id, name, name2, categoryId, unit, cost, price, companyId, userId }, cancellationToken: ct));
        if (affected != 1) throw new KeyNotFoundException("Inventory item was not found.");
    }

    public async Task SoftDeleteItemAsync(int id, Guid companyId, Guid userId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = """
            UPDATE products SET is_deleted=true, is_active=false, deleted_at=now(),
                deleted_by=@userId WHERE product_id=@id AND company_id=@companyId AND is_deleted=false;
            """;
        var affected = await db.ExecuteAsync(new CommandDefinition(sql, new { id, companyId, userId }, cancellationToken: ct));
        if (affected != 1) throw new KeyNotFoundException("Inventory item was not found.");
    }

    public async Task<bool> ItemCodeExistsAsync(string code, int? excludeId, Guid companyId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = """
            SELECT CAST(CASE WHEN EXISTS (
                SELECT 1 FROM products WHERE company_id=@companyId AND product_code=@code
                    AND is_deleted=false AND (@excludeId IS NULL OR product_id<>@excludeId)
            ) THEN 1 ELSE 0 END)
            """;
        return await db.ExecuteScalarAsync<bool>(new CommandDefinition(sql,
            new { code, excludeId, companyId }, cancellationToken: ct));
    }

    public Task<long> PostStockInAsync(long warehouseId, int itemId, decimal qty, decimal cost,
        string? reference, Guid companyId, Guid userId, CancellationToken ct)
        => ExecuteMovementAsync(true, warehouseId, itemId, qty, cost, reference, companyId, userId, ct);

    public Task<long> PostStockOutAsync(long warehouseId, int itemId, decimal qty,
        string? reference, Guid companyId, Guid userId, CancellationToken ct)
        => ExecuteMovementAsync(false, warehouseId, itemId, qty, null, reference, companyId, userId, ct);

    private async Task<long> ExecuteMovementAsync(bool increase, long warehouseId, int itemId, decimal qty,
        decimal? cost, string? reference, Guid companyId, Guid userId, CancellationToken ct)
    {
        if (qty <= 0) throw new ArgumentOutOfRangeException(nameof(qty), "Quantity must be positive.");
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        await using var tx = await db.BeginTransactionAsync(ct);
        var delta = increase ? qty : -qty;
        var movementType = increase ? "PURCHASE" : "SALE";
        await db.ExecuteAsync(new CommandDefinition("""
            INSERT INTO stock_balances (company_id, warehouse_id, product_id, available_qty, last_cost, last_updated, is_deleted)
            VALUES (@companyId, @warehouseId, @itemId, @delta, @cost, now(), false)
            ON CONFLICT (company_id, warehouse_id, product_id) DO UPDATE SET available_qty=stock_balances.available_qty + EXCLUDED.available_qty, last_cost=COALESCE(EXCLUDED.last_cost, stock_balances.last_cost), last_updated=now()
            """, new { companyId, warehouseId, itemId, delta, cost }, tx, cancellationToken: ct));
        if (!increase && await db.ExecuteScalarAsync<decimal>(new CommandDefinition(
            "SELECT available_qty FROM stock_balances WHERE company_id=@companyId AND warehouse_id=@warehouseId AND product_id=@itemId FOR UPDATE",
            new { companyId, warehouseId, itemId }, tx, cancellationToken: ct)) < 0)
            throw new InvalidOperationException("Insufficient available stock.");
        var id = await db.ExecuteScalarAsync<long>(new CommandDefinition("""
            INSERT INTO stock_movements
                (company_id, movement_type, warehouse_id_to, product_id, quantity, unit_cost,
                 reference_table, notes, created_by)
            VALUES (@companyId, @movementType, @warehouseId, @itemId, @qty, @cost,
                    'Inventory', @reference, @userId)
            
            RETURNING movement_id
            """, new { companyId, movementType, warehouseId, itemId, qty, cost, reference, userId }, tx, cancellationToken: ct));
        await tx.CommitAsync(ct);
        return id;
    }

    public async Task<decimal> GetAvailableQtyAsync(long warehouseId, int itemId, Guid companyId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = "SELECT COALESCE(available_qty, 0) FROM stock_balances WHERE company_id=@companyId AND warehouse_id=@warehouseId AND product_id=@itemId AND is_deleted=false";
        return await db.ExecuteScalarAsync<decimal?>(new CommandDefinition(sql,
            new { companyId, warehouseId, itemId }, cancellationToken: ct)) ?? 0m;
    }
}

public sealed class SqliteInvRepo : IInvRepo
{
    private readonly string _connectionString;
    public SqliteInvRepo(string connectionString)
        => _connectionString = string.IsNullOrWhiteSpace(connectionString)
            ? throw new ArgumentException("A database connection string is required.", nameof(connectionString))
            : connectionString;

    private SqliteConnection OpenConnection() => new(_connectionString);

    public async Task<IReadOnlyList<InventoryItem>> GetItemsAsync(string? search, Guid companyId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = """
            SELECT p.product_id Id, p.product_code Code, p.product_name_ar Name, p.product_name_en Name2,
                   p.category_id CategoryId, u.uom_code Unit, p.cost_price Cost, p.default_sale_price Price, p.is_active IsActive
            FROM products p INNER JOIN units_of_measure u ON u.uom_id=p.primary_uom_id
            WHERE p.company_id=@companyId AND p.is_deleted=0
              AND (@search IS NULL OR p.product_code LIKE '%' || @search || '%' OR p.product_name_ar LIKE '%' || @search || '%')
            ORDER BY p.product_code LIMIT 1000
            """;
        var rows = await db.QueryAsync<InventoryItem>(new CommandDefinition(sql, new { companyId = companyId.ToString(), search = string.IsNullOrWhiteSpace(search) ? null : search.Trim() }, cancellationToken: ct));
        return rows.AsList();
    }

    public async Task<InventoryItem?> GetItemAsync(int id, Guid companyId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = """
            SELECT p.product_id Id, p.product_code Code, p.product_name_ar Name, p.product_name_en Name2,
                   p.category_id CategoryId, u.uom_code Unit, p.cost_price Cost, p.default_sale_price Price, p.is_active IsActive
            FROM products p INNER JOIN units_of_measure u ON u.uom_id=p.primary_uom_id
            WHERE p.product_id=@id AND p.company_id=@companyId AND p.is_deleted=0 LIMIT 1
            """;
        return await db.QuerySingleOrDefaultAsync<InventoryItem>(new CommandDefinition(sql, new { id, companyId = companyId.ToString() }, cancellationToken: ct));
    }

    public async Task<int> CreateItemAsync(string code, string name, string? name2, int categoryId,
        string unit, decimal cost, decimal price, Guid companyId, Guid userId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        await using var tx = await db.BeginTransactionAsync(ct);
        var uomId = await db.ExecuteScalarAsync<long?>(new CommandDefinition("""
            SELECT uom_id FROM units_of_measure
            WHERE company_id=@companyId AND uom_code=@unit AND is_deleted=0 AND is_active=1
            LIMIT 1
            """, new { companyId = companyId.ToString(), unit }, tx, cancellationToken: ct));
        if (!uomId.HasValue)
            throw new InvalidOperationException("The specified unit was not found for the company.");

        await db.ExecuteAsync(new CommandDefinition("""
            INSERT INTO products
                (company_id, product_code, product_name_ar, product_name_en, category_id, primary_uom_id,
                 default_sale_price, default_purchase_price, cost_price, created_by)
            VALUES (@companyId, @code, @name, @name2, @categoryId, @primaryUomId,
                    @price, @cost, @cost, @userId)
            """, new
        {
            companyId = companyId.ToString(),
            code,
            name,
            name2,
            categoryId,
            primaryUomId = uomId.Value,
            price,
            cost,
            userId = userId.ToString()
        }, tx, cancellationToken: ct));
        var id = await db.ExecuteScalarAsync<long>(new CommandDefinition("SELECT last_insert_rowid()", transaction: tx, cancellationToken: ct));
        await tx.CommitAsync(ct);
        return checked((int)id);
    }

    public async Task UpdateItemAsync(int id, string name, string? name2, int categoryId, string unit,
        decimal cost, decimal price, Guid companyId, Guid userId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        await using var tx = await db.BeginTransactionAsync(ct);
        var uomId = await db.ExecuteScalarAsync<long?>(new CommandDefinition("""
            SELECT uom_id FROM units_of_measure
            WHERE company_id=@companyId AND uom_code=@unit AND is_deleted=0 AND is_active=1
            LIMIT 1
            """, new { companyId = companyId.ToString(), unit }, tx, cancellationToken: ct));
        if (!uomId.HasValue)
            throw new InvalidOperationException("The specified unit was not found for the company.");

        var affected = await db.ExecuteAsync(new CommandDefinition("""
            UPDATE products
            SET product_name_ar=@name,
                product_name_en=@name2,
                category_id=@categoryId,
                primary_uom_id=@primaryUomId,
                cost_price=@cost,
                default_sale_price=@price,
                default_purchase_price=@cost,
                updated_by=@userId,
                updated_at=CURRENT_TIMESTAMP
            WHERE product_id=@id AND company_id=@companyId AND is_deleted=0
            """, new
        {
            id,
            name,
            name2,
            categoryId,
            primaryUomId = uomId.Value,
            cost,
            price,
            companyId = companyId.ToString(),
            userId = userId.ToString()
        }, tx, cancellationToken: ct));
        if (affected != 1) throw new KeyNotFoundException("Inventory item was not found.");
        await tx.CommitAsync(ct);
    }

    public async Task SoftDeleteItemAsync(int id, Guid companyId, Guid userId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = """
            UPDATE products SET is_deleted=1, is_active=0, deleted_at=CURRENT_TIMESTAMP,
                deleted_by=@userId WHERE product_id=@id AND company_id=@companyId AND is_deleted=0;
            """;
        var affected = await db.ExecuteAsync(new CommandDefinition(sql, new { id, companyId = companyId.ToString(), userId = userId.ToString() }, cancellationToken: ct));
        if (affected != 1) throw new KeyNotFoundException("Inventory item was not found.");
    }

    public async Task<bool> ItemCodeExistsAsync(string code, int? excludeId, Guid companyId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = """
            SELECT CASE WHEN EXISTS (
                SELECT 1 FROM products WHERE company_id=@companyId AND product_code=@code
                    AND is_deleted=0 AND (@excludeId IS NULL OR product_id<>@excludeId)
            ) THEN 1 ELSE 0 END
            """;
        return await db.ExecuteScalarAsync<bool>(new CommandDefinition(sql,
            new { code, excludeId, companyId = companyId.ToString() }, cancellationToken: ct));
    }

    public Task<long> PostStockInAsync(long warehouseId, int itemId, decimal qty, decimal cost,
        string? reference, Guid companyId, Guid userId, CancellationToken ct)
        => ExecuteMovementAsync(true, warehouseId, itemId, qty, cost, reference, companyId, userId, ct);

    public Task<long> PostStockOutAsync(long warehouseId, int itemId, decimal qty,
        string? reference, Guid companyId, Guid userId, CancellationToken ct)
        => ExecuteMovementAsync(false, warehouseId, itemId, qty, null, reference, companyId, userId, ct);

    private async Task<long> ExecuteMovementAsync(bool increase, long warehouseId, int itemId, decimal qty,
        decimal? cost, string? reference, Guid companyId, Guid userId, CancellationToken ct)
    {
        if (qty <= 0) throw new ArgumentOutOfRangeException(nameof(qty), "Quantity must be positive.");
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        await using var tx = await db.BeginTransactionAsync(ct);
        var delta = increase ? qty : -qty;
        var movementType = increase ? "PURCHASE" : "SALE";
        await db.ExecuteAsync(new CommandDefinition("""
            INSERT INTO stock_balances (company_id, warehouse_id, product_id, available_qty, last_cost, last_updated, is_deleted)
            VALUES (@companyId, @warehouseId, @itemId, @delta, @cost, CURRENT_TIMESTAMP, 0)
            ON CONFLICT (company_id, warehouse_id, product_id) DO UPDATE SET
                available_qty = stock_balances.available_qty + excluded.available_qty,
                last_cost = COALESCE(excluded.last_cost, stock_balances.last_cost),
                last_updated = CURRENT_TIMESTAMP
            """, new { companyId = companyId.ToString(), warehouseId, itemId, delta, cost }, tx, cancellationToken: ct));
        if (!increase && await db.ExecuteScalarAsync<decimal>(new CommandDefinition(
            "SELECT available_qty FROM stock_balances WHERE company_id=@companyId AND warehouse_id=@warehouseId AND product_id=@itemId",
            new { companyId = companyId.ToString(), warehouseId, itemId }, tx, cancellationToken: ct)) < 0)
            throw new InvalidOperationException("Insufficient available stock.");
        await db.ExecuteAsync(new CommandDefinition("""
            INSERT INTO stock_movements
                (company_id, movement_type, warehouse_id_to, product_id, quantity, unit_cost,
                 reference_table, notes, created_by)
            VALUES (@companyId, @movementType, @warehouseId, @itemId, @qty, @cost,
                    'Inventory', @reference, @userId)
            """, new { companyId = companyId.ToString(), movementType, warehouseId, itemId, qty, cost, reference, userId = userId.ToString() }, tx, cancellationToken: ct));
        var id = await db.ExecuteScalarAsync<long>(new CommandDefinition("SELECT last_insert_rowid()", transaction: tx, cancellationToken: ct));
        await tx.CommitAsync(ct);
        return id;
    }

    public async Task<decimal> GetAvailableQtyAsync(long warehouseId, int itemId, Guid companyId, CancellationToken ct)
    {
        await using var db = OpenConnection();
        await db.OpenAsync(ct);
        const string sql = "SELECT COALESCE(available_qty, 0) FROM stock_balances WHERE company_id=@companyId AND warehouse_id=@warehouseId AND product_id=@itemId AND is_deleted=0";
        return await db.ExecuteScalarAsync<decimal?>(new CommandDefinition(sql,
            new { companyId = companyId.ToString(), warehouseId, itemId }, cancellationToken: ct)) ?? 0m;
    }
}
