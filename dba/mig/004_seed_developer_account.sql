/*
   Creates the controlled developer account in dbo.Users.
   Supply these SQLCMD variables at execution time; never commit their values:
     DeveloperCompanyId
     DeveloperPasswordHash
     DeveloperPasswordSalt
*/
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
    IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
        THROW 50001, 'dbo.Users does not exist. Apply the user schema first.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Username = N'developer')
    BEGIN
        INSERT INTO dbo.Users
        (
            UserID,
            CompanyID,
            Username,
            PasswordHash,
            PasswordSalt,
            MustChangePassword,
            TwoFactorEnabled,
            FullNameAR,
            FullNameEN,
            Email,
            PreferredLanguage,
            IsLocked,
            IsActive,
            IsDeleted,
            CreatedAt
        )
        VALUES
        (
            NEWID(),
            '$(DeveloperCompanyId)',
            N'developer',
            '$(DeveloperPasswordHash)',
            '$(DeveloperPasswordSalt)',
            1,
            0,
            N'حساب المطور',
            N'Platform Developer',
            N'developer@shoutech.local',
            N'ar-SA',
            0,
            1,
            0,
            SYSUTCDATETIME()
        );
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO