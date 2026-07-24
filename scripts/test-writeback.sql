-- Test Writeback Stored Procedure
-- Run this in Fabric SQL Database (HRData) Query Editor

-- Step 1: View current data
SELECT * FROM dbo.Employees ORDER BY EmployeeID;

-- Step 2: Test the UPDATE stored procedure
EXEC dbo.usp_UpdateEmployee 
    @EmployeeID = 2,
    @EmployeeName = 'Mo',
    @ModifiedBy = 'Test User';

-- Step 3: Verify the change
SELECT * FROM dbo.Employees WHERE EmployeeID = 2;

-- Expected result: EmployeeName should be 'Mo'

-- Step 4: Test another update
EXEC dbo.usp_UpdateEmployee 
    @EmployeeID = 3,
    @EmployeeName = 'Sarah Lee',
    @ModifiedBy = 'Test User';

-- Step 5: View all changes
SELECT 
    EmployeeID,
    EmployeeName,
    LastModifiedDate,
    ModifiedBy
FROM dbo.Employees 
ORDER BY LastModifiedDate DESC;

-- If you want to reset the data back to original:
/*
UPDATE dbo.Employees SET EmployeeName = 'Mohammed', ModifiedBy = 'System' WHERE EmployeeID = 2;
UPDATE dbo.Employees SET EmployeeName = 'Sarah', ModifiedBy = 'System' WHERE EmployeeID = 3;
*/
