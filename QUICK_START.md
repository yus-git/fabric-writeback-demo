# Quick Start Guide - Fabric SQL Database Writeback Solution

## 🚀 Getting Started

You've already completed:
- ✅ Created Fabric SQL Database "HRData"
- ✅ Prepared SQL query/schema

Follow these steps in order:

---

## 📋 Step-by-Step Implementation (30-60 minutes)

### Step 1: Set Up Tables (10 minutes)
📄 **File**: `scripts/01-table-creation.sql`

**Actions:**
1. Open SQL Server Management Studio (SSMS) or Azure Data Studio
2. Connect to your **on-prem SQL Server**
3. Run Part A of the script (creates Employees table + sample data)
4. Connect to **Fabric SQL Database (HRData)**
   - Option 1: Use Fabric portal → SQL Query Editor
   - Option 2: Use Azure Data Studio with connection string from Fabric portal
5. Run Part B of the script (creates Employees table in Fabric)
6. Run Part C (creates merge stored procedure on on-prem)
7. Run Part D (creates writeback stored procedure in Fabric SQL DB)

**Validation:**
```sql
-- On both servers, verify:
SELECT * FROM dbo.Employees;
-- Should see 5 sample employees
```

---

### Step 2: Create Pipeline 1 - Ingest Data (15 minutes)
📄 **File**: `scripts/02-pipeline-ingest-config.md`

**Actions:**
1. In Fabric portal, go to workspace **Fabric Writeback Demo**
2. Create connection to on-prem SQL Server
   - Connection name: `OnPremSQLServer`
   - Server: [your server IP/hostname]
   - Database: HRSystem (or your DB name)
   - Authentication: SQL or Windows Auth
3. Create connection to Fabric SQL Database
   - Connection name: `FabricSQLDB_HRData`
4. Create Pipeline: `IngestEmployees`
5. Add Copy activity:
   - Source: OnPremSQLServer → dbo.Employees
   - Destination: FabricSQLDB_HRData → dbo.Employees
   - Write behavior: **Upsert** on EmployeeID
6. **Run pipeline** and verify data copied

**Validation:**
```sql
-- In Fabric SQL DB, check:
SELECT COUNT(*) FROM dbo.Employees;
-- Should show 5 records
```

---

### Step 3: Set Up Writeback (20 minutes)
📄 **File**: `scripts/03-semantic-model-setup.md`

**Choose your approach** (ranked by ease):

#### 🥇 **Easiest**: Direct Edit in Fabric Portal
1. Go to Fabric SQL Database (HRData) → **Data** tab
2. Select `dbo.Employees`
3. Click **Edit data**
4. Update "Mohammed" to "Mo"
5. Click **Save**

#### 🥈 **Recommended for Production**: Power Automate + Power BI
1. Create Power Automate flow: `UpdateEmployeeFromPowerBI`
2. Configure trigger: Power BI button
3. Add action: Execute stored procedure `usp_UpdateEmployee`
4. In Power BI Desktop:
   - Connect to Fabric SQL DB
   - Create table visual
   - Add button linked to Power Automate flow

#### 🥉 **Advanced**: Power Apps Embedded in Power BI
- Full custom forms for data entry
- More complex but most flexible

**Validation:**
```sql
-- After updating, verify in Fabric SQL DB:
SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
-- EmployeeName should be 'Mo'
```

---

### Step 4: Create Pipeline 2 - Sync Back (15 minutes)
📄 **File**: `scripts/04-pipeline-syncback-config.md`

**Actions:**
1. Create Pipeline: `SyncBackEmployees`
2. Add Copy activity:
   - Source: FabricSQLDB_HRData (query for modified records)
   - Destination: OnPremSQLServer (stored procedure `usp_MergeEmployees`)
3. Configure schedule: Every 30 minutes (or as needed)
4. Add error handling (optional but recommended)

**Validation:**
```sql
-- After running Pipeline 2, check on-prem:
SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
-- EmployeeName should now be 'Mo'
```

---

## 🎯 End-to-End Test

### Complete Workflow Test:

1. **Update in Fabric SQL DB**:
   ```sql
   UPDATE dbo.Employees
   SET EmployeeName = 'Sarah J.',
       ModifiedBy = 'TestUser'
   WHERE EmployeeID = 3;
   ```

2. **Verify in Fabric**:
   ```sql
   SELECT * FROM dbo.Employees WHERE EmployeeID = 3;
   ```

3. **Run Pipeline 2** (SyncBackEmployees)

4. **Verify on On-Prem**:
   ```sql
   SELECT * FROM dbo.Employees WHERE EmployeeID = 3;
   -- Should show 'Sarah J.'
   ```

✅ **Success!** Your bidirectional sync is working!

---

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     On-Prem SQL Server                          │
│                     (HRSystem.Employees)                        │
│                                                                 │
│  EmployeeID | EmployeeName | LastModifiedDate | ModifiedBy    │
│  ────────────────────────────────────────────────────────────  │
│      1      |    Yusra     |   2026-07-15     |   System      │
│      2      |   Mohammed   |   2026-07-15     |   System      │
└─────────────────┬───────────────────────────────────────┬───────┘
                  │                                       │
                  │ Pipeline 1: Ingest                   │ Pipeline 2: Sync Back
                  │ (Copy Activity)                       │ (Merge via Stored Proc)
                  │ Frequency: Hourly                     │ Frequency: Every 30 min
                  ▼                                       ▲
┌─────────────────────────────────────────────────────────────────┐
│                  Fabric SQL Database (HRData)                   │
│                     (dbo.Employees)                             │
│                                                                 │
│  EmployeeID | EmployeeName | LastModifiedDate | ModifiedBy    │
│  ────────────────────────────────────────────────────────────  │
│      1      |    Yusra     |   2026-07-15     |   System      │
│      2      |      Mo      |   2026-07-15     |   Yusra       │ ← Updated!
└─────────────────────────────────────────────────────────────────┘
                  │
                  │ DirectQuery / Direct Lake
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Semantic Model                               │
│                   (EmployeeModel)                               │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Power BI Report                              │
│  ┌───────────────────────────────────────────────┐             │
│  │  Employee List                                │             │
│  │  ─────────────────────────────────────────────│             │
│  │  ID  | Name          | Last Modified         │             │
│  │  1   | Yusra         | 2026-07-15            │             │
│  │  2   | Mo ✏️         | 2026-07-15 ← Edited!  │             │
│  │  3   | Sarah Johnson | 2026-07-15            │             │
│  └───────────────────────────────────────────────┘             │
│           [Update Employee] Button                              │
│           (Triggers Power Automate Flow)                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Configuration Summary

| Component | Name | Purpose |
|-----------|------|---------|
| **On-Prem DB** | HRSystem | Source system |
| **Fabric SQL DB** | HRData | Central hub for updates |
| **Connection 1** | OnPremSQLServer | Connect to on-prem |
| **Connection 2** | FabricSQLDB_HRData | Connect to Fabric SQL DB |
| **Pipeline 1** | IngestEmployees | On-prem → Fabric |
| **Pipeline 2** | SyncBackEmployees | Fabric → On-prem |
| **Stored Proc 1** | usp_UpdateEmployee | Writeback in Fabric |
| **Stored Proc 2** | usp_MergeEmployees | Merge on on-prem |
| **Semantic Model** | EmployeeModel | Power BI data model |

---

## 🔧 Troubleshooting

### Issue: Can't connect to on-prem SQL Server
**Solutions:**
- Verify SQL Server allows remote connections
- Check firewall rules (port 1433)
- Enable TCP/IP in SQL Server Configuration Manager
- Test with: `telnet [server-ip] 1433`

### Issue: Pipeline fails with "Authentication failed"
**Solutions:**
- Verify SQL credentials
- Check SQL Server authentication mode (mixed mode)
- Test connection in SSMS first

### Issue: Merge not working (duplicates or missing records)
**Solutions:**
- Verify EmployeeID is PRIMARY KEY in both databases
- Check stored procedure logic
- Review Copy activity mapping

### Issue: Changes in Fabric not syncing back
**Solutions:**
- Check Pipeline 2 schedule
- Verify LastModifiedDate is being updated
- Check Pipeline 2 source query (time window)

---

## 📚 Additional Resources

- **Fabric SQL Database Docs**: https://learn.microsoft.com/fabric/database/sql/overview
- **Data Pipelines Docs**: https://learn.microsoft.com/fabric/data-factory/
- **Power BI Writeback**: https://learn.microsoft.com/power-bi/create-reports/service-report-writeback

---

## 🎓 What You've Learned

- ✅ Connect on-prem SQL Server to Microsoft Fabric
- ✅ Create bidirectional data sync workflows
- ✅ Implement merge (UPSERT) logic with stored procedures
- ✅ Build reports with writeback capability
- ✅ Schedule automated data synchronization
- ✅ Track changes with audit columns

---

## 🚀 Next Steps

Want to enhance your solution?

1. **Add more tables**: Apply the same pattern to other tables
2. **Implement change tracking**: Use SQL Server Change Tracking for efficiency
3. **Add data validation**: Create validation rules in Fabric SQL DB
4. **Build dashboards**: Create executive dashboards showing data flow metrics
5. **Set up alerts**: Configure alerts for sync failures
6. **Scale to OPDG**: Migrate from direct connection to On-Premises Data Gateway for better security

---

## 💬 Need Help?

If you get stuck:
1. Check the detailed guides in the `scripts/` folder
2. Review troubleshooting section above
3. Test each component individually
4. Verify connections and permissions

**You've got this!** 🎉
