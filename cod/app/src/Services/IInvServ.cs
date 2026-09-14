// shoutech_erp_v0.1.6/cod/app/src/Services/IInvServ.cs
using System;
using System.Threading;
using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    public interface IInvServ
    {
        Task<IReadOnlyList<InventoryItem>> GetItemsAsync(string? search = null, CancellationToken ct = default);
        Task<InventoryItem> GetItemAsync(int id, CancellationToken ct = default);
        // Items
        Task<int> CreateItemAsync(string code, string name, string? name2, int categoryId,
            string unit, decimal cost, decimal price, string userId, CancellationToken ct = default);

        Task UpdateItemAsync(int id, string name, string? name2, int categoryId,
            string unit, decimal cost, decimal price, string userId, CancellationToken ct = default);

        Task SoftDeleteItemAsync(int id, string userId, CancellationToken ct = default);

        Task<bool> ItemCodeExistsAsync(string code, int? excludeId = null, CancellationToken ct = default);

        // Stock
        Task<long> PostStockInAsync(long warehouseId, int itemId, decimal qty, decimal cost,
            string? refDoc, string userId, CancellationToken ct = default);

        Task<long> PostStockOutAsync(long warehouseId, int itemId, decimal qty,
            string? refDoc, string userId, CancellationToken ct = default);

        Task<decimal> GetAvailableQtyAsync(long warehouseId, int itemId, CancellationToken ct = default);
    }
}