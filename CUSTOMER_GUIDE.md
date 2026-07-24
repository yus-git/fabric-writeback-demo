# Customer Replication Guide - Power BI Writeback with Fabric UDF

## 🎯 Purpose
This repository contains everything needed to replicate the **Power BI writeback solution** using Microsoft Fabric User-Defined Functions (UDF) and on-premises data gateway.

## 📋 What's Included

### Fabric Workspace Artifacts
From workspace: **Fabric Writeback Demo** (ID: `5720b110-927c-4145-a4a4-d214a30908f8`)

| Artifact | Type | Purpose |
|----------|------|---------|
| HRData | SQL Database | Central data store with Employees and NeedsWriteback tables |
| HRData | SQL Endpoint | Query endpoint for semantic model connection |
| EmployeeWritebackFunctions | User-Defined Function | RESTful API for Power BI writeback |
| Pipeline_IngestEmployees | Data Pipeline | Initial data load from on-prem via gateway |
| Pipeline_Writeback_to_On-Prem | Data Pipeline | Sync changes back to on-prem via gateway |
| Semantic Model | Semantic Model | Data model for Power BI report |
| Employee Records Dashboard | Power BI Report | Interactive report with writeback buttons |

### Repository Structure

```
fabric-writeback-demo/
├── artifacts/
│   ├── udf/
│   │   ├── udf-corrected.py              # Basic UDF implementation
│   │   └── udf-with-pipeline-trigger.py  # UDF with pipeline trigger (recommended)
│   ├── pipelines/
│   │   └── pipeline-definition.json      # Writeback pipeline structure
│   └── workspace-manifest.json           # Complete artifact inventory
│
├── scripts/
│   ├── 01-table-creation.sql                          # SQL Database schema setup
│   ├── usp-update-employee-with-pipeline-trigger.sql  # On-prem stored procedure
│   ├── update-merge-procedure-simple.sql              # Alternative merge logic
│   ├── test-writeback.sql                             # Test writeback flow
│   ├── cleanup-needswriteback-complete.sql            # Maintenance cleanup
│   └── remove-needswriteback.sql                      # Reset staging table
│
├── README.md                # Solution overview
├── DEPLOYMENT_GUIDE.md      # Step-by-step deployment
└── CUSTOMER_GUIDE.md        # This file
```

---

## 🚀 Quick Start

### Step 1: Clone Repository
```bash
git clone https://github.com/yus-git/fabric-writeback-demo.git
cd fabric-writeback-demo
```

### Step 2: Review Architecture
See [README.md](README.md) for the complete architecture diagram showing:
- On-premises SQL Server → Gateway → Fabric SQL Database
- Power BI Report → UDF → Staging Table → Pipeline → Gateway → On-prem SQL Server

### Step 3: Follow Deployment Guide
Open [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed step-by-step instructions

---

## 🔑 Key Components to Replicate

### 1. Fabric SQL Database (HRData)

**File**: `scripts/01-table-creation.sql`

**Tables**:
- **Employees** - Master employee data
- **NeedsWriteback** - Staging table for changes awaiting sync to on-prem

Create these in your Fabric SQL Database workspace item.

---

### 2. User-Defined Function (UDF)
**File**: `artifacts/udf/EmployeeWritebackFunctions.py`

**Functions Provided**:

**1. update_employee()** - Main writeback function
```python
@udf.connection(argName="sqlDB", alias="HRData")
@udf.function()
def update_employee(sqlDB: fn.FabricSqlConnection, 
                   employeeId: int, 
                   employeeName: str, 
                   modifiedBy: str) -> str:
    # Validates input
    # Calls stored procedure: EXEC dbo.usp_UpdateEmployee
    # Returns success/error message with emoji
```

**2. get_employee_info()** - Retrieve employee data
```python
def get_employee_info(sqlDB: fn.FabricSqlConnection, 
                      employeeId: int) -> str:
    # Queries employee information
    # Returns formatted employee details
```

**3. list_employees()** - List all employees
```python
def list_employees(sqlDB: fn.FabricSqlConnection) -> list:
    # Returns list of all employees as dictionaries
```

**Key Configuration**:
- Connection alias: `HRData` (points to your Fabric SQL Database)
- Stored procedure called: `usp_UpdateEmployee`
- No direct pipeline triggering (pipeline runs separately or triggered by stored procedure)

**How to Call from Power BI**:
```dax
// In Power BI measure or button action
update_employee(
    [EmployeeID],
    [EmployeeName], 
    USERPRINCIPALNAME()  // Auto-captures user email
)
```

---

### 3. On-Premises Data Gateway

**Required for**:
- Pipeline_IngestEmployees (load data from on-prem to Fabric)
- Pipeline_Writeback_to_On-Prem (sync changes from Fabric to on-prem)

**Setup Steps**:
1. Install gateway on a server with access to on-prem SQL Server
2. Register gateway in Fabric portal
3. Create connection to on-prem SQL Server
4. Use in pipeline configurations

---

### 4. Pipeline_Writeback_to_On-Prem

**File**: `artifacts/pipelines/pipeline-definition.json`

**Activities**:
1. **Lookup** - Query `NeedsWriteback` for unprocessed records (`IsProcessed = 0`)
2. **ForEach** - Iterate through each pending change
3. **Stored Procedure** - Call `usp_UpdateEmployee` on on-prem SQL Server via gateway
4. **Update** - Mark record as processed in `NeedsWriteback`

**Gateway Connection**: Uses on-prem data gateway for secure connectivity

**On-Premises Stored Procedure**:
```sql
-- File: scripts/usp-update-employee-with-pipeline-trigger.sql
CREATE PROCEDURE usp_UpdateEmployee
    @EmployeeID INT,
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Department NVARCHAR(100),
    @Salary DECIMAL(18,2)
AS
BEGIN
    -- MERGE logic to insert or update employee
    MERGE Employees AS target
    USING (SELECT @EmployeeID AS EmployeeID) AS source
    ON target.EmployeeID = source.EmployeeID
    WHEN MATCHED THEN UPDATE SET ...
    WHEN NOT MATCHED THEN INSERT ...
END;
```

Deploy this stored procedure to your on-premises SQL Server.

---

### 5. Power BI Report with Writeback

**Report**: Employee Records Dashboard

**Writeback Configuration**:
1. Add button visual for each editable field
2. Set button action to **Web URL**
3. Configure to POST to UDF endpoint:
   ```
   https://your-udf-endpoint.fabric.microsoft.com/api/writeback
   ```
4. Pass parameters from selected row (EmployeeID, field values)

**Example Button Action**:
```
Action Type: Web URL
URL: https://<your-udf-endpoint>/api/writeback
Method: POST
Headers: Authorization: Bearer <token>
Body: 
{
  "EmployeeID": [EmployeeID from selection],
  "FirstName": [FirstName],
  "LastName": [LastName],
  "Department": [Department],
  "Salary": [Salary]
}
```

---

## 📊 End-to-End Writeback Flow

```
┌──────────────────────────────┐
│  User Edits in Power BI      │
│  (Employee Records Dashboard)│
└──────────────┬───────────────┘
               │ Click writeback button
               ▼
┌──────────────────────────────┐
│  UDF: EmployeeWritebackFunctions │
│  (Fabric Function)           │
└──────────────┬───────────────┘
               │ INSERT INTO NeedsWriteback
               ▼
┌──────────────────────────────┐
│  HRData.NeedsWriteback       │
│  (Staging Table)             │
│  IsProcessed = 0             │
└──────────────┬───────────────┘
               │ UDF triggers
               ▼
┌──────────────────────────────┐
│  Pipeline_Writeback_to_On-Prem│
└──────────────┬───────────────┘
               │ Via on-prem gateway
               ▼
┌──────────────────────────────┐
│  On-Premises SQL Server      │
│  usp_UpdateEmployee          │
│  (MERGE to Employees table)  │
└──────────────┬───────────────┘
               │ Success
               ▼
┌──────────────────────────────┐
│  UPDATE NeedsWriteback       │
│  SET IsProcessed = 1         │
└──────────────────────────────┘
```

---

## 🔧 Customization for Your Environment

### SQL Schema
Modify `scripts/01-table-creation.sql` to match your table structure:
- Add/remove columns
- Change data types
- Adjust constraints

### UDF Logic
Customize `artifacts/udf/udf-with-pipeline-trigger.py`:
- Add validation rules
- Implement business logic
- Add logging/error handling

### Pipeline Mappings
Update pipeline to match your column names and business rules:
- Modify lookup query
- Adjust stored procedure parameters
- Add error handling activities

### Power BI Report
Design report to match your requirements:
- Custom visualizations
- Additional fields
- Conditional writeback logic

---

## ⚙️ Connection Strings to Update

1. **UDF Configuration**:
   - `WORKSPACE_ID` - Your Fabric workspace ID
   - `SQL_DATABASE_NAME` - Your Fabric SQL Database name
   - `PIPELINE_NAME` - Your writeback pipeline name

2. **Gateway Configuration**:
   - On-prem SQL Server connection string
   - SQL authentication credentials (stored in gateway)

3. **Power BI Report**:
   - UDF endpoint URL
   - Authentication token/service principal

---

## 🧪 Testing Your Deployment

### Test 1: Verify Tables Created
```sql
-- In Fabric SQL Database (HRData)
SELECT * FROM INFORMATION_SCHEMA.TABLES;
-- Should see: Employees, NeedsWriteback
```

### Test 2: Test UDF Endpoint
```bash
curl -X POST https://your-udf-endpoint/api/writeback \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "EmployeeID": 1001,
    "FirstName": "Test",
    "LastName": "User",
    "Department": "IT",
    "Salary": 65000
  }'
```

Expected response: `{"status": "success"}`

### Test 3: Verify Staging Table
```sql
-- Check record inserted into staging
SELECT * FROM NeedsWriteback WHERE IsProcessed = 0;
```

### Test 4: Test Pipeline Trigger
1. Manually run `Pipeline_Writeback_to_On-Prem`
2. Check pipeline run history
3. Verify on-prem database updated:
```sql
-- On on-prem SQL Server
SELECT * FROM Employees WHERE EmployeeID = 1001;
```

### Test 5: Verify Processing
```sql
-- Check staging table marked as processed
SELECT * FROM NeedsWriteback WHERE IsProcessed = 1;
```

---

## 🔍 Troubleshooting

### UDF Issues
**Symptom**: UDF returns error or no response  
**Check**:
- UDF deployment status in Fabric portal
- UDF logs for errors
- SQL Database connection permissions
- Request payload format

### Gateway Issues
**Symptom**: Pipeline fails with gateway error  
**Check**:
- Gateway service running
- Gateway connection healthy in Fabric
- Network connectivity from gateway to SQL Server
- SQL authentication credentials valid

### Pipeline Failures
**Symptom**: Pipeline completes but on-prem not updated  
**Check**:
- Stored procedure exists on on-prem SQL Server
- Stored procedure permissions
- Pipeline run history for detailed errors
- `NeedsWriteback` table for stuck records (IsProcessed = 0)

### Writeback Not Working End-to-End
**Symptom**: Button click doesn't sync to on-prem  
**Debug Steps**:
```sql
-- 1. Check if UDF wrote to staging
SELECT * FROM NeedsWriteback ORDER BY CreatedDate DESC;

-- 2. Check if pipeline ran
-- (View in Fabric portal pipeline run history)

-- 3. Check if on-prem updated
-- (Query on-prem SQL Server Employees table)

-- 4. Check for errors
SELECT * FROM NeedsWriteback WHERE IsProcessed = 0;
```

---

## 🛡️ Security Best Practices

1. **Authentication**
   - Use Fabric service principal for UDF
   - Store credentials in Azure Key Vault
   - Enable managed identity where possible

2. **Gateway Security**
   - Install gateway on dedicated secure server
   - Use Windows authentication for SQL Server
   - Restrict network access to gateway machine

3. **SQL Permissions**
   - Grant minimal required permissions
   - Use separate service accounts for read/write
   - Enable auditing on sensitive tables

4. **Data Privacy**
   - Apply Row-Level Security (RLS) in semantic model
   - Encrypt sensitive columns
   - Audit all writeback operations

---

## 📚 Additional Resources

- **Microsoft Fabric**: https://learn.microsoft.com/fabric/
- **On-Premises Data Gateway**: https://learn.microsoft.com/data-integration/gateway/
- **User-Defined Functions**: https://learn.microsoft.com/fabric/data-engineering/user-defined-functions
- **Power BI Writeback**: https://learn.microsoft.com/power-bi/

---

## 📝 Summary

This solution provides a **production-ready Power BI writeback implementation** using:
- ✅ Fabric SQL Database for cloud storage
- ✅ User-Defined Functions for writeback API
- ✅ On-premises data gateway for secure connectivity
- ✅ Data pipelines for automated synchronization
- ✅ Power BI for interactive reporting

**Clone this repo, follow the deployment guide, and customize for your use case!**

---

**Repository**: https://github.com/yus-git/fabric-writeback-demo  
**Workspace ID**: 5720b110-927c-4145-a4a4-d214a30908f8  
**Last Updated**: 2026-07-24
