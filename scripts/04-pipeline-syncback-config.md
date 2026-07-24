# Pipeline 2: Sync Back to On-Prem (Fabric SQL DB → On-Prem SQL Server)

> **⚠️ Note**: This document has been superseded by [06-pipeline-syncback-implementation.md](06-pipeline-syncback-implementation.md) which includes more comprehensive instructions, error handling, scheduling, and troubleshooting.
> 
> **Please use the new guide**: [06-pipeline-syncback-implementation.md](06-pipeline-syncback-implementation.md)

---

## Objective
Copy updated records from Fabric SQL Database back to on-prem SQL Server using merge (UPSERT) logic based on EmployeeID.

---

## Step 1: Verify Prerequisites

Before creating Pipeline 2, ensure:

- ✅ Pipeline 1 is working (on-prem → Fabric SQL DB)
- ✅ Writeback is configured (users can update records in Fabric SQL DB)
- ✅ Stored procedure `usp_MergeEmployees` exists on on-prem SQL Server
- ✅ Both connections (`OnPremSQLServer` and `FabricSQLDB_HRData`) are working

---

## Step 2: Create Pipeline

1. In Fabric workspace: **Fabric Writeback Demo**
2. Click **+ New** → **Data Pipeline**
3. Name: `SyncBackEmployees`
4. Description: "Sync employee updates from Fabric SQL DB back to on-prem SQL Server"

---

## Step 3: Add Copy Activity with Merge Logic

### 3.1 Add Copy Activity

1. In pipeline canvas, add **Copy data** activity
2. Name: `SyncEmployeesToOnPrem`

### 3.2 Configure Source (Fabric SQL Database)

**Source Tab:**
- **Connection**: `FabricSQLDB_HRData`
- **Source type**: Query
- **Query**: 
  ```sql
  -- Only sync records modified in the last hour (adjust as needed)
  SELECT 
      EmployeeID,
      EmployeeName,
      LastModifiedDate,
      ModifiedBy
  FROM dbo.Employees
  WHERE LastModifiedDate >= DATEADD(HOUR, -1, GETDATE())
  ```

**Why query instead of table?**
- Performance: Only sync changed records
- Reduces load on on-prem server
- Avoids unnecessary network traffic

**Alternative (Full Refresh):**
If you want to sync all records every time:
```sql
SELECT 
    EmployeeID,
    EmployeeName,
    LastModifiedDate,
    ModifiedBy
FROM dbo.Employees
```

### 3.3 Configure Destination (On-Prem SQL Server)

**Destination Tab:**
- **Connection**: `OnPremSQLServer`
- **Destination type**: **Stored Procedure**
- **Stored procedure name**: `[dbo].[usp_MergeEmployees]`

**Parameter mapping:**
- Map source columns to stored procedure parameters:
  - EmployeeID → @EmployeeID
  - EmployeeName → @EmployeeName
  - ModifiedBy → @ModifiedBy

> **Note**: Using stored procedure ensures proper MERGE logic (update if exists, insert if new)

---

## Step 4: Add Pre-Copy Script (Optional - for Logging)

To track sync operations, add a logging step:

### 4.1 Add Script Activity (Before Copy)

1. Add **Script** activity before the Copy activity
2. Name: `LogSyncStart`
3. Configure:
   - **Connection**: `OnPremSQLServer`
   - **Script type**: NonQuery
   - **Script**:
   ```sql
   INSERT INTO dbo.SyncLog (SyncType, StartTime, Status)
   VALUES ('FabricToOnPrem', GETDATE(), 'Running');
   ```

### 4.2 Create SyncLog Table (on on-prem server)

Run this on **on-prem SQL Server**:
```sql
CREATE TABLE dbo.SyncLog (
    SyncLogID INT IDENTITY(1,1) PRIMARY KEY,
    SyncType NVARCHAR(50),
    StartTime DATETIME2,
    EndTime DATETIME2,
    RowsAffected INT,
    Status NVARCHAR(50),
    ErrorMessage NVARCHAR(MAX)
);
GO
```

### 4.3 Add Script Activity (After Copy)

1. Add **Script** activity after the Copy activity
2. Name: `LogSyncComplete`
3. Configure:
   ```sql
   UPDATE dbo.SyncLog
   SET EndTime = GETDATE(),
       RowsAffected = @{activity('SyncEmployeesToOnPrem').output.rowsCopied},
       Status = 'Success'
   WHERE SyncLogID = (SELECT MAX(SyncLogID) FROM dbo.SyncLog WHERE SyncType = 'FabricToOnPrem');
   ```

---

## Step 5: Add Error Handling

### 5.1 Configure Failure Path

1. Click on the Copy activity
2. Click the **...** → **Add failure output**
3. Add **Script** activity for error logging:
   ```sql
   UPDATE dbo.SyncLog
   SET EndTime = GETDATE(),
       Status = 'Failed',
       ErrorMessage = '@{activity('SyncEmployeesToOnPrem').error.message}'
   WHERE SyncLogID = (SELECT MAX(SyncLogID) FROM dbo.SyncLog WHERE SyncType = 'FabricToOnPrem');
   ```

### 5.2 Add Email Notification (Optional)

Add **Office 365 Outlook** activity to send email on failure.

---

## Step 6: Configure Schedule

### Option A: Scheduled Run (Recommended)

1. Click **Schedule** at top
2. Configure:
   - **Recurrence**: Every 30 minutes (or as needed)
   - **Start time**: Now
   - **Time zone**: Your timezone
3. **Save**

### Option B: Event-Driven Trigger

For real-time sync, create a trigger based on changes:

1. Click **Add trigger** → **Custom event**
2. Configure trigger on Fabric SQL DB changes (requires additional setup)

### Option C: Manual Run

Keep it manual and run on-demand when major updates occur.

---

## Step 7: Alternative - Direct MERGE in Copy Activity

If you prefer not to use stored procedure, use **Script** activity instead:

### 7.1 Remove Stored Procedure Destination

### 7.2 Add Script Activity

1. Add **Script** activity after Copy
2. Name: `MergeEmployees`
3. Configure:
   - **Connection**: `OnPremSQLServer`
   - **Script type**: NonQuery
   - **Script**:
   ```sql
   MERGE INTO dbo.Employees AS Target
   USING (
       SELECT 
           EmployeeID,
           EmployeeName,
           ModifiedBy
       FROM OPENROWSET(
           'SQLNCLI',
           'Server=<fabric-sql-endpoint>;Database=HRData;Trusted_Connection=yes;',
           'SELECT EmployeeID, EmployeeName, ModifiedBy 
            FROM dbo.Employees 
            WHERE LastModifiedDate >= DATEADD(HOUR, -1, GETDATE())'
       )
   ) AS Source
   ON Target.EmployeeID = Source.EmployeeID
   WHEN MATCHED THEN
       UPDATE SET 
           EmployeeName = Source.EmployeeName,
           LastModifiedDate = GETDATE(),
           ModifiedBy = Source.ModifiedBy
   WHEN NOT MATCHED THEN
       INSERT (EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy)
       VALUES (Source.EmployeeID, Source.EmployeeName, GETDATE(), Source.ModifiedBy);
   ```

> **Note**: This approach requires linked server or OPENROWSET, which may have security implications.

---

## Step 8: Test End-to-End Workflow

### Test Scenario:

1. **Update record in Fabric SQL DB**:
   ```sql
   -- Run in Fabric SQL Database (HRData)
   UPDATE dbo.Employees
   SET EmployeeName = 'Mo',
       ModifiedBy = 'TestUser',
       LastModifiedDate = GETDATE()
   WHERE EmployeeID = 2;
   ```

2. **Run Pipeline 2** (SyncBackEmployees):
   - Click **Run** in Fabric portal
   - Monitor execution

3. **Verify on on-prem**:
   ```sql
   -- Run on on-prem SQL Server
   SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
   -- Expected: EmployeeName = 'Mo'
   ```

4. **Check sync log**:
   ```sql
   SELECT * FROM dbo.SyncLog ORDER BY SyncLogID DESC;
   ```

---

## Step 9: Performance Tuning

### For Large Datasets:

1. **Batch Processing**:
   - Modify source query to process in batches:
   ```sql
   SELECT TOP 1000 * 
   FROM dbo.Employees 
   WHERE LastModifiedDate >= DATEADD(HOUR, -1, GETDATE())
   ORDER BY LastModifiedDate;
   ```

2. **Parallel Processing**:
   - Use ForEach activity to process multiple batches in parallel

3. **Index Optimization**:
   - Ensure indexes on EmployeeID and LastModifiedDate
   - On on-prem server, monitor execution plans

---

## Complete Pipeline Flow Diagram

```
┌──────────────────────┐
│  Start Pipeline      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Log Sync Start       │
│ (Script Activity)    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────┐
│ Copy Activity:                   │
│ Source: Fabric SQL DB            │
│ (modified records only)          │
│ Destination: On-Prem SQL Server  │
│ (via usp_MergeEmployees)         │
└──────────┬───────────────────────┘
           │
           ├─────────────┬─────────────┐
           │             │             │
        Success       Failure       Timeout
           │             │             │
           ▼             ▼             ▼
    ┌──────────┐  ┌──────────┐  ┌──────────┐
    │ Log      │  │ Log      │  │ Retry    │
    │ Success  │  │ Failure  │  │ Logic    │
    └──────────┘  └────┬─────┘  └──────────┘
                       │
                       ▼
                 ┌──────────┐
                 │ Send     │
                 │ Alert    │
                 └──────────┘
```

---

## Troubleshooting

### Common Issues:

1. **Merge conflicts**:
   - Check for concurrent updates
   - Implement optimistic concurrency control

2. **Permission errors**:
   - Ensure service account has EXECUTE permission on stored procedure
   - Grant necessary permissions on on-prem SQL Server

3. **Network timeouts**:
   - Increase timeout settings
   - Process in smaller batches

4. **Data type mismatches**:
   - Verify column types match between Fabric SQL DB and on-prem

---

## Monitoring & Maintenance

### Daily Checks:
- Monitor sync logs for failures
- Check row counts match between Fabric SQL DB and on-prem
- Review execution times

### Weekly Tasks:
- Archive old sync logs
- Review and optimize query performance
- Check for orphaned records

### Monthly Reviews:
- Analyze sync patterns
- Optimize batch sizes
- Review security and permissions

---

## Production Readiness Checklist

- [ ] Both pipelines tested end-to-end
- [ ] Error handling implemented
- [ ] Logging and monitoring configured
- [ ] Schedules optimized
- [ ] Performance tuned for your data volume
- [ ] Documentation updated
- [ ] Backup strategy in place
- [ ] Disaster recovery tested

---

## Summary

You now have a complete bidirectional sync solution:

1. **Pipeline 1**: On-prem → Fabric SQL DB (initial ingestion)
2. **Writeback**: Users update data in Fabric SQL DB
3. **Pipeline 2**: Fabric SQL DB → On-prem (merge updates)

This architecture ensures:
- Data consistency across environments
- Audit trail (LastModifiedDate, ModifiedBy)
- Controlled, scheduled synchronization
- Error handling and logging
