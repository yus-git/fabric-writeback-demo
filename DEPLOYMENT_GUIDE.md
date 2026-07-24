# Deployment Guide - Power BI Writeback with Fabric UDF

## Overview
Deploy a complete Power BI writeback solution using Microsoft Fabric User-Defined Functions (UDF), SQL Database, and on-premises data gateway.

**Workspace**: Fabric Writeback Demo  
**Workspace ID**: `5720b110-927c-4145-a4a4-d214a30908f8`

---

## Prerequisites

### Infrastructure
- ✅ Microsoft Fabric capacity (F2 or higher)
- ✅ On-premises SQL Server
- ✅ On-premises data gateway installed and registered
- ✅ Power BI Premium or Premium Per User (PPU)

### Permissions
- ✅ Fabric workspace admin or contributor
- ✅ SQL Server sysadmin or db_owner on on-prem database
- ✅ Gateway admin permissions

---

## Architecture Components

### Fabric Workspace Artifacts (7 total)

1. **HRData** (SQL Database) - Central data store
2. **HRData** (SQL Endpoint) - Query endpoint for semantic model
3. **EmployeeWritebackFunctions** (UDF) - Writeback API endpoint
4. **Pipeline_IngestEmployees** - Initial data load from on-prem
5. **Pipeline_Writeback_to_On-Prem** - Sync changes back to on-prem
6. **Semantic Model** - Data model for reporting
7. **Employee Records Dashboard** (Report) - Interactive PBI report

---

## Deployment Steps

### Step 1: Create Fabric SQL Database

1. In Fabric workspace, create SQL Database item named **HRData**
2. Run the table creation script:

```sql
-- See scripts/01-table-creation.sql

-- Employees table
CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY,
    EmployeeName NVARCHAR(255) NOT NULL,
    LastModifiedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedBy NVARCHAR(100) DEFAULT SYSTEM_USER
);
```

3. Note the SQL endpoint connection string for later use

---

### Step 2: Configure On-Premises Data Gateway

1. **Install gateway** on a machine that can access your on-prem SQL Server
2. **Register gateway** in the Fabric portal
3. **Create connection** to on-premises SQL Server:
   - Go to Settings → Manage connections and gateways
   - Add new connection
   - Select your gateway
   - Enter SQL Server credentials
   - Test connection

---

### Step 3: Deploy Pipeline_IngestEmployees

**Purpose**: Load initial employee data from on-prem to Fabric SQL Database

1. Create new Data Pipeline named **Pipeline_IngestEmployees**
2. Add **Copy Data** activity
3. **Source configuration**:
   - Connection: On-premises SQL Server (via gateway)
   - Table: `Employees`
4. **Destination configuration**:
   - Connection: HRData SQL Database
   - Table: `Employees`
5. Save and run to test

---

### Step 4: Deploy User-Defined Function

**Purpose**: Provides callable functions for Power BI writeback

1. Create new **User Data Function** item named **EmployeeWritebackFunctions**
2. Copy code from `artifacts/udf/EmployeeWritebackFunctions.py`
3. **Configure SQL Database connection**:
   - Connection alias: `HRData`
   - Points to your Fabric SQL Database

4. **Deploy the UDF** and test the functions

**UDF Functions**:

**1. update_employee()** - Main writeback function
```python
update_employee(
    employeeId: int,      # Employee ID to update
    employeeName: str,    # New employee name
    modifiedBy: str       # User email (use USERPRINCIPALNAME() in Power BI)
)
```
- Validates input
- Calls stored procedure `usp_UpdateEmployee` on Fabric SQL Database
- Returns success/error message with emoji indicators

**2. get_employee_info()** - Retrieve employee details
```python
get_employee_info(employeeId: int)
```

**3. list_employees()** - List all employees
```python
list_employees()  # Returns list of employee dictionaries
```

**Test the UDF**:
```python
# From Fabric notebook or Power BI
result = update_employee(1001, "John Doe", "user@company.com")
print(result)  # ✅ Successfully updated John Doe (ID: 1001) by user@company.com
```

---

### Step 5: Deploy Pipeline_Writeback_to_On-Prem

**Purpose**: Sync employee data from Fabric SQL Database to on-premises SQL Server

1. Create new Data Pipeline named **Pipeline_Writeback_to_On-Prem**
2. **Configure manual or scheduled trigger** (no automatic triggering)

**Pipeline Activities**:

**Activity 1: Copy Data from Fabric to On-Prem**
```json
{
  "type": "Copy",
  "name": "SyncEmployees",
  "source": {
    "type": "SqlQuery",
    "query": "SELECT * FROM Employees",
    "dataset": "HRData"
  },
  "sink": {
    "type": "SqlServerStoredProcedure",
    "storedProcedureName": "usp_MergeEmployees",
    "linkedService": "OnPremSQLServer"
  }
}
```

3. **Configure gateway connection** for on-prem SQL Server destination
4. **Create stored procedure** on on-prem SQL Server:

```sql
-- See scripts/01-table-creation.sql (PART C)
CREATE PROCEDURE usp_MergeEmployees
    @EmployeeID INT,
    @EmployeeName NVARCHAR(255),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    MERGE Employees AS target
    USING (SELECT @EmployeeID AS EmployeeID) AS source
    ON target.EmployeeID = source.EmployeeID
    WHEN MATCHED THEN
        UPDATE SET
            EmployeeName = @EmployeeName,
            LastModifiedDate = GETDATE(),
            ModifiedBy = @ModifiedBy
    WHEN NOT MATCHED THEN
        INSERT (EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy)
        VALUES (@EmployeeID, @EmployeeName, GETDATE(), @ModifiedBy);
END;
```

5. **Trigger Options**:
   - **Manual**: Trigger from Fabric portal after UDF updates
   - **Scheduled**: Configure schedule trigger (e.g., every 15 minutes, hourly, daily)
   - No automatic triggering from UDF

6. Save pipeline and test with manual trigger

---

### Step 6: Deploy Semantic Model

1. Create new semantic model named **Semantic Model**
2. Connect to **HRData SQL endpoint** (automatically created with SQL Database)
3. Import `Employees` table
4. Configure:
   - Relationships (if multiple tables)
   - Measures
   - Calculated columns as needed
5. Publish to workspace

---

### Step 7: Deploy Power BI Report

1. Create new report from **Semantic Model**
2. Add visualizations:
   - Table or matrix showing employee records
   - Edit buttons for each row or field
3. **Configure writeback buttons**:
   - Add button visual for each editable field
   - Set button action to **Web URL**
   - Configure URL to call UDF endpoint:

```
https://your-udf-endpoint.fabric.microsoft.com/api/writeback
```

4. **Configure button parameters** (use Power BI parameters/variables):
   - EmployeeID from selected row
   - Field name
   - New value
5. Publish report to workspace as **Employee Records Dashboard**

---

## Testing the Solution

### Test 1: Verify Data Flow
```sql
-- Check data loaded into Fabric
SELECT COUNT(*) FROM HRData.dbo.Employees;

-- View employee data
SELECT * FROM HRData.dbo.Employees;
```

### Test 2: Test UDF Writeback
1. Open **Employee Records Dashboard** in Power BI Service
2. Call UDF function to update an employee:

```dax
// In Power BI measure or button
update_employee(1, "Jane Doe", USERPRINCIPALNAME())
```

3. Verify record updated in Fabric SQL Database:

```sql
SELECT * FROM Employees WHERE EmployeeID = 1;
```

### Test 3: Test Pipeline Sync
1. **Manually trigger** **Pipeline_Writeback_to_On-Prem** from Fabric portal
2. Check pipeline run history (should succeed)
3. Verify on-premises database was updated:

```sql
-- On on-prem SQL Server
SELECT * FROM Employees WHERE LastModifiedDate > DATEADD(minute, -5, GETDATE());
```

---

## Writeback Flow Summary

```
1. User edits data in Power BI report
   ↓
2. Report calls UDF function: update_employee()
   ↓
3. UDF executes stored procedure on Fabric SQL Database
   ↓
4. Fabric SQL Database Employees table updated
   ↓
5. Manual or scheduled trigger of Pipeline_Writeback_to_On-Prem
   ↓
6. Pipeline reads from Fabric SQL Database
   ↓
7. Pipeline calls stored procedure via gateway
   ↓
8. On-prem SQL Server updated via MERGE
   ↓
9. Success - data synced
```

---

## Troubleshooting

### UDF Errors
**Issue**: UDF returns 500 error  
**Solution**: Check UDF logs in Fabric portal. Verify SQL connection string and permissions.

### Pipeline Failures
**Issue**: Pipeline fails to connect to on-prem  
**Solution**: 
- Verify gateway is running and healthy
- Check gateway connection credentials
- Test connection in Fabric settings

**Issue**: Stored procedure not found  
**Solution**: Verify `usp_UpdateEmployee` exists on on-prem SQL Server with correct schema

### No Writeback Sync
**Issue**: Changes in Fabric SQL Database but not syncing to on-prem  
**Solution**:
- Manually trigger pipeline from Fabric portal
- Check pipeline run history for errors
- Verify gateway connectivity
- Check on-prem stored procedure exists

### Gateway Issues
**Issue**: Gateway offline or unreachable  
**Solution**:
- Restart gateway service
- Check network/firewall rules
- Verify gateway registration in Fabric portal

---

## Maintenance

### Monitor Pipeline Runs
- Check pipeline run history in Fabric portal
- Review any failed runs
- Monitor sync frequency (if scheduled)

### Data Integrity Checks
```sql
-- Compare record counts between Fabric and on-prem
-- In Fabric SQL Database
SELECT COUNT(*) AS FabricCount FROM Employees;

-- In on-prem SQL Server
SELECT COUNT(*) AS OnPremCount FROM Employees;
```

---

## Security Considerations

1. **UDF Authentication**: Use Fabric service principal or managed identity
2. **Gateway Security**: Store credentials in Azure Key Vault
3. **SQL Permissions**: Grant minimal required permissions to service accounts
4. **Network Security**: Restrict gateway machine network access
5. **Row-Level Security**: Apply RLS in semantic model if multi-tenant

---

## Resources

- [Microsoft Fabric Documentation](https://learn.microsoft.com/fabric/)
- [On-Premises Data Gateway](https://learn.microsoft.com/data-integration/gateway/)
- [User-Defined Functions](https://learn.microsoft.com/fabric/data-engineering/user-defined-functions)
- [Power BI Writeback](https://learn.microsoft.com/power-bi/)

---

**Last Updated**: 2026-07-24
