-- =============================================
-- Cleanup Script: Remove NeedsWriteback Column and Delete Test Tables
-- =============================================
-- Run this in FABRIC SQL DATABASE (HRData)
-- =============================================

USE HRData;
GO

PRINT '========================================';
PRINT 'Starting Cleanup Process';
PRINT '========================================';
PRINT '';

-- =============================================
-- 1. Remove NeedsWriteback Column from Employees Table
-- =============================================

PRINT '1. Removing NeedsWriteback column from Employees table...';

IF EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID('dbo.Employees') 
    AND name = 'NeedsWriteback'
)
BEGIN
    ALTER TABLE dbo.Employees
    DROP COLUMN NeedsWriteback;
    
    PRINT '   ✅ Successfully dropped NeedsWriteback column from dbo.Employees';
END
ELSE
BEGIN
    PRINT '   ℹ️  NeedsWriteback column does not exist in dbo.Employees';
END
GO

-- =============================================
-- 2. Delete Test Table: employee
-- =============================================

PRINT '';
PRINT '2. Deleting test table [employee]...';

IF OBJECT_ID('dbo.employee', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.employee;
    PRINT '   ✅ Successfully dropped table dbo.employee';
END
ELSE
BEGIN
    PRINT '   ℹ️  Table dbo.employee does not exist';
END
GO

-- =============================================
-- 3. Delete Test Table: test load
-- =============================================

PRINT '';
PRINT '3. Deleting test table [test load]...';

IF OBJECT_ID('dbo.[test load]', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.[test load];
    PRINT '   ✅ Successfully dropped table dbo.[test load]';
END
ELSE
BEGIN
    PRINT '   ℹ️  Table dbo.[test load] does not exist';
END
GO

-- =============================================
-- 4. Verify Final Table Structure
-- =============================================

PRINT '';
PRINT '4. Verifying final Employees table structure...';
PRINT '';

SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Employees'
ORDER BY ORDINAL_POSITION;
GO

-- =============================================
-- 5. List All Remaining Tables
-- =============================================

PRINT '';
PRINT '5. Current tables in database:';
PRINT '';

SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
GO

PRINT '';
PRINT '========================================';
PRINT 'Cleanup Process Complete!';
PRINT '========================================';
GO
