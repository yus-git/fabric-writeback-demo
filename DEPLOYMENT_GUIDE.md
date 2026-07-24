# Fabric Writeback Demo - Deployment Guide

## Overview
This repository contains a complete Microsoft Fabric solution demonstrating Power BI writeback functionality using User-Defined Functions (UDF), Data Pipelines, and SQL Database.

**Workspace ID**: `5720b110-927c-4145-a4a4-d214a30908f8`

## Architecture Components

### 1. SQL Database: HRData
- **Purpose**: Central data store for employee records
- **Type**: Fabric SQL Database
- **Key Tables**: 
  - `Employees` - Master employee data
  - `NeedsWriteback` - Staging table for changes

### 2. User-Defined Function: EmployeeWritebackFunctions
- **Purpose**: Enables writeback from Power BI reports
- **Location**: `artifacts/udf/`
- **Files**:
  - `udf-corrected.py` - Basic UDF implementation
  - `udf-with-pipeline-trigger.py` - UDF with pipeline orchestration

### 3. Data Pipelines

#### Pipeline_IngestEmployees
- **Purpose**: Initial data ingestion into HRData SQL Database
- **Configuration**: See `scripts/02-pipeline-ingest-config.md`

#### Pipeline_Writeback_to_On-Prem
- **Purpose**: Sync written-back changes to on-premises systems
- **Configuration**: See `scripts/04-pipeline-syncback-config.md`
- **Definition**: `artifacts/pipelines/pipeline-definition.json`

### 4. Semantic Model
- **Name**: Semantic Model
- **Purpose**: Data model for Power BI report
- **Setup**: See `scripts/03-semantic-model-setup.md`

### 5. Power BI Report: Employee Records Dashboard
- **Purpose**: Interactive dashboard with writeback capability
- **Features**:
  - View employee records
  - Edit employee data inline
  - Changes written back via UDF
  - Sync to on-premises via pipeline

## Deployment Steps

### Prerequisites
- Microsoft Fabric capacity (F2 or higher)
- Azure subscription (for on-premises gateway if needed)
- Power BI Premium per User (PPU) or Premium capacity

### Step 1: Create Fabric Workspace
```powershell
# Using Azure CLI or Fabric Portal
# Create a new workspace with appropriate capacity
```

### Step 2: Deploy SQL Database
1. Create SQL Database item named "HRData"
2. Run table creation script:
```sql
-- See scripts/01-table-creation.sql
```

### Step 3: Deploy User-Defined Function
1. Create UDF item named "EmployeeWritebackFunctions"
2. Copy code from `artifacts/udf/udf-with-pipeline-trigger.py`
3. Configure function endpoint
4. Test function with sample data

**Key UDF Features**:
- RESTful API endpoint for Power BI writeback
- Inserts changes into `NeedsWriteback` staging table
- Triggers pipeline for downstream sync
- Returns success/error status

### Step 4: Deploy Pipelines

#### 4a. Pipeline_IngestEmployees
1. Create Data Pipeline item
2. Configure source connection (CSV, Azure SQL, etc.)
3. Map to HRData tables
4. Schedule or trigger manually

#### 4b. Pipeline_Writeback_to_On-Prem
1. Create Data Pipeline item
2. Import definition from `artifacts/pipelines/pipeline-definition.json`
3. Configure:
   - Source: `NeedsWriteback` table in HRData
   - Destination: On-premises SQL Server
   - Gateway connection
4. Add stored procedure activity:
```sql
-- See scripts/usp-update-employee-with-pipeline-trigger.sql
```

### Step 5: Deploy Semantic Model
1. Create semantic model item
2. Connect to HRData SQL endpoint
3. Configure tables and relationships
4. Follow `scripts/03-semantic-model-setup.md`

### Step 6: Deploy Power BI Report
1. Create report from semantic model
2. Add visual elements for employee data
3. Configure writeback buttons/actions
4. Set UDF endpoint in custom visual or button action

## Writeback Flow

```
User edits in Power BI Report
    ↓
Button/Action triggers HTTP request
    ↓
User-Defined Function (UDF) receives data
    ↓
UDF inserts into NeedsWriteback table
    ↓
UDF triggers Pipeline_Writeback_to_On-Prem
    ↓
Pipeline reads from NeedsWriteback
    ↓
Pipeline executes merge/update on on-premises SQL
    ↓
Pipeline marks record as processed
    ↓
Success confirmation returned to user
```

## Testing

### Test Writeback Functionality
```sql
-- See scripts/test-writeback.sql
SELECT * FROM NeedsWriteback WHERE IsProcessed = 0;
```

### Cleanup Test Data
```sql
-- See scripts/cleanup-test-tables.sql
```

## Troubleshooting

### UDF Not Responding
- Check UDF deployment status
- Verify endpoint URL
- Check authentication tokens
- Review UDF logs in Fabric portal

### Pipeline Failures
- Check gateway connectivity
- Verify credentials for on-premises connection
- Review pipeline run history
- Check `NeedsWriteback` table for stuck records

### Writeback Not Syncing
```sql
-- Check for unprocessed records
-- See scripts/cleanup-needswriteback-complete.sql
```

## Maintenance Scripts

All maintenance scripts located in `scripts/`:
- `cleanup-needswriteback-complete.sql` - Remove processed records
- `remove-needswriteback.sql` - Clear staging table
- `get-fabric-pipeline-ids.ps1` - Get pipeline IDs for configuration
- `get-fabric-sql-endpoint.ps1` - Get SQL endpoint connection string

## Security Considerations

1. **UDF Authentication**: Use Fabric service principal or managed identity
2. **Gateway Security**: Secure gateway credentials in Azure Key Vault
3. **SQL Permissions**: Grant minimal permissions to service accounts
4. **Row-Level Security**: Apply RLS in semantic model if needed

## Additional Resources

- [Quick Start Guide](QUICK_START.md)
- [Writeback Setup Guide](WRITEBACK_SETUP_GUIDE.md)
- [Demo Checklist](DEMO_CHECKLIST.md)
- [Automated Demo Setup](AUTOMATED_DEMO_SETUP.md)
- [OPDG Migration Guide](OPDG_MIGRATION_GUIDE.md)

## Support

For issues or questions, refer to the Fabric documentation:
- [Microsoft Fabric Documentation](https://learn.microsoft.com/fabric/)
- [Power BI Writeback](https://learn.microsoft.com/power-bi/create-reports/service-interact-with-power-bi-report)
- [User-Defined Functions](https://learn.microsoft.com/fabric/data-engineering/user-defined-functions)

---

**Last Updated**: 2026-07-24
**Workspace**: Fabric Writeback Demo
**Workspace ID**: 5720b110-927c-4145-a4a4-d214a30908f8
