-- Currency support migration.
IF OBJECT_ID(N'dbo.Currencies', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Currencies
    (
        CurrencyCode CHAR(3) NOT NULL CONSTRAINT PK_Currencies PRIMARY KEY,
        CurrencyName NVARCHAR(100) NOT NULL,
        Symbol NVARCHAR(10) NULL,
        DecimalPlaces TINYINT NOT NULL CONSTRAINT DF_Currencies_DecimalPlaces DEFAULT 2,
        IsActive BIT NOT NULL CONSTRAINT DF_Currencies_IsActive DEFAULT 1,
        CreatedAt DATETIME2(7) NOT NULL CONSTRAINT DF_Currencies_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_Currencies_DecimalPlaces CHECK (DecimalPlaces <= 6)
    );
END;
