namespace ShouTech.App.Services;

/// <summary>
/// Compatibility name retained for existing consumers. ThemeService is the
/// single implementation and canonical resource-dictionary owner.
/// </summary>
public sealed class ThmServ : ThemeService, IThmServ
{
}
