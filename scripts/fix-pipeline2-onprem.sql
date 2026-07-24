-- =============================================
-- Fix On-Prem Database for Pipeline 2
-- =============================================

USE HRDemo;
GO

-- Step 1: Remove NeedsWriteback column if it exists
IF EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID('dbo.Employees') 
    AND name = 'NeedsWriteback'
)
BEGIN
    ALTER TABLE dbo.Employees
    DROP COLUMN NeedsWriteback;
    PRINT '✅ Dropped NeedsWriteback column';
END
ELSE
BEGIN
    PRINT 'ℹ️ NeedsWriteback column does not exist';
END
GO


-- Step 2: Verify current table structure
PRINT 'Current table structure:';
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Employees'
ORDER BY ORDINAL_POSITION;
GO


-- Step 3: Show current data
PRINT 'Current data:';
SELECT * FROM dbo.Employees;
GO


-- Step 4: Recreate merge procedure (without NeedsWriteback)
IF OBJECT_ID('dbo.usp_MergeEmployees', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_MergeEmployees;
GO

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
    
    -- Return number of affected rows
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

PRINT '✅ Recreated merge procedure without NeedsWriteback';
GO


-- Step 5: Test the merge procedure
PRINT 'Testing merge procedure...';

DECLARE @TestData dbo.EmployeeTableType;

-- Test updating existing record
INSERT INTO @TestData 
VALUES (1, 'Yusra Adil - Updated', GETDATE(), 'pipeline@test.com');

EXEC dbo.usp_MergeEmployees @EmployeeData = @TestData;
GO

-- Verify the update
SELECT * FROM dbo.Employees WHERE EmployeeID = 1;
GO


-- Step 6: Check for duplicate records
PRINT 'Checking for duplicate EmployeeIDs...';
SELECT 
    EmployeeID, 
    COUNT(*) as DuplicateCount
FROM dbo.Employees
GROUP BY EmployeeID
HAVING COUNT(*) > 1;
GO

-- If duplicates found, you'll see them listed above
-- If no results, you're good! ✅
