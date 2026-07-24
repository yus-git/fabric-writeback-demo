# 📋 Demo Setup Checklist

Use this checklist to track your progress through the writeback demo setup.

---

## ✅ Prerequisites

- [ ] Fabric workspace created: **"Fabric Writeback Demo"**
- [ ] Fabric SQL Database created: **"HRData"**
- [ ] Access to on-prem SQL Server (or Azure SQL DB for testing)
- [ ] Fabric Contributor or Admin permissions
- [ ] Signed in to Fabric in VS Code

---

## 📊 Step 1: Database Setup

### On-Prem SQL Server
- [ ] Database created: `HRSystem`
- [ ] Table created: `dbo.Employees`
- [ ] Index created: `IX_Employees_LastModifiedDate`
- [ ] Sample data inserted (5 records)
- [ ] Stored procedure created: `usp_MergeEmployees`
- [ ] **Validation**: `SELECT * FROM dbo.Employees` returns 5 rows

### Fabric SQL Database
- [ ] Table created: `dbo.Employees`
- [ ] Index created: `IX_Employees_LastModifiedDate`
- [ ] Stored procedure created: `usp_UpdateEmployee`
- [ ] **Validation**: Table appears in Fabric portal Data tab

---

## 🔌 Step 2: Connections

- [ ] Connection created: `OnPremSQLServer`
  - Server: ___________________________
  - Database: `HRSystem`
  - Authentication: SQL / Windows
  - **Test passed**: ✅
  
- [ ] Connection created: `FabricSQLDB_HRData`
  - Workspace: `Fabric Writeback Demo`
  - SQL Database: `HRData`
  - **Test passed**: ✅

---

## 🔄 Step 3: Pipeline 1 - Ingest (On-Prem → Fabric)

- [ ] Pipeline created: `Pipeline_IngestEmployees`
- [ ] Copy activity added: `CopyEmployeesToFabric`
- [ ] Source configured:
  - Connection: `OnPremSQLServer`
  - Table: `dbo.Employees`
- [ ] Destination configured:
  - Connection: `FabricSQLDB_HRData`
  - Table: `dbo.Employees`
  - Write method: **Upsert**
  - Key column: `EmployeeID`
- [ ] **First run completed**: ✅
  - Status: Succeeded
  - Rows copied: **5**
- [ ] **Validation in Fabric SQL DB**: `SELECT COUNT(*) FROM dbo.Employees` returns 5

---

## 📝 Step 4: Writeback Test

- [ ] Updated Employee ID 2 from "Mohammed" to "Mo"
  - Method used: ___________________________
  - (Direct edit / SQL query / Power Automate)
- [ ] **Validation**: `SELECT * FROM dbo.Employees WHERE EmployeeID = 2` shows "Mo"
- [ ] Verified `LastModifiedDate` updated: ✅
- [ ] Verified `ModifiedBy` populated: ✅

---

## 🔙 Step 5: Pipeline 2 - Sync Back (Fabric → On-Prem)

- [ ] Pipeline created: `Pipeline_SyncBackEmployees`
- [ ] Copy activity added: `SyncUpdatesToOnPrem`
- [ ] Source configured:
  - Connection: `FabricSQLDB_HRData`
  - Query with filter: LastModifiedDate >= DATEADD(HOUR, -24, GETDATE())
- [ ] Destination configured:
  - Connection: `OnPremSQLServer`
  - Write method: **Stored procedure**
  - Stored procedure: `usp_MergeEmployees`
  - Parameters mapped correctly
- [ ] **First run completed**: ✅
  - Status: Succeeded
  - Rows processed: ______
- [ ] **Validation on On-Prem**: `SELECT * FROM dbo.Employees WHERE EmployeeID = 2` shows "Mo"

---

## ⏰ Step 6: Scheduling

### Pipeline 1 Schedule
- [ ] Schedule enabled: ✅
- [ ] Frequency: Every ______ hour(s)
- [ ] Start time: ___________________________
- [ ] Time zone: ___________________________

### Pipeline 2 Schedule
- [ ] Schedule enabled: ✅
- [ ] Frequency: Every ______ minutes
- [ ] Start time: ___________________________
- [ ] Time zone: ___________________________

---

## 🧪 Step 7: End-to-End Testing

### Test 1: On-Prem → Fabric
- [ ] Updated record on on-prem: Employee ID _____, changed to: _______________
- [ ] Pipeline 1 ran (manual or scheduled): ✅
- [ ] Change reflected in Fabric SQL DB: ✅
- [ ] Timestamp: ___________________________

### Test 2: Fabric → On-Prem
- [ ] Updated record in Fabric: Employee ID _____, changed to: _______________
- [ ] Pipeline 2 ran (manual or scheduled): ✅
- [ ] Change reflected on on-prem: ✅
- [ ] Timestamp: ___________________________

### Test 3: Conflict Resolution
- [ ] Updated same record in both systems
- [ ] Pipeline behavior: ___________________________
- [ ] Result: ___________________________

---

## 🎯 Optional Enhancements

- [ ] **Power BI Report with Writeback**
  - [ ] Semantic model created: `EmployeeModel`
  - [ ] Report created with table visual
  - [ ] Power Automate flow configured
  - [ ] Writeback tested from report

- [ ] **Monitoring & Alerts**
  - [ ] Email notification for pipeline failures
  - [ ] Dashboard showing sync metrics
  - [ ] Logging table created

- [ ] **OPDG Migration**
  - [ ] On-Premises Data Gateway installed
  - [ ] Gateway registered: ___________________________
  - [ ] Connections updated to use gateway
  - [ ] End-to-end test passed with OPDG

- [ ] **Additional Tables**
  - [ ] Departments table added
  - [ ] Projects table added
  - [ ] Relationships configured

---

## 📊 Performance Metrics

Record your baseline performance:

### Pipeline 1 (Ingest)
- [ ] Average duration: _______ seconds
- [ ] Average rows processed: _______
- [ ] Failures in last 7 days: _______

### Pipeline 2 (Sync Back)
- [ ] Average duration: _______ seconds
- [ ] Average rows processed: _______
- [ ] Failures in last 7 days: _______

---

## 🐛 Issues Encountered

Track any issues you faced and how you resolved them:

| Issue | Date | Resolution | Time to Resolve |
|-------|------|------------|----------------|
| | | | |
| | | | |
| | | | |

---

## 📝 Notes

Additional notes, learnings, or customizations:

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

---

## ✅ Demo Complete!

- [ ] All steps completed successfully
- [ ] Documentation reviewed
- [ ] Team trained on the solution
- [ ] Production readiness assessment completed
- [ ] Handoff documentation prepared

**Date completed**: ___________________________

**Completed by**: ___________________________

**Next review date**: ___________________________

---

## 📚 Reference

- **Main Guide**: AUTOMATED_DEMO_SETUP.md
- **Quick Start**: QUICK_START.md
- **OPDG Migration**: OPDG_MIGRATION_GUIDE.md
- **SQL Scripts**: scripts/01-table-creation.sql
- **Pipeline Guides**: scripts/02-pipeline-ingest-config.md, scripts/04-pipeline-syncback-config.md
