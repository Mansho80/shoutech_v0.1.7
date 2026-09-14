namespace ShouTech.Domain.Interfaces
{
    public interface ILicenseProvider
    {
        bool Validate();
        int MaxClients { get; }
        DateTime? ExpirationDate { get; }
    }
}