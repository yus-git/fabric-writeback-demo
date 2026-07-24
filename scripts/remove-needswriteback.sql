-- =============================================
-- Remove NeedsWriteback Column from Both Systems
-- =============================================

-- Run this in FABRIC SQL DATABASE
-- Note: Do NOT use USE statement in Fabric SQL Database
-- =============================================

-- Step 1: Drop the default constraint first (if exists)
IF EXISTS (
    SELECT 1 
    FROM sys.default_constraints 
    WHERE parent_object_id = OBJECT_ID('dbo.Employees') 
    AND name = 'DF_Employees_NeedsWriteback'
)
BEGIN
    ALTER TABLE dbo.Employees
    DROP CONSTRAINT DF_Employees_NeedsWriteback;
    
    PRINT '✅ Dropped default constraint DF_Employees_NeedsWriteback';
END
ELSE
BEGIN
    PRINT 'ℹ️ Default constraint does not exist';
END
GO

-- Step 2: Drop the column if it exists
IF EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID('dbo.Employees') 
    AND name = 'NeedsWriteback'
)
BEGIN
    ALTER TABLE dbo.Employees
    DROP COLUMN NeedsWriteback;
    
    PRINT '✅ Dropped NeedsWriteback column from Employees table';
END
ELSE
BEGIN
    PRINT 'ℹ️ NeedsWriteback column does not exist';
END
GO

-- =============================================
-- Delete Test Tables
-- =============================================

-- Delete test table: employee
IF OBJECT_ID('dbo.employee', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.employee;
    PRINT '✅ Dropped test table dbo.employee';
END
ELSE
BEGIN
    PRINT 'ℹ️ Test table dbo.employee does not exist';
END
GO

-- Delete test table: test load
IF OBJECT_ID('dbo.[test load]', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.[test load];
    PRINT '✅ Dropped test table dbo.[test load]';
END
ELSE
BEGIN
    PRINT 'ℹ️ Test table dbo.[test load] does not exist';
END
GO

-- =============================================
-- Verify Results
-- =============================================

-- Verify the Employees table structure
PRINT '';
PRINT 'Final Employees table structure:';
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Employees'
ORDER BY ORDINAL_POSITION;
GO

-- List all remaining tables
PRINT '';
PRINT 'All tables in database:';
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
GO
