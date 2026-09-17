# Pattern 1: UDF and Fabric SQL Database

Use this pattern for interactive report writeback. The UDF calls one parameterized stored procedure, and the procedure updates the employee plus its audit record in one SQL transaction.

## Prerequisites

- A Fabric workspace on a capacity and in a region that supports User Data Functions.
- Permission to create and publish a UDF and to create objects in a Fabric SQL Database.
- Power BI Desktop or the Power BI service for the data function button.

## Deploy

1. Create a **SQL database** item. The sample uses the name `HRData`.
2. In its query editor, run these scripts in order:
   - [`01-create-database-objects.sql`](../scripts/sql/01-create-database-objects.sql)
   - [`02-seed-sample-data.sql`](../scripts/sql/02-seed-sample-data.sql), if sample rows are useful
3. Create a **User data functions** item named `EmployeeWritebackFunctions`.
4. In **Manage connections**, add the SQL database and set its alias to `HRData`.
5. Replace the generated function source with [`function_app.py`](../fabric-items/EmployeeWritebackFunctions.UserDataFunction/function_app.py).
6. Test `get_employee_info`, then test `update_employee` with a seeded employee ID.
7. Publish the UDF. Published changes have a two-minute republish cooldown.

The UDF derives `ModifiedBy` from `udfContext.executing_user`; the report does not supply or impersonate an audit identity. All SQL values are passed as parameters.

## Connect Power BI

1. Build a report over `dbo.Employees`. DirectQuery or Direct Lake usually gives the clearest writeback experience; import mode depends on task-flow refresh behavior.
2. Add a table or other visual that allows one employee to be selected.
3. Add an input slicer for the new employee name.
4. Add a button and set **Action** to **Data function**.
5. Select the destination workspace, `EmployeeWritebackFunctions`, and `update_employee`.
6. Map `employeeId` to the selected employee key and `employeeName` to the input slicer.
7. Publish the report and test the button in the Power BI service.

The UDF must return `str` to appear as a Power BI data function. This sample returns a short success message and uses `fn.UserThrownError` for expected user-facing failures.

`list_employees` intentionally returns a structured list for notebook or UDF test diagnostics, so it is not a Power BI data function button target.

## Verify

Run [`03-test-writeback.sql`](../scripts/sql/03-test-writeback.sql) to test the stored procedure and audit behavior inside a transaction that is rolled back. After testing the UDF, verify the live result:

```sql
SELECT EmployeeId, EmployeeName, ModifiedDate, ModifiedBy
FROM dbo.Employees
ORDER BY EmployeeId;

SELECT TOP (20) *
FROM dbo.EmployeeWritebackAudit
ORDER BY AuditId DESC;
```

## Production notes

- Grant the UDF connection only the permissions required to execute the procedure and read approved objects.
- Add business authorization independently of report row-level security. RLS controls what users see; it does not by itself prove they may mutate the selected row.
- Keep the transaction short. Add a row-version input and compare it in the procedure if users must detect edits made after their report view was loaded.
- Fabric SQL Database has its own current platform limitations; review the linked Learn page before adopting features beyond this sample.