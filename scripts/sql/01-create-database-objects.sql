SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.Employees', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Employees
    (
        EmployeeId INT NOT NULL,
        EmployeeName NVARCHAR(200) NOT NULL,
        ModifiedDate DATETIME2(3) NOT NULL,
        ModifiedBy NVARCHAR(256) NOT NULL,
        RowVersion ROWVERSION NOT NULL,
        CONSTRAINT PK_Employees PRIMARY KEY CLUSTERED (EmployeeId)
    );
END;
GO

IF OBJECT_ID(N'dbo.EmployeeWritebackAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EmployeeWritebackAudit
    (
        AuditId BIGINT IDENTITY(1, 1) NOT NULL,
        EmployeeId INT NOT NULL,
        PreviousName NVARCHAR(200) NOT NULL,
        NewName NVARCHAR(200) NOT NULL,
        ModifiedDate DATETIME2(3) NOT NULL,
        ModifiedBy NVARCHAR(256) NOT NULL,
        CONSTRAINT PK_EmployeeWritebackAudit PRIMARY KEY CLUSTERED (AuditId),
        CONSTRAINT FK_EmployeeWritebackAudit_Employees
            FOREIGN KEY (EmployeeId) REFERENCES dbo.Employees (EmployeeId)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UpdateEmployee
    @EmployeeId INT,
    @EmployeeName NVARCHAR(200),
    @ModifiedBy NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EmployeeId IS NULL OR @EmployeeId <= 0
        THROW 50001, 'EmployeeId must be greater than zero.', 1;

    SET @EmployeeName = LTRIM(RTRIM(@EmployeeName));
    SET @ModifiedBy = LTRIM(RTRIM(@ModifiedBy));

    IF @EmployeeName IS NULL OR @EmployeeName = N'' OR LEN(@EmployeeName) > 200
        THROW 50002, 'EmployeeName must contain between 1 and 200 characters.', 1;

    IF @ModifiedBy IS NULL OR @ModifiedBy = N'' OR LEN(@ModifiedBy) > 256
        THROW 50003, 'ModifiedBy must contain between 1 and 256 characters.', 1;

    DECLARE @PreviousName NVARCHAR(200);
    DECLARE @ModifiedDate DATETIME2(3) = SYSUTCDATETIME();

    BEGIN TRANSACTION;

    SELECT @PreviousName = EmployeeName
    FROM dbo.Employees WITH (UPDLOCK, HOLDLOCK)
    WHERE EmployeeId = @EmployeeId;

    IF @PreviousName IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50004, 'EmployeeId was not found.', 1;
    END;

    UPDATE dbo.Employees
    SET EmployeeName = @EmployeeName,
        ModifiedDate = @ModifiedDate,
        ModifiedBy = @ModifiedBy
    WHERE EmployeeId = @EmployeeId;

    INSERT dbo.EmployeeWritebackAudit
    (
        EmployeeId,
        PreviousName,
        NewName,
        ModifiedDate,
        ModifiedBy
    )
    VALUES
    (
        @EmployeeId,
        @PreviousName,
        @EmployeeName,
        @ModifiedDate,
        @ModifiedBy
    );

    COMMIT TRANSACTION;
END;
GO