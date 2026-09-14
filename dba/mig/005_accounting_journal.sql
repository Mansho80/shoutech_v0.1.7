SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.JournalEntries', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.JournalEntries
    (
        JournalEntryId UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_JournalEntries PRIMARY KEY,
        CompanyId UNIQUEIDENTIFIER NOT NULL,
        EntryDate DATE NOT NULL,
        Description NVARCHAR(500) NOT NULL,
        Status TINYINT NOT NULL CONSTRAINT DF_JournalEntries_Status DEFAULT 0,
        CreatedBy NVARCHAR(100) NOT NULL,
        CreatedAt DATETIME2(7) NOT NULL CONSTRAINT DF_JournalEntries_CreatedAt DEFAULT SYSUTCDATETIME(),
        PostedBy NVARCHAR(100) NULL,
        PostedAt DATETIME2(7) NULL,
        ReversedBy NVARCHAR(100) NULL,
        ReversedAt DATETIME2(7) NULL,
        RowVersion ROWVERSION NOT NULL,
        CONSTRAINT CK_JournalEntries_Status CHECK (Status IN (0, 1, 2)),
        CONSTRAINT CK_JournalEntries_Description CHECK (LEN(LTRIM(RTRIM(Description))) > 0)
    );
END;
GO

IF OBJECT_ID(N'dbo.JournalEntryLines', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.JournalEntryLines
    (
        JournalEntryLineId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_JournalEntryLines PRIMARY KEY,
        JournalEntryId UNIQUEIDENTIFIER NOT NULL,
        LineNumber INT NOT NULL,
        AccountId UNIQUEIDENTIFIER NOT NULL,
        Debit DECIMAL(19,4) NOT NULL CONSTRAINT DF_JournalEntryLines_Debit DEFAULT 0,
        Credit DECIMAL(19,4) NOT NULL CONSTRAINT DF_JournalEntryLines_Credit DEFAULT 0,
        CostCenter NVARCHAR(100) NULL,
        Note NVARCHAR(500) NULL,
        CONSTRAINT FK_JournalEntryLines_Entries FOREIGN KEY (JournalEntryId) REFERENCES dbo.JournalEntries(JournalEntryId),
        CONSTRAINT UQ_JournalEntryLines_Number UNIQUE (JournalEntryId, LineNumber),
        CONSTRAINT CK_JournalEntryLines_Amounts CHECK
        ((Debit >= 0) AND (Credit >= 0) AND ((Debit > 0 AND Credit = 0) OR (Credit > 0 AND Debit = 0)))
    );
END;
GO

IF OBJECT_ID(N'dbo.JournalAuditEvents', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.JournalAuditEvents
    (
        JournalAuditEventId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_JournalAuditEvents PRIMARY KEY,
        JournalEntryId UNIQUEIDENTIFIER NOT NULL,
        EventType TINYINT NOT NULL,
        Actor NVARCHAR(100) NOT NULL,
        EventAt DATETIME2(7) NOT NULL CONSTRAINT DF_JournalAuditEvents_EventAt DEFAULT SYSUTCDATETIME(),
        Details NVARCHAR(1000) NULL,
        CONSTRAINT FK_JournalAuditEvents_Entries FOREIGN KEY (JournalEntryId) REFERENCES dbo.JournalEntries(JournalEntryId),
        CONSTRAINT CK_JournalAuditEvents_EventType CHECK (EventType IN (1, 2, 3))
    );
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JournalEntries_PreventPostedMutation
ON dbo.JournalEntries
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM deleted oldRow
        INNER JOIN inserted newRow ON newRow.JournalEntryId = oldRow.JournalEntryId
         WHERE oldRow.Status IN (1, 2)
          AND (oldRow.EntryDate <> newRow.EntryDate
               OR oldRow.Description <> newRow.Description
             OR (oldRow.Status = 2 AND newRow.Status <> 2)
             OR (oldRow.Status = 1 AND newRow.Status NOT IN (1, 2)))
    )
        THROW 51001, 'Posted or reversed journal entries cannot be mutated.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JournalEntryLines_PreventPostedMutation
ON dbo.JournalEntryLines
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.JournalEntries entryRow
        INNER JOIN
        (
            SELECT JournalEntryId FROM inserted
            UNION
            SELECT JournalEntryId FROM deleted
        ) changed ON changed.JournalEntryId = entryRow.JournalEntryId
        WHERE entryRow.Status <> 0
    )
        THROW 51002, 'Only draft journal entries can have lines changed.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.PostJournalEntry
    @JournalEntryId UNIQUEIDENTIFIER,
    @PostedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.JournalEntries WITH (UPDLOCK, HOLDLOCK)
        WHERE JournalEntryId = @JournalEntryId AND Status = 0
    )
        THROW 51003, 'Only an existing draft journal entry can be posted.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.JournalEntryLines
        WHERE JournalEntryId = @JournalEntryId
        GROUP BY JournalEntryId
        HAVING COUNT(*) >= 2
           AND SUM(Debit) = SUM(Credit)
           AND SUM(Debit) > 0
    )
        THROW 51004, 'Journal entry is not balanced or has no lines.', 1;

    UPDATE dbo.JournalEntries
    SET Status = 1,
        PostedBy = @PostedBy,
        PostedAt = SYSUTCDATETIME()
    WHERE JournalEntryId = @JournalEntryId AND Status = 0;

    INSERT INTO dbo.JournalAuditEvents (JournalEntryId, EventType, Actor, Details)
    VALUES (@JournalEntryId, 1, @PostedBy, N'Journal entry posted.');

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.ReverseJournalEntry
    @JournalEntryId UNIQUEIDENTIFIER,
    @ReversedBy NVARCHAR(100),
    @Details NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.JournalEntries WITH (UPDLOCK, HOLDLOCK)
        WHERE JournalEntryId = @JournalEntryId AND Status = 1
    )
        THROW 51005, 'Only a posted journal entry can be reversed.', 1;

    UPDATE dbo.JournalEntries
    SET Status = 2,
        ReversedBy = @ReversedBy,
        ReversedAt = SYSUTCDATETIME()
    WHERE JournalEntryId = @JournalEntryId AND Status = 1;

    INSERT INTO dbo.JournalAuditEvents (JournalEntryId, EventType, Actor, Details)
    VALUES (@JournalEntryId, 2, @ReversedBy, @Details);

    COMMIT TRANSACTION;
END;
GO