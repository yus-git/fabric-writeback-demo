-- =============================================
-- Update On-Prem Merge Procedure (Remove NeedsWriteback)
-- =============================================

USE HRDemo;
GO

-- Drop the existing procedure
IF OBJECT_ID('dbo.usp_MergeEmployees', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_MergeEmployees;
GO

-- Recreate the procedure without NeedsWriteback logic
CREATE PROCEDURE dbo.usp_MergeEmployees
    @EmployeeData dbo.EmployeeTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;

    MERGE INTO dbo.Employees AS Target
    USING @EmployeeData AS Source
    ON Target.EmployeeID = Source.EmployeeID
    
    -- Update existing records
    WHEN MATCHED THEN
        UPDATE SET
            Target.EmployeeName = Source.EmployeeName,
            Target.LastModifiedDate = Source.LastModifiedDate,
            Target.ModifiedBy = Source.ModifiedBy
    
    -- Insert new records
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy)
        VALUES (Source.EmployeeID, Source.EmployeeName, Source.LastModifiedDate, Source.ModifiedBy);
    
    PRINT '✅ Merge completed successfully';
END;
GO

-- Test the procedure
PRINT 'Testing updated procedure...';

DECLARE @TestData dbo.EmployeeTableType;
INSERT INTO @TestData VALUES (1, 'Test Employee', GETDATE(), 'test@contoso.com');

EXEC dbo.usp_MergeEmployees @EmployeeData = @TestData;
GO

-- Verify
SELECT * FROM dbo.Employees;
GO
