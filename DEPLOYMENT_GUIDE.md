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

-- Employees table (main data)
CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Department NVARCHAR(100),
    Salary DECIMAL(18, 2),
    HireDate DATE,
    LastModified DATETIME DEFAULT GETDATE()
);

-- NeedsWriteback table (staging for changes)
CREATE TABLE NeedsWriteback (
    RecordID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Department NVARCHAR(100),
    Salary DECIMAL(18, 2),
    IsProcessed BIT DEFAULT 0,
    CreatedDate DATETIME DEFAULT GETDATE(),
    ProcessedDate DATETIME NULL
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

**Purpose**: RESTful API endpoint that receives writeback requests from Power BI

1. Create new **User Data Function** item named **EmployeeWritebackFunctions**
2. Copy code from `artifacts/udf/udf-with-pipeline-trigger.py`
3. Update configuration variables:

```python
# Update these values
WORKSPACE_ID = "5720b110-927c-4145-a4a4-d214a30908f8"  # Your workspace
SQL_DATABASE_NAME = "HRData"
PIPELINE_NAME = "Pipeline_Writeback_to_On-Prem"
```

4. **Deploy the UDF** and note the endpoint URL
5. **Test** with a sample POST request:

```json
POST https://your-udf-endpoint.fabric.microsoft.com/api/writeback
Content-Type: application/json
Authorization: Bearer <token>

{
  "EmployeeID": 1001,
  "FirstName": "John",
  "LastName": "Doe",
  "Department": "Engineering",
  "Salary": 75000
}
```

**UDF Functionality**:
- Receives employee change data from Power BI
- Validates input
- Inserts into `NeedsWriteback` staging table
- Triggers `Pipeline_Writeback_to_On-Prem`
- Returns success/error status

---

### Step 5: Deploy Pipeline_Writeback_to_On-Prem

**Purpose**: Sync changes from `NeedsWriteback` back to on-premises SQL Server

1. Create new Data Pipeline named **Pipeline_Writeback_to_On-Prem**
2. Import definition from `artifacts/pipelines/pipeline-definition.json` (or build manually)

**Pipeline Activities**:

**Activity 1: Lookup Unprocessed Records**
```json
{
  "type": "Lookup",
  "name": "GetUnprocessedChanges",
  "source": {
    "type": "SqlQuery",
    "query": "SELECT * FROM NeedsWriteback WHERE IsProcessed = 0"
  },
  "dataset": "HRData"
}
```

**Activity 2: ForEach Record**
```json
{
  "type": "ForEach",
  "name": "ProcessEachChange",
  "items": "@activity('GetUnprocessedChanges').output.value"
}
```

**Activity 3: Stored Procedure (inside ForEach)**
```json
{
  "type": "SqlServerStoredProcedure",
  "name": "MergeToOnPrem",
  "storedProcedureName": "usp_UpdateEmployee",
  "parameters": {
    "EmployeeID": "@item().EmployeeID",
    "FirstName": "@item().FirstName",
    "LastName": "@item().LastName",
    "Department": "@item().Department",
    "Salary": "@item().Salary"
  },
  "linkedService": "OnPremSQLServer"  // via gateway
}
```

**Activity 4: Update Processed Flag**
```json
{
  "type": "SqlQuery",
  "name": "MarkAsProcessed",
  "query": "UPDATE NeedsWriteback SET IsProcessed = 1, ProcessedDate = GETDATE() WHERE RecordID = @{item().RecordID}"
}
```

3. **Configure gateway connection** for on-prem SQL Server destination
4. **Create stored procedure** on on-prem SQL Server:

```sql
-- See scripts/usp-update-employee-with-pipeline-trigger.sql
CREATE PROCEDURE usp_UpdateEmployee
    @EmployeeID INT,
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Department NVARCHAR(100),
    @Salary DECIMAL(18,2)
AS
BEGIN
    MERGE Employees AS target
    USING (SELECT @EmployeeID AS EmployeeID) AS source
    ON target.EmployeeID = source.EmployeeID
    WHEN MATCHED THEN
        UPDATE SET
            FirstName = @FirstName,
            LastName = @LastName,
            Department = @Department,
            Salary = @Salary,
            LastModified = GETDATE()
    WHEN NOT MATCHED THEN
        INSERT (EmployeeID, FirstName, LastName, Department, Salary, HireDate)
        VALUES (@EmployeeID, @FirstName, @LastName, @Department, @Salary, GETDATE());
END;
```

5. Save pipeline and test with manual trigger

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

-- Verify empty staging table
SELECT * FROM HRData.dbo.NeedsWriteback;
```

### Test 2: Test UDF Writeback
1. Open **Employee Records Dashboard** in Power BI Service
2. Edit an employee field
3. Click writeback button
4. Verify record appears in staging:

```sql
SELECT * FROM NeedsWriteback WHERE IsProcessed = 0;
```

### Test 3: Test Pipeline Sync
1. Manually trigger **Pipeline_Writeback_to_On-Prem**
2. Check pipeline run history (should succeed)
3. Verify on-premises database was updated:

```sql
-- On on-prem SQL Server
SELECT * FROM Employees WHERE LastModified > DATEADD(minute, -5, GETDATE());
```

4. Confirm staging table marked as processed:

```sql
SELECT * FROM NeedsWriteback WHERE IsProcessed = 1;
```

---

## Writeback Flow Summary

```
1. User edits data in Power BI report
   ↓
2. Button triggers HTTP POST to UDF endpoint
   ↓
3. UDF inserts change into NeedsWriteback table
   ↓
4. UDF triggers Pipeline_Writeback_to_On-Prem
   ↓
5. Pipeline reads unprocessed records
   ↓
6. Pipeline calls stored procedure via gateway
   ↓
7. On-prem SQL Server updates via MERGE
   ↓
8. Pipeline marks record as processed
   ↓
9. Success response returned to user
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
**Issue**: Changes in `NeedsWriteback` but not syncing  
**Solution**:
- Check if pipeline is triggered (review run history)
- Verify `IsProcessed = 0` for pending records
- Manually trigger pipeline to test

### Gateway Issues
**Issue**: Gateway offline or unreachable  
**Solution**:
- Restart gateway service
- Check network/firewall rules
- Verify gateway registration in Fabric portal

---

## Maintenance

### Cleanup Processed Records
```sql
-- Remove old processed records (run periodically)
-- See scripts/cleanup-needswriteback-complete.sql
DELETE FROM NeedsWriteback 
WHERE IsProcessed = 1 
  AND ProcessedDate < DATEADD(day, -30, GETDATE());
```

### Reset Staging Table
```sql
-- Clear all staging records (use carefully)
-- See scripts/remove-needswriteback.sql
TRUNCATE TABLE NeedsWriteback;
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
