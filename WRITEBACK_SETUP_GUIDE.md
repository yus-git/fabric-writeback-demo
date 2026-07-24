# Quick Start Guide - Writeback Configuration

## Your Current Status
✅ Pipeline 1 complete (On-prem → Fabric SQL DB)  
✅ Data successfully ingested into Fabric SQL Database  
🔄 **Next**: Configure writeback + sync-back pipeline

---

## Implementation Order

### Phase 1: Test Writeback Mechanism ⚡ (5 minutes)

1. **Open Fabric SQL Database** (HRData)
2. **Click "New Query"** button
3. **Run the test script**:
   ```sql
   -- Test the stored procedure
   EXEC dbo.usp_UpdateEmployee 
       @EmployeeID = 2,
       @EmployeeName = 'Mo',
       @ModifiedBy = 'Test User';
   
   -- Verify
   SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
   ```
4. ✅ Confirm that "Mohammed" changed to "Mo"

📄 **Reference**: `scripts/test-writeback.sql`

---

### Phase 2: Set Up Power Automate Flow ⚡ (20 minutes)

1. **Go to [Power Automate](https://make.powerautomate.com)**
2. **Create Instant Cloud Flow**:
   - Name: `UpdateEmployeeFromPowerBI`
   - Trigger: Power BI button
3. **Add inputs**: EmployeeID (Number), EmployeeName (Text)
4. **Add action**: SQL Server → Execute stored procedure
   - Server: Your Fabric SQL endpoint (get from Fabric portal)
   - Database: HRData
   - Procedure: `[dbo].[usp_UpdateEmployee]`
5. **Save and test** the flow

📄 **Detailed Guide**: `scripts/05-power-automate-writeback-setup.md`

---

### Phase 3: Create Power BI Report ⚡ (15 minutes)

**Option A: Power BI Desktop**
1. Connect to Fabric SQL Database (DirectQuery mode)
2. Create table visual with Employees data
3. Add button → Link to Power Automate flow
4. Publish to Fabric workspace

**Option B: Power BI Service**
1. Create semantic model in Fabric
2. Build report with edit capability
3. Add Power Automate button

📄 **Detailed Guide**: `scripts/05-power-automate-writeback-setup.md` (Step 2)

---

### Phase 4: Create Sync-Back Pipeline ⚡ (20 minutes)

1. **Verify on-prem stored procedure exists**: `usp_MergeEmployees`
   - If not, create it (see guide)
2. **In Fabric workspace**:
   - New → Data Pipeline → `SyncBackEmployees`
3. **Add Copy Activity**:
   - **Source**: Fabric SQL Database (HRData)
     - Query: Select modified records
   - **Destination**: On-prem SQL Server
     - Use stored procedure: `usp_MergeEmployees`
4. **Schedule trigger**: Every 5-15 minutes
5. **Test the pipeline**

📄 **Detailed Guide**: `scripts/06-pipeline-syncback-implementation.md`

---

## End-to-End Test Workflow

Once everything is configured, test the complete flow:

1. **Update in Power BI**:
   - Select employee (e.g., Sarah, ID=3)
   - Change name to "Sarah Johnson"
   - Click "Update Employee" button
   - ✅ Flow executes successfully

2. **Verify in Fabric SQL Database** (immediate):
   ```sql
   SELECT * FROM dbo.Employees WHERE EmployeeID = 3;
   -- Expected: EmployeeName = 'Sarah Johnson'
   ```

3. **Wait for scheduled pipeline** (5-15 minutes)

4. **Verify in On-Prem SQL Server**:
   ```sql
   SELECT * FROM dbo.Employees WHERE EmployeeID = 3;
   -- Expected: EmployeeName = 'Sarah Johnson'
   ```

✅ **Success**: Changes flow from Power BI → Fabric → On-Prem!

---

## Architecture Summary

```
┌─────────────────────┐
│  On-Prem SQL Server │
│    (Source)         │
└──────────┬──────────┘
           │ Pipeline 1: Ingest (hourly/scheduled)
           ▼
┌──────────────────────┐
│ Fabric SQL Database  │ ◄── Power Automate Flow ◄── Power BI Button
│       (HRData)       │     (User clicks to update)
└──────────┬───────────┘
           │ Pipeline 2: Sync Back (every 5-15 min)
           ▼
┌─────────────────────┐
│  On-Prem SQL Server │
│    (Updated)        │
└─────────────────────┘
```

---

## Quick Links to Documentation

| Phase | Guide | Time |
|-------|-------|------|
| Test stored procedure | `test-writeback.sql` | 5 min |
| Power Automate setup | `05-power-automate-writeback-setup.md` | 20 min |
| Power BI report | `05-power-automate-writeback-setup.md` (Step 2) | 15 min |
| Sync-back pipeline | `06-pipeline-syncback-implementation.md` | 20 min |

---

## Common Issues & Solutions

### Issue: Can't find "Edit data" button in Fabric portal
**Solution**: Fabric SQL Database doesn't have direct grid editing. Use:
- Query Editor for testing (New Query button)
- Power Automate + Power BI for user writeback

### Issue: Power Automate flow fails
**Solution**: 
- Verify SQL connection uses correct Fabric endpoint
- Check stored procedure exists and has EXECUTE permission
- Test stored procedure manually first

### Issue: Pipeline 2 doesn't sync
**Solution**:
- Check on-prem data gateway is running
- Verify `usp_MergeEmployees` exists on on-prem
- Increase time window in source query (use last 24 hours for testing)

### Issue: Changes take too long to sync
**Solution**:
- Reduce schedule frequency (e.g., every 5 minutes instead of hourly)
- Consider real-time sync with Azure Functions (advanced)

---

## Next Step: Start Here 👇

Begin with **Phase 1** - test the stored procedure to verify the foundation is working, then proceed to Power Automate setup.

Need help? Open the detailed guide for each phase.
