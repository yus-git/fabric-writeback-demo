-- =============================================
-- Remove NeedsWriteback Column from On-Premises SQL Server
-- =============================================

USE HRDemo;
GO

-- Drop the column if it exists
IF EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID('dbo.Employees') 
    AND name = 'NeedsWriteback'
)
BEGIN
    ALTER TABLE dbo.Employees
    DROP COLUMN NeedsWriteback;
    
    PRINT '✅ Dropped NeedsWriteback column from On-Prem SQL Server';
END
ELSE
BEGIN
    PRINT 'ℹ️ NeedsWriteback column does not exist on-prem';
END
GO

-- Verify the table structure
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Employees'
ORDER BY ORDINAL_POSITION;
GO

-- Show current data
SELECT * FROM dbo.Employees;
GO
