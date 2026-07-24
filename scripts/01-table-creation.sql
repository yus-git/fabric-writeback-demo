-- =====================================================
-- Fabric SQL Database Writeback Solution
-- Step 1: Table Creation Scripts
-- =====================================================

-- =====================================================
-- PART A: Run on ON-PREM SQL SERVER
-- =====================================================

-- Create database (if needed)
-- CREATE DATABASE HRSystem;
-- GO

USE HRSystem; -- Or your database name
GO

-- Drop table if exists (for testing)
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL
    DROP TABLE dbo.Employees;
GO

-- Create Employees table
CREATE TABLE dbo.Employees (
    EmployeeID INT PRIMARY KEY,
    EmployeeName NVARCHAR(255) NOT NULL,
    LastModifiedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedBy NVARCHAR(100) DEFAULT SYSTEM_USER
);
GO

-- Create index for efficient merge operations
CREATE INDEX IX_Employees_LastModifiedDate ON dbo.Employees(LastModifiedDate);
GO

-- Insert sample data
INSERT INTO dbo.Employees (EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy)
VALUES 
    (1, 'Yusra', GETDATE(), 'System'),
    (2, 'Mohammed', GETDATE(), 'System'),
    (3, 'Sarah Johnson', GETDATE(), 'System'),
    (4, 'Michael Chen', GETDATE(), 'System'),
    (5, 'Emily Davis', GETDATE(), 'System');
GO

-- Verify data
SELECT * FROM dbo.Employees;
GO

-- =====================================================
-- PART B: Run on FABRIC SQL DATABASE (HRData)
-- =====================================================

-- Note: Execute these in the Fabric SQL Database "HRData" via:
-- 1. SQL Query Editor in Fabric portal, OR
-- 2. Azure Data Studio connected to Fabric SQL DB, OR
-- 3. VS Code with SQL extension

-- Drop table if exists (for testing)
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL
    DROP TABLE dbo.Employees;
GO

-- Create Employees table (same schema as on-prem)
CREATE TABLE dbo.Employees (
    EmployeeID INT PRIMARY KEY,
    EmployeeName NVARCHAR(255) NOT NULL,
    LastModifiedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedBy NVARCHAR(100) DEFAULT SYSTEM_USER
);
GO

-- Create index for efficient merge operations
CREATE INDEX IX_Employees_LastModifiedDate ON dbo.Employees(LastModifiedDate);
GO

-- =====================================================
-- PART C: Stored Procedure for Merge (on ON-PREM)
-- =====================================================

USE HRSystem;
GO

-- Create stored procedure for merge operation (used by Pipeline 2)
CREATE OR ALTER PROCEDURE dbo.usp_MergeEmployees
    @EmployeeID INT,
    @EmployeeName NVARCHAR(255),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    MERGE INTO dbo.Employees AS Target
    USING (
        SELECT 
            @EmployeeID AS EmployeeID,
            @EmployeeName AS EmployeeName,
            @ModifiedBy AS ModifiedBy
    ) AS Source
    ON Target.EmployeeID = Source.EmployeeID
    WHEN MATCHED THEN
        UPDATE SET 
            EmployeeName = Source.EmployeeName,
            LastModifiedDate = GETDATE(),
            ModifiedBy = Source.ModifiedBy
    WHEN NOT MATCHED THEN
        INSERT (EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy)
        VALUES (Source.EmployeeID, Source.EmployeeName, GETDATE(), Source.ModifiedBy);
END;
GO

-- =====================================================
-- PART D: User Defined Function (UDF) for Writeback in Fabric SQL DB
-- =====================================================

-- Note: Run this in FABRIC SQL DATABASE (HRData)

-- Create stored procedure for writeback updates
CREATE OR ALTER PROCEDURE dbo.usp_UpdateEmployee
    @EmployeeID INT,
    @EmployeeName NVARCHAR(255),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE dbo.Employees
    SET 
        EmployeeName = @EmployeeName,
        LastModifiedDate = GETDATE(),
        ModifiedBy = @ModifiedBy
    WHERE EmployeeID = @EmployeeID;
    
    -- Return the updated record
    SELECT * FROM dbo.Employees WHERE EmployeeID = @EmployeeID;
END;
GO

-- =====================================================
-- Validation Queries
-- =====================================================

-- Check record counts
SELECT COUNT(*) AS RecordCount FROM dbo.Employees;

-- Check for schema differences
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Employees'
ORDER BY ORDINAL_POSITION;
