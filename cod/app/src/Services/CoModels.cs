namespace ShouTech.App.Services
{
    public sealed class NewCoReq
    {
        public string CompanyNameAr { get; set; } = string.Empty;
        public string CompanyNameEn { get; set; } = string.Empty;
        public string TaxNumber { get; set; } = string.Empty;
        public string License { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Website { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string Mobile { get; set; } = string.Empty;
        public string AddressLine1 { get; set; } = string.Empty;
        public string AddressLine2 { get; set; } = string.Empty;
        public string City { get; set; } = string.Empty;
        public string Country { get; set; } = string.Empty;
        public string Notes { get; set; } = string.Empty;
        public DateTime FiscalYearStart { get; set; }
        public DateTime FiscalYearEnd { get; set; }
        public string CurrencyCode { get; set; } = "SYP";
        public int DecimalPlaces { get; set; } = 2;
        public string CalendarType { get; set; } = "ميلادي";
        public string NumberGrouping { get; set; } = "3-3-3";
        public string LanguageCode { get; set; } = "ar-SY";
        public string AdminUsername { get; set; } = string.Empty;
        public string AdminPassword { get; set; } = string.Empty;
        public string AdminFullName { get; set; } = string.Empty;
        public string DatabaseProvider { get; set; } = "SQLite";
        public bool PostgreSqlProducerApproval { get; set; }
        public string DbPath { get; set; } = string.Empty;
        public string AltDbPath { get; set; } = string.Empty;
        public string BackupPath { get; set; } = string.Empty;
        public string AltBackupPath { get; set; } = string.Empty;
        public bool AutoBackup { get; set; } = true;
        public string BackupSchedule { get; set; } = "يومي";
        public string BackupTime { get; set; } = "02:00";
    }

    public sealed class CoCreateResult
    {
        public bool Success { get; init; }
        public string Message { get; init; } = string.Empty;
        public string CompanyCode { get; init; } = string.Empty;
        public string CompanyNameAr { get; init; } = string.Empty;
        public bool SavedToDatabase { get; init; }
        public bool SavedLocally { get; init; }
    }

    public sealed class StoredCoRec
    {
        public Guid CompanyId { get; set; } = Guid.NewGuid();
        public string Code { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string NameEn { get; set; } = string.Empty;
        public string TaxNumber { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Website { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string Mobile { get; set; } = string.Empty;
        public string AddressLine1 { get; set; } = string.Empty;
        public string AddressLine2 { get; set; } = string.Empty;
        public string City { get; set; } = string.Empty;
        public string Country { get; set; } = string.Empty;
        public string License { get; set; } = string.Empty;
        public string Notes { get; set; } = string.Empty;
        public DateTime FiscalYearStart { get; set; }
        public DateTime FiscalYearEnd { get; set; }
        public string CurrencyCode { get; set; } = "SYP";
        public int DecimalPlaces { get; set; } = 2;
        public string CalendarType { get; set; } = "ميلادي";
        public string NumberGrouping { get; set; } = "3-3-3";
        public string LanguageCode { get; set; } = "ar-SY";
        public string AdminUsername { get; set; } = string.Empty;
        public string AdminPasswordHash { get; set; } = string.Empty;
        public string AdminPasswordSalt { get; set; } = string.Empty;
        public string AdminFullName { get; set; } = string.Empty;
        public string DatabaseProvider { get; set; } = "SQLite";
        public string DbPath { get; set; } = string.Empty;
        public string AltDbPath { get; set; } = string.Empty;
        public string BackupPath { get; set; } = string.Empty;
        public string AltBackupPath { get; set; } = string.Empty;
        public bool AutoBackup { get; set; } = true;
        public string BackupSchedule { get; set; } = "يومي";
        public string BackupTime { get; set; } = "02:00";
        public bool Enabled { get; set; } = true;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    public sealed class StoredCoFile
    {
        public List<StoredCoRec> Companies { get; set; } = new();
    }
}
