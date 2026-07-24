-- =============================================
-- Complete Cleanup Guide: Remove NeedsWriteback
-- =============================================

/*
This guide removes NeedsWriteback column and logic from the entire solution.
Execute steps in order.
*/

-- =============================================
-- STEP 1: Update Pipeline 2 (in Fabric Portal)
-- =============================================
/*
1. Open Pipeline 2 (SyncBackEmployees)
2. Click Copy data activity
3. Go to Source tab
4. Change query from:
   
   SELECT EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy
   FROM dbo.Employees
   WHERE NeedsWriteback = 1
   
   To:
   
   SELECT EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy
   FROM dbo.Employees
   
5. Save and Publish
*/

-- =============================================
-- STEP 2: Remove Column from Fabric SQL Database
-- =============================================

-- Run in FABRIC SQL DATABASE query editor
USE HRData;
GO

ALTER TABLE dbo.Employees
DROP COLUMN IF EXISTS NeedsWriteback;
GO

PRINT '✅ Removed NeedsWriteback from Fabric SQL Database';
GO

-- Verify schema
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Employees'
ORDER BY ORDINAL_POSITION;
GO


-- =============================================
-- STEP 3: Remove Column from On-Prem SQL Server
-- =============================================

-- Run in ON-PREM SQL SERVER
USE HRDemo;
GO

IF EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID('dbo.Employees') 
    AND name = 'NeedsWriteback'
)
BEGIN
    ALTER TABLE dbo.Employees
    DROP COLUMN NeedsWriteback;
    PRINT '✅ Removed NeedsWriteback from On-Prem SQL Server';
END
ELSE
BEGIN
    PRINT 'ℹ️ NeedsWriteback column already removed from On-Prem';
END
GO

-- Verify schema
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Employees'
ORDER BY ORDINAL_POSITION;
GO


-- =============================================
-- STEP 4: Update Fabric Stored Procedure (Optional)
-- =============================================

-- Run in FABRIC SQL DATABASE
USE HRData;
GO

-- The usp_UpdateEmployee procedure doesn't use NeedsWriteback
-- So no changes needed here!

-- Verify it still works
SELECT OBJECT_ID('dbo.usp_UpdateEmployee');
GO


-- =============================================
-- STEP 5: Verify Both Systems
-- =============================================

-- FABRIC SQL DATABASE
SELECT 
    'Fabric' AS System,
    EmployeeID, 
    EmployeeName, 
    LastModifiedDate, 
    ModifiedBy 
FROM dbo.Employees;
GO

-- ON-PREM SQL SERVER
SELECT 
    'On-Prem' AS System,
    EmployeeID, 
    EmployeeName, 
    LastModifiedDate, 
    ModifiedBy 
FROM HRDemo.dbo.Employees;
GO


-- =============================================
-- STEP 6: Test End-to-End Flow
-- =============================================

/*
1. Test User Data Function in Fabric:
   - employeeId: 2
   - employeeName: "Mo Khan Updated"
   - modifiedBy: "test@contoso.com"

2. Verify in Fabric SQL Database:
   SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
   
3. Run Pipeline 2 manually

4. Verify in On-Prem SQL Server:
   SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
   
   Should show "Mo Khan Updated"
*/
