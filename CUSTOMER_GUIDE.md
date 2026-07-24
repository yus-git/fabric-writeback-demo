# Customer Replication Guide

## 🎯 Purpose
This repository contains everything needed to replicate the **Fabric Writeback Demo** functionality in your own Microsoft Fabric workspace.

## 📋 What's Included

### 1. **Artifacts** (`/artifacts/`)
All exportable Fabric components with deployment metadata:

- **`workspace-manifest.json`** - Complete artifact inventory with IDs and deployment order
- **`udf/`** - User-Defined Function Python code
  - `udf-corrected.py` - Basic UDF implementation
  - `udf-with-pipeline-trigger.py` - UDF with pipeline orchestration (recommended)
- **`pipelines/`** - Pipeline definitions
  - `pipeline-definition.json` - Writeback-to-On-Prem pipeline structure

### 2. **SQL Scripts** (`/scripts/`)
All database setup and maintenance scripts:

- **Setup Scripts**:
  - `01-table-creation.sql` - Creates Employees and NeedsWriteback tables
  - `usp-update-employee-with-pipeline-trigger.sql` - Stored procedure for merging changes
  
- **Test & Validation**:
  - `test-writeback.sql` - Validate writeback functionality
  - `cleanup-test-tables.sql` - Clean up test data
  
- **Maintenance**:
  - `cleanup-needswriteback-complete.sql` - Remove processed records
  - `remove-needswriteback.sql` - Clear staging table
  
- **Helper Scripts**:
  - `get-fabric-pipeline-ids.ps1` - Retrieve pipeline IDs after deployment
  - `get-fabric-sql-endpoint.ps1` - Get SQL endpoint connection strings

### 3. **Configuration Guides** (`/scripts/`)

- `02-pipeline-ingest-config.md` - Configure initial data ingestion
- `03-semantic-model-setup.md` - Set up the semantic model
- `04-pipeline-syncback-config.md` - Configure writeback pipeline
- `06-pipeline-syncback-implementation.md` - Detailed pipeline implementation

### 4. **Deployment Documentation**

- **`DEPLOYMENT_GUIDE.md`** - Complete step-by-step deployment instructions
- **`QUICK_START.md`** - Fast-track setup for experienced users
- **`WRITEBACK_SETUP_GUIDE.md`** - Detailed writeback configuration
- **`DEMO_CHECKLIST.md`** - Pre-demo validation checklist
- **`AUTOMATED_DEMO_SETUP.md`** - Automated setup scripts
- **`OPDG_MIGRATION_GUIDE.md`** - On-premises data gateway migration

## 🚀 Quick Start for Customers

### Step 1: Clone This Repository
```bash
git clone https://github.com/yus-git/fabric-writeback-demo.git
cd fabric-writeback-demo
```

### Step 2: Review Artifact Manifest
```bash
cat artifacts/workspace-manifest.json
```
This shows all 7 artifacts and their deployment order.

### Step 3: Follow Deployment Guide
Open `DEPLOYMENT_GUIDE.md` and follow these sections in order:
1. Prerequisites
2. Create Fabric Workspace
3. Deploy SQL Database (HRData)
4. Deploy User-Defined Function
5. Deploy Data Pipelines
6. Deploy Semantic Model
7. Deploy Power BI Report

### Step 4: Test Writeback Flow
```sql
-- Run test script
-- See scripts/test-writeback.sql
```

## 🔑 Key Components to Replicate

### 1. SQL Database Schema
**File**: `scripts/01-table-creation.sql`

**Tables**:
- `Employees` - Master employee records
- `NeedsWriteback` - Staging table for changes awaiting sync

### 2. User-Defined Function (UDF)
**File**: `artifacts/udf/udf-with-pipeline-trigger.py`

**Functionality**:
- Receives HTTP POST from Power BI writeback button
- Parses employee change data (ID, Name, Department, Salary, etc.)
- Inserts into `NeedsWriteback` staging table
- Triggers `Pipeline_Writeback_to_On-Prem`
- Returns success/error response

**Key Configuration**:
```python
# Update these with your values
SQL_DATABASE_CONNECTION = "your-hrdata-connection-string"
PIPELINE_ID = "your-pipeline-id"
WORKSPACE_ID = "your-workspace-id"
```

### 3. Writeback Pipeline
**File**: `artifacts/pipelines/pipeline-definition.json`

**Activities**:
1. **Lookup**: Query `NeedsWriteback` for unprocessed records
2. **ForEach**: Iterate through pending changes
3. **Stored Procedure**: Execute merge on target database
4. **Update**: Mark records as processed

**Required Configuration**:
- Source: Fabric SQL Database (HRData)
- Destination: On-premises SQL Server (via Gateway)
- Linked Service: On-premises SQL connection
- Stored Procedure: `usp_UpdateEmployee` (see scripts)

### 4. Power BI Report Setup
**Configuration Steps**:
1. Create report from Semantic Model
2. Add table/matrix visual with employee data
3. Add custom button with writeback action
4. Configure button to call UDF endpoint:
```
Action: Web URL
URL: https://your-udf-endpoint.fabric.microsoft.com/api/writeback
Method: POST
Headers: Authorization: Bearer <token>
Body: { "EmployeeID": [selected value], "Field": [field name], "Value": [new value] }
```

## 📊 Architecture Flow

```
Power BI Report (Edit)
    ↓ HTTP POST
User-Defined Function (UDF)
    ↓ INSERT
NeedsWriteback Table (SQL Database)
    ↓ TRIGGER
Pipeline_Writeback_to_On-Prem
    ↓ MERGE
On-Premises SQL Server
    ↓ UPDATE
NeedsWriteback.IsProcessed = 1
```

## 🔧 Customization Points

### For Your Environment:
1. **SQL Schema**: Modify `01-table-creation.sql` for your table structure
2. **UDF Logic**: Customize `udf-with-pipeline-trigger.py` for your business rules
3. **Pipeline Mappings**: Update pipeline to match your column names
4. **Stored Procedure**: Adapt merge logic in `usp-update-employee-with-pipeline-trigger.sql`

### Connection Strings to Update:
- SQL Database endpoint (HRData)
- On-premises SQL Server connection
- Gateway configuration
- UDF authentication tokens

## 📞 Support & Troubleshooting

### Common Issues:

**UDF Not Responding**
- Verify UDF is published and active
- Check authentication tokens
- Review UDF execution logs in Fabric portal

**Pipeline Fails to Trigger**
- Verify pipeline ID in UDF code
- Check workspace permissions
- Ensure service principal has pipeline execute permissions

**Writeback Not Syncing**
- Query `NeedsWriteback` for stuck records
- Check gateway connectivity
- Review pipeline run history
- Verify stored procedure permissions

### Debug Scripts:
```sql
-- Check pending records
SELECT * FROM NeedsWriteback WHERE IsProcessed = 0;

-- Check processed records
SELECT * FROM NeedsWriteback WHERE IsProcessed = 1 ORDER BY ProcessedDate DESC;

-- Get recent errors
SELECT * FROM NeedsWriteback WHERE ErrorMessage IS NOT NULL;
```

## 📚 Additional Resources

- [Microsoft Fabric Documentation](https://learn.microsoft.com/fabric/)
- [User-Defined Functions Guide](https://learn.microsoft.com/fabric/data-engineering/user-defined-functions)
- [Data Pipelines Documentation](https://learn.microsoft.com/fabric/data-factory/)
- [Power BI Writeback Features](https://learn.microsoft.com/power-bi/create-reports/)

## 📝 License
This solution is provided as-is for demonstration and replication purposes.

---

**Repository**: https://github.com/yus-git/fabric-writeback-demo  
**Workspace**: Fabric Writeback Demo  
**Workspace ID**: 5720b110-927c-4145-a4a4-d214a30908f8  
**Last Updated**: 2026-07-24
