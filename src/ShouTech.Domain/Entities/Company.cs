using ShouTech.Domain.Entities;

namespace ShouTech.Domain.Entities
{
    public class Company
    {
        // Company identifiers are GUIDs throughout the persistence boundary.
        // Keeping this aligned prevents accidental cross-tenant integer IDs.
        public Guid Id { get; set; } = Guid.NewGuid();
        public string Code { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string NameEn { get; set; } = string.Empty;
        public bool Enabled { get; set; } = true;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}