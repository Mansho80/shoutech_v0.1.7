namespace ShouTech.App.Services;

public sealed record InventoryItem(
    int Id,
    string Code,
    string Name,
    string? Name2,
    int CategoryId,
    string Unit,
    decimal Cost,
    decimal Price,
    bool IsActive);
