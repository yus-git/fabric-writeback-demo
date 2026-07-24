# Power BI Writeback Solution with Fabric UDF

> **Microsoft Fabric solution demonstrating Power BI writeback using User-Defined Functions (UDF) and on-premises data gateway.**

[![Fabric](https://img.shields.io/badge/Microsoft-Fabric-blue)](https://fabric.microsoft.com)
[![Power BI](https://img.shields.io/badge/Power-BI-yellow)](https://powerbi.microsoft.com)

## 🎯 Solution Overview

This solution enables **interactive data writeback** from Power BI reports to on-premises SQL Server:
1. Users view and edit employee records in the **Employee Records Dashboard**
2. Edits trigger a **User-Defined Function (UDF)** that writes changes to Fabric SQL Database
3. A **Data Pipeline** syncs changes to on-premises SQL Server via **on-premises data gateway**
4. All changes are tracked in a staging table for auditing

## Architecture

```
┌─────────────────────────────┐
│   On-Premises SQL Server    │
│   (Source Employee Data)    │
└──────────────┬──────────────┘
               │
               │ On-Premises Data Gateway
               ▼
    ┌──────────────────────────┐
    │  Pipeline_IngestEmployees│
    │  (Initial Data Load)     │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │  Fabric SQL Database     │
    │  HRData                  │
    │  - Employees             │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │  Semantic Model          │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │  Power BI Report         │
    │  Employee Records        │
    │  Dashboard               │
    └──────────┬───────────────┘
               │ User Edits
               ▼
    ┌──────────────────────────┐
    │  EmployeeWritebackFunctions│
    │  (UDF - Fabric Function) │
    │  Updates Fabric SQL DB   │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │  Pipeline_Writeback_to_  │
    │  On-Prem                 │
    │  (Manual Trigger)        │
    └──────────┬───────────────┘
               │ On-Premises Data Gateway
               ▼
    ┌─────────────────────────┐
    │  On-Premises SQL Server │
    │  (Updated Employee Data)│
    └─────────────────────────┘
```

## 📦 Repository Contents

- **`artifacts/`** - Fabric artifact code and definitions
  - `udf/` - User-Defined Function Python code (`EmployeeWritebackFunctions.py`)
  - `pipelines/` - Pipeline JSON definitions
  - `workspace-manifest.json` - Complete artifact inventory
  
- **`scripts/`** - Essential SQL scripts
  - `01-table-creation.sql` - Database schema setup
  - `usp-update-employee-with-pipeline-trigger.sql` - Stored procedure for merges
  - `test-writeback.sql` - Validation script
  - Cleanup utilities

- **Documentation**
  - `README.md` - This file
  - `DEPLOYMENT_GUIDE.md` - Step-by-step deployment
  - `CUSTOMER_GUIDE.md` - Replication guide

## 🚀 Workspace Artifacts

### 1. SQL Database: **HRData**
- Central data store in Microsoft Fabric
- Tables: `Employees`

### 2. User-Defined Function: **EmployeeWritebackFunctions**
- Python functions callable from Power BI
- Three functions: `update_employee()`, `get_employee_info()`, `list_employees()`
- Calls stored procedures on Fabric SQL Database
- Returns formatted success/error messages

### 3. Pipelines
- **Pipeline_IngestEmployees** - Initial data load from on-prem via gateway
- **Pipeline_Writeback_to_On-Prem** - Syncs changes back via gateway

### 4. Semantic Model
- Connects to HRData SQL endpoint
- Powers the Power BI report

### 5. Report: **Employee Records Dashboard**
- Interactive Power BI report
- Edit buttons trigger UDF for writeback

## 🔑 Key Technologies

- **Microsoft Fabric** - Cloud data platform
- **Fabric SQL Database** - Cloud SQL storage
- **User-Defined Functions (UDF)** - RESTful writeback endpoint
- **Data Pipelines** - ETL orchestration
- **On-Premises Data Gateway** - Secure connectivity to on-prem SQL Server
- **Power BI** - Interactive reporting and writeback UI

## 🛠️ Prerequisites

- Microsoft Fabric capacity (F2 or higher)
- On-premises SQL Server
- On-premises data gateway installed and configured
- Power BI Premium or Premium Per User (PPU)

## 📚 Quick Links

- **Workspace ID**: `5720b110-927c-4145-a4a4-d214a30908f8`
- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Complete setup instructions
- [Customer Replication Guide](CUSTOMER_GUIDE.md) - How to replicate this solution

---

**Last Updated**: 2026-07-24

- [ ] Create writeback-enabled table (UDF)
- [ ] Build Power BI report with edit capability
- [ ] Test update functionality

### 🔙 Step 4: Pipeline 2 - Sync Back
- [ ] Create Pipeline "SyncBackEmployees"
- [ ] Configure merge logic (UPSERT based on EmployeeID)
- [ ] Schedule automated sync
- [ ] Test end-to-end workflow

---

## 🚀 Getting Started

### Documentation
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Complete step-by-step deployment instructions
- **[CUSTOMER_GUIDE.md](CUSTOMER_GUIDE.md)** - How to replicate this solution in your environment

### Scripts
- **[01-table-creation.sql](scripts/01-table-creation.sql)** - Complete database setup (tables + stored procedures)
- **[test-writeback.sql](scripts/test-writeback.sql)** - Test UDF and writeback flow

### Artifacts
- **[EmployeeWritebackFunctions.py](artifacts/udf/EmployeeWritebackFunctions.py)** - UDF code (3 functions)
- **[pipeline-definition.json](artifacts/pipelines/pipeline-definition.json)** - Pipeline configuration
- **[workspace-manifest.json](artifacts/workspace-manifest.json)** - Complete artifact inventory

