using ShouTech.Domain.Entities;

namespace ShouTech.Domain.Interfaces
{
    public interface IUserRepository
    {
        Task<User?> GetByUsernameAsync(string username);
        Task<bool> ValidateCredentialsAsync(string username, string passwordHash);
    }
}