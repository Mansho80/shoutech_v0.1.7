SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.Companies', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1 FROM sys.foreign_keys
       WHERE parent_object_id = OBJECT_ID(N'dbo.JournalEntries')
         AND name = N'FK_JournalEntries_Company'
   )
BEGIN
    ALTER TABLE dbo.JournalEntries
        ADD CONSTRAINT FK_JournalEntries_Company
        FOREIGN KEY (CompanyId) REFERENCES dbo.Companies(CompanyId);
END;
GO

/* All journal state changes must carry the company scope.  The old procedures
   accepted only a journal id, which allowed a caller with an id from another
   company to mutate it. */
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.JournalEntries')
      AND name = N'IX_JournalEntries_Company_Status_Date'
)
    CREATE INDEX IX_JournalEntries_Company_Status_Date
        ON dbo.JournalEntries (CompanyId, Status, EntryDate)
        INCLUDE (JournalEntryId, Description);
GO

CREATE OR ALTER PROCEDURE dbo.PostJournalEntry
    @CompanyId UNIQUEIDENTIFIER,
    @JournalEntryId UNIQUEIDENTIFIER,
    @PostedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CompanyId IS NULL OR @CompanyId = '00000000-0000-0000-0000-000000000000'
        THROW 51006, 'Company scope is required.', 1;

    BEGIN TRANSACTION;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.JournalEntries WITH (UPDLOCK, HOLDLOCK)
        WHERE JournalEntryId = @JournalEntryId
          AND CompanyId = @CompanyId
          AND Status = 0
    )
        THROW 51003, 'Only an existing draft journal entry in the company can be posted.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.JournalEntryLines
        WHERE JournalEntryId = @JournalEntryId
        GROUP BY JournalEntryId
        HAVING COUNT(*) >= 2 AND SUM(Debit) = SUM(Credit) AND SUM(Debit) > 0
    )
        THROW 51004, 'Journal entry is not balanced or has no lines.', 1;

    UPDATE dbo.JournalEntries
    SET Status = 1, PostedBy = @PostedBy, PostedAt = SYSUTCDATETIME()
    WHERE JournalEntryId = @JournalEntryId AND CompanyId = @CompanyId AND Status = 0;

    INSERT INTO dbo.JournalAuditEvents (JournalEntryId, EventType, Actor, Details)
    VALUES (@JournalEntryId, 1, @PostedBy, N'Journal entry posted.');
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.ReverseJournalEntry
    @CompanyId UNIQUEIDENTIFIER,
    @JournalEntryId UNIQUEIDENTIFIER,
    @ReversedBy NVARCHAR(100),
    @Details NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CompanyId IS NULL OR @CompanyId = '00000000-0000-0000-0000-000000000000'
        THROW 51006, 'Company scope is required.', 1;

    BEGIN TRANSACTION;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.JournalEntries WITH (UPDLOCK, HOLDLOCK)
        WHERE JournalEntryId = @JournalEntryId
          AND CompanyId = @CompanyId
          AND Status = 1
    )
        THROW 51005, 'Only a posted journal entry in the company can be reversed.', 1;

    UPDATE dbo.JournalEntries
    SET Status = 2, ReversedBy = @ReversedBy, ReversedAt = SYSUTCDATETIME()
    WHERE JournalEntryId = @JournalEntryId AND CompanyId = @CompanyId AND Status = 1;

    INSERT INTO dbo.JournalAuditEvents (JournalEntryId, EventType, Actor, Details)
    VALUES (@JournalEntryId, 2, @ReversedBy, @Details);
    COMMIT TRANSACTION;
END;
GO
