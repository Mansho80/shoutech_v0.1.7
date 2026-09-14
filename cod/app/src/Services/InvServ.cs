using System;
using System.Threading;
using System.Threading.Tasks;

namespace ShouTech.App.Services;

/// <summary>Inventory application service; policy checks stay outside the SQL repository.</summary>
public sealed class InvServ : IInvServ
{
    private readonly ILicServ _lic;
    private readonly IPermServ _perm;
    private readonly IInvRepo _repo;

    public InvServ(ILicServ lic, IPermServ perm, IInvRepo repo)
    {
        _lic = lic ?? throw new ArgumentNullException(nameof(lic));
        _perm = perm ?? throw new ArgumentNullException(nameof(perm));
        _repo = repo ?? throw new ArgumentNullException(nameof(repo));
    }

    public async Task<IReadOnlyList<InventoryItem>> GetItemsAsync(string? search = null, CancellationToken ct = default)
    {
        await _lic.EnsureModuleAsync(ModKey.Inv, ct);
        return await _repo.GetItemsAsync(search, ResolveCompanyId(), ct);
    }

    public async Task<InventoryItem> GetItemAsync(int id, CancellationToken ct = default)
    {
        await _lic.EnsureModuleAsync(ModKey.Inv, ct);
        if (id <= 0) throw new ArgumentException("Invalid item id.", nameof(id));
        return await _repo.GetItemAsync(id, ResolveCompanyId(), ct)
            ?? throw new KeyNotFoundException("Inventory item was not found.");
    }

    public async Task<int> CreateItemAsync(string code, string name, string? name2, int categoryId,
        string unit, decimal cost, decimal price, string userId, CancellationToken ct = default)
    {
        await EnsureWriteAsync(PermKey.InvCreate, ct);
        ValidateItem(code, name, unit, cost, price);
        var companyId = ResolveCompanyId();
        var actor = ParseUserId(userId);
        if (await _repo.ItemCodeExistsAsync(code.Trim(), null, companyId, ct))
            throw new InvalidOperationException("An item with this code already exists.");
        return await _repo.CreateItemAsync(code.Trim(), name.Trim(), name2?.Trim(), categoryId,
            unit.Trim(), cost, price, companyId, actor, ct);
    }

    public async Task UpdateItemAsync(int id, string name, string? name2, int categoryId,
        string unit, decimal cost, decimal price, string userId, CancellationToken ct = default)
    {
        await EnsureWriteAsync(PermKey.InvCreate, ct);
        if (id <= 0) throw new ArgumentException("Invalid item id.", nameof(id));
        ValidateItem("valid", name, unit, cost, price);
        await _repo.UpdateItemAsync(id, name.Trim(), name2?.Trim(), categoryId, unit.Trim(),
            cost, price, ResolveCompanyId(), ParseUserId(userId), ct);
    }

    public async Task SoftDeleteItemAsync(int id, string userId, CancellationToken ct = default)
    {
        await EnsureWriteAsync(PermKey.InvDelete, ct);
        if (id <= 0) throw new ArgumentException("Invalid item id.", nameof(id));
        await _repo.SoftDeleteItemAsync(id, ResolveCompanyId(), ParseUserId(userId), ct);
    }

    public async Task<bool> ItemCodeExistsAsync(string code, int? excludeId = null, CancellationToken ct = default)
    {
        await _lic.EnsureModuleAsync(ModKey.Inv, ct);
        if (string.IsNullOrWhiteSpace(code)) return false;
        return await _repo.ItemCodeExistsAsync(code.Trim(), excludeId, ResolveCompanyId(), ct);
    }

    public async Task<long> PostStockInAsync(long warehouseId, int itemId, decimal qty, decimal cost,
        string? refDoc, string userId, CancellationToken ct = default)
    {
        await EnsureWriteAsync(PermKey.InvMove, ct);
        ValidateStock(warehouseId, itemId, qty);
        if (cost < 0) throw new ArgumentException("Cost cannot be negative.", nameof(cost));
        return await _repo.PostStockInAsync(warehouseId, itemId, qty, cost, refDoc,
            ResolveCompanyId(), ParseUserId(userId), ct);
    }

    public async Task<long> PostStockOutAsync(long warehouseId, int itemId, decimal qty,
        string? refDoc, string userId, CancellationToken ct = default)
    {
        await EnsureWriteAsync(PermKey.InvMove, ct);
        ValidateStock(warehouseId, itemId, qty);
        var available = await _repo.GetAvailableQtyAsync(warehouseId, itemId, ResolveCompanyId(), ct);
        if (available < qty) throw new InvalidOperationException("Insufficient stock quantity.");
        return await _repo.PostStockOutAsync(warehouseId, itemId, qty, refDoc,
            ResolveCompanyId(), ParseUserId(userId), ct);
    }

    public async Task<decimal> GetAvailableQtyAsync(long warehouseId, int itemId, CancellationToken ct = default)
    {
        await _lic.EnsureModuleAsync(ModKey.Inv, ct);
        ValidateStock(warehouseId, itemId, 1);
        return await _repo.GetAvailableQtyAsync(warehouseId, itemId, ResolveCompanyId(), ct);
    }

    private async Task EnsureWriteAsync(string permission, CancellationToken ct)
    {
        await _lic.EnsureCanWriteAsync(ct);
        await _lic.EnsureModuleAsync(ModKey.Inv, ct);
        if (!_perm.Has(permission)) throw new UnauthorizedAccessException("Insufficient inventory permission.");
    }

    private static void ValidateItem(string code, string name, string unit, decimal cost, decimal price)
    {
        if (string.IsNullOrWhiteSpace(code)) throw new ArgumentException("Item code is required.", nameof(code));
        if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("Item name is required.", nameof(name));
        if (string.IsNullOrWhiteSpace(unit)) throw new ArgumentException("Unit is required.", nameof(unit));
        if (cost < 0 || price < 0) throw new ArgumentException("Cost and price cannot be negative.");
    }

    private static void ValidateStock(long warehouseId, int itemId, decimal qty)
    {
        if (warehouseId <= 0) throw new ArgumentException("Invalid warehouse id.", nameof(warehouseId));
        if (itemId <= 0) throw new ArgumentException("Invalid item id.", nameof(itemId));
        if (qty <= 0) throw new ArgumentException("Quantity must be greater than zero.", nameof(qty));
    }

    private static Guid ParseUserId(string userId)
        => Guid.TryParse(userId, out var id) && id != Guid.Empty
            ? id : throw new ArgumentException("A valid user id is required.", nameof(userId));

    private static Guid ResolveCompanyId()
        => Guid.TryParse(Environment.GetEnvironmentVariable("SHOUTECH_COMPANY_ID"), out var id) && id != Guid.Empty
            ? id : throw new InvalidOperationException("SHOUTECH_COMPANY_ID is not configured.");
}
