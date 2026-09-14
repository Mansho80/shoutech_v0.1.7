using ShouTech.Domain.Entities;

namespace ShouTech.Domain.Interfaces
{
    public interface ICompanyRepository
    {
        Task<List<Company>> GetAllAsync();
        Task<Company?> GetByCodeAsync(string code);
        Task<bool> HasCompaniesAsync();
        Task AddAsync(Company company);
    }
}