using System.Globalization;
using System.Linq;
using System.IO;
using System.Text.Json;
using ShouTech.App.Common;

namespace ShouTech.App.Services
{
    public static class CoLocalStore
    {
        private static readonly string StorePath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "ShouTech", "ERP", "data", "companies.json");

        public static async Task<List<StoredCoRec>> LoadAsync()
        {
            var all = await LoadAllAsync();
            return all.Where(c => c.Enabled).ToList();
        }

        /// <summary>
        /// All index entries including soft-disabled (removed from window / pending restore).
        /// </summary>
        public static async Task<List<StoredCoRec>> LoadAllAsync()
        {
            try
            {
                if (!File.Exists(StorePath))
                    return new List<StoredCoRec>();

                var json = await File.ReadAllTextAsync(StorePath);
                var file = JsonSerializer.Deserialize<StoredCoFile>(json, JsonDefs.AppSetngRead);
                return file?.Companies?.ToList() ?? new List<StoredCoRec>();
            }
            catch
            {
                return new List<StoredCoRec>();
            }
        }

        public static async Task<List<StoredCoRec>> LoadDisabledAsync()
        {
            var all = await LoadAllAsync();
            return all.Where(c => !c.Enabled).ToList();
        }

        public static async Task SaveCompanyAsync(StoredCoRec company)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(StorePath)!);

            var file = new StoredCoFile();
            if (File.Exists(StorePath))
            {
                try
                {
                    var json = await File.ReadAllTextAsync(StorePath);
                    file = JsonSerializer.Deserialize<StoredCoFile>(json, JsonDefs.AppSetngRead) ?? new StoredCoFile();
                }
                catch
                {
                    file = new StoredCoFile();
                }
            }

            var existing = file.Companies.FirstOrDefault(c =>
                string.Equals(c.Code, company.Code, StringComparison.OrdinalIgnoreCase));

            if (existing != null)
                file.Companies.Remove(existing);

            file.Companies.Add(company);

            var temp = StorePath + ".tmp";
            var output = JsonSerializer.Serialize(file, JsonDefs.Indented);
            await File.WriteAllTextAsync(temp, output);
            File.Move(temp, StorePath, overwrite: true);
        }

        public static async Task<StoredCoRec?> FindUserCompanyAsync(string companyCode, string username, string password)
        {
            var companies = await LoadAsync();
            var company = companies.FirstOrDefault(c =>
                string.Equals(c.Code, companyCode, StringComparison.OrdinalIgnoreCase));

            if (company == null)
                return null;

            if (!string.Equals(company.AdminUsername, username, StringComparison.OrdinalIgnoreCase))
                return null;

            return PwdHash.Verify(password, company.AdminPasswordHash, company.AdminPasswordSalt)
                ? company
                : null;
        }

        public static async Task<StoredCoRec?> FindCompanyAdminByPasswordAsync(string companyCode, string password)
        {
            if (string.IsNullOrWhiteSpace(companyCode) || string.IsNullOrEmpty(password))
                return null;

            var companies = await LoadAsync();
            var company = companies.FirstOrDefault(c =>
                string.Equals(c.Code, companyCode, StringComparison.OrdinalIgnoreCase));

            if (company == null)
                return null;

            return PwdHash.Verify(password, company.AdminPasswordHash, company.AdminPasswordSalt)
                ? company
                : null;
        }

        public static async Task<StoredCoRec?> FindPasswordOwnerAsync(string password)
        {
            if (string.IsNullOrEmpty(password))
                return null;

            var companies = await LoadAsync();
            foreach (var company in companies)
            {
                if (PwdHash.Verify(password, company.AdminPasswordHash, company.AdminPasswordSalt))
                    return company;
            }

            return null;
        }

        public static async Task<string> GenerateNextCodeAsync()
        {
            var companies = await LoadAllAsync();
            var max = 0;

            foreach (var code in companies.Select(c => c.Code))
            {
                if (int.TryParse(code, out var n) && n > max)
                    max = n;
            }

            return (max + 1).ToString("000", CultureInfo.InvariantCulture);
        }

        /// <summary>
        /// Soft-remove from company window: keep the record with Enabled=false so Restore can find it.
        /// </summary>
        public static async Task RemoveFromIndexAsync(string companyCode)
        {
            if (string.IsNullOrWhiteSpace(companyCode))
                return;

            Directory.CreateDirectory(Path.GetDirectoryName(StorePath)!);
            var file = new StoredCoFile();
            if (File.Exists(StorePath))
            {
                try
                {
                    var json = await File.ReadAllTextAsync(StorePath);
                    file = JsonSerializer.Deserialize<StoredCoFile>(json, JsonDefs.AppSetngRead) ?? new StoredCoFile();
                }
                catch
                {
                    file = new StoredCoFile();
                }
            }

            var hit = false;
            foreach (var c in file.Companies)
            {
                if (string.Equals(c.Code, companyCode, StringComparison.OrdinalIgnoreCase))
                {
                    c.Enabled = false;
                    hit = true;
                }
            }

            // If never indexed, still write a tombstone so restore UI can list it after full-delete paths.
            if (!hit)
            {
                file.Companies.Add(new StoredCoRec
                {
                    Code = companyCode,
                    Name = companyCode,
                    NameEn = companyCode,
                    Enabled = false
                });
            }

            var temp = StorePath + ".tmp";
            var output = JsonSerializer.Serialize(file, JsonDefs.Indented);
            await File.WriteAllTextAsync(temp, output);
            File.Move(temp, StorePath, overwrite: true);
        }

        public static async Task RestoreInIndexAsync(string companyCode)
        {
            if (string.IsNullOrWhiteSpace(companyCode))
                return;

            var all = await LoadAllAsync();
            var rec = all.FirstOrDefault(c =>
                string.Equals(c.Code, companyCode, StringComparison.OrdinalIgnoreCase));
            if (rec == null)
                return;
            rec.Enabled = true;
            await SaveCompanyAsync(rec);
        }

        public static async Task ReplaceIndexAsync(IEnumerable<StoredCoRec> companies)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(StorePath)!);
            var file = new StoredCoFile
            {
                Companies = companies?.ToList() ?? new List<StoredCoRec>()
            };
            var temp = StorePath + ".tmp";
            var output = JsonSerializer.Serialize(file, JsonDefs.Indented);
            await File.WriteAllTextAsync(temp, output);
            File.Move(temp, StorePath, overwrite: true);
            await Task.CompletedTask;
        }

    }
}
