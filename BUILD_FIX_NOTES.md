# ShouTech ERP v0.1.7 — Frozen Company Session Build Fix

Applied fixes based on the user's actual Windows `dotnet build` log:

1. Added `using ShouTech.Domain.Interfaces;` to `ComWin.xaml.cs` so `DatabaseProviderNames` resolves.
2. Added null-safe handling for `Application.Current` at both `SelectedCompany` assignments.
3. Explicitly typed `Grid` child iteration as `UIElement` in `MWin.xaml.cs`, fixing `Grid.GetRow` and `IsEnabled` compilation errors.
4. Frozen-state menu behavior now leaves only the Ribbon `File -> Open` path active; the legacy main menu is fully disabled during handoff.
5. Preserved the agreed behavior: cancelling the target-company login does not restore the previous company; the shell remains frozen and only Ribbon `File -> Open` is available.

Validation in this environment: static source/XML inspection only. `dotnet` is not installed in this container, so a local Windows build remains the authoritative compiler check.
