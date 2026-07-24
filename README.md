# Fabric SQL Database Writeback Solution

> **Complete Microsoft Fabric solution demonstrating Power BI writeback functionality using User-Defined Functions (UDF), Data Pipelines, and SQL Database.**

[![Fabric](https://img.shields.io/badge/Microsoft-Fabric-blue)](https://fabric.microsoft.com)
[![Power BI](https://img.shields.io/badge/Power-BI-yellow)](https://powerbi.microsoft.com)

## 📦 Repository Contents

- **`artifacts/`** - Exported Fabric artifact definitions (UDF, pipelines, SQL schemas)
- **`scripts/`** - SQL scripts, PowerShell helpers, and configuration guides
- **`docs/`** - Additional documentation
- **Deployment guides** - Step-by-step setup instructions

## 🎯 Use Case

This solution enables **bidirectional data flow** between Power BI reports and on-premises SQL databases:
1. Users view and edit employee data in Power BI
2. Changes are captured via User-Defined Function (UDF)
3. Data pipelines sync changes back to on-premises systems
4. All changes are tracked and auditable

## Architecture Overview

```
┌─────────────────────┐
│  On-Prem SQL Server │
│  (Employees Table)  │
└──────────┬──────────┘
           │
           ▼
    ┌──────────────────────┐
    │ Pipeline 1: Ingest   │
    │ (Copy Activity)      │
    └──────────┬───────────┘
               │
               ▼
    ┌──────────────────────┐
    │ Fabric SQL Database  │
    │ HRData.Employees     │
    └──────────┬───────────┘
               │
               ▼
    ┌──────────────────────┐
    │ Semantic Model       │
    │ + Power BI Report    │
    │ (with Writeback UDF) │
    └──────────┬───────────┘
               │
               ▼
    ┌──────────────────────┐
    │ Pipeline 2: Sync Back│
    │ (Merge Activity)     │
    └──────────┬───────────┘
               │
               ▼
    ┌─────────────────────┐
    │  On-Prem SQL Server │
    │  (Merged Updates)   │
    └─────────────────────┘
```

## Workspace Information
- **Workspace Name**: Fabric Writeback Demo
- **SQL Database Name**: HRData
- **Connection Method**: Direct connection (public IP/VPN)

## Implementation Checklist

### ✅ Prerequisites
- [ ] On-prem SQL Server accessible (direct connection)
- [ ] Fabric SQL Database "HRData" created in workspace "Fabric Writeback Demo"
- [ ] Permissions: SQL Server admin, Fabric workspace admin

### 📋 Step 1: Set Up Tables
- [ ] Create Employees table in on-prem SQL Server
- [ ] Create Employees table in Fabric SQL Database
- [ ] Insert sample data

### 🔄 Step 2: Pipeline 1 - Initial Ingestion
- [ ] Create connection to on-prem SQL Server
- [ ] Create Pipeline "IngestEmployees"
- [ ] Configure Copy Activity
- [ ] Test and validate data transfer

### 📊 Step 3: Semantic Model & Report
- [ ] Create semantic model pointing to Fabric SQL DB
- [ ] Create writeback-enabled table (UDF)
- [ ] Build Power BI report with edit capability
- [ ] Test update functionality

### 🔙 Step 4: Pipeline 2 - Sync Back
- [ ] Create Pipeline "SyncBackEmployees"
- [ ] Configure merge logic (UPSERT based on EmployeeID)
- [ ] Schedule automated sync
- [ ] Test end-to-end workflow

---

## Next Steps

### 🚀 Quick Start
See **[WRITEBACK_SETUP_GUIDE.md](WRITEBACK_SETUP_GUIDE.md)** for step-by-step implementation

### 📚 Detailed Documentation

1. ✅ **[01-table-creation.sql](scripts/01-table-creation.sql)** - Create tables in both environments
2. ✅ **[02-pipeline-ingest-config.md](scripts/02-pipeline-ingest-config.md)** - Configure ingestion pipeline
3. 🔄 **[03-semantic-model-setup.md](scripts/03-semantic-model-setup.md)** - Semantic model overview
4. 🔄 **[05-power-automate-writeback-setup.md](scripts/05-power-automate-writeback-setup.md)** - Power Automate flow + Power BI report
5. 🔄 **[06-pipeline-syncback-implementation.md](scripts/06-pipeline-syncback-implementation.md)** - Sync-back pipeline to on-prem
6. ⚡ **[test-writeback.sql](scripts/test-writeback.sql)** - Test writeback stored procedure

