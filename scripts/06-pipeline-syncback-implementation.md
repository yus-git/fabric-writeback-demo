# Pipeline 2: Sync Back to On-Prem SQL Server

## Overview
This pipeline copies updated records from Fabric SQL Database back to on-prem SQL Server, completing the bi-directional sync workflow.

---

## Architecture Flow

```
Fabric SQL Database (HRData)
        ↓
Query: SELECT modified records
        ↓
Copy Activity
        ↓
On-Prem SQL Server → usp_MergeEmployees
        ↓
MERGE into Employees table
```

---

## Prerequisites Checklist

Before creating this pipeline, verify:

- ✅ Pipeline 1 (IngestEmployees) is working
- ✅ Power Automate writeback is configured and tested
- ✅ At least one record has been modified in Fabric SQL Database
- ✅ Connection to on-prem SQL Server exists
- ✅ Stored procedure `usp_MergeEmployees` exists on on-prem

---

## Step 1: Verify On-Prem Stored Procedure

### 1.1 Check if Merge Procedure Exists

Connect to your on-prem SQL Server and run:

```sql
-- Check if stored procedure exists
SELECT name, create_date, modify_date
FROM sys.objects 
WHERE type = 'P' AND name = 'usp_MergeEmployees';
```

### 1.2 Create Merge Procedure (if not exists)

If the stored procedure doesn't exist, create it:

```sql
CREATE PROCEDURE dbo.usp_MergeEmployees
    @EmployeeID INT,
    @EmployeeName NVARCHAR(100),
    @ModifiedBy NVARCHAR(100),
    @LastModifiedDate DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    
    -- MERGE logic: Update if exists, Insert if new
    MERGE INTO dbo.Employees AS Target
    USING (
        SELECT 
            @EmployeeID AS EmployeeID,
            @EmployeeName AS EmployeeName,
            @LastModifiedDate AS LastModifiedDate,
            @ModifiedBy AS ModifiedBy
    ) AS Source
    ON Target.EmployeeID = Source.EmployeeID
    
    -- When matched, update
    WHEN MATCHED THEN
        UPDATE SET
            Target.EmployeeName = Source.EmployeeName,
            Target.LastModifiedDate = Source.LastModifiedDate,
            Target.ModifiedBy = Source.ModifiedBy
    
    -- When not matched (new employee from Fabric), insert
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy)
        VALUES (Source.EmployeeID, Source.EmployeeName, Source.LastModifiedDate, Source.ModifiedBy);
    
    PRINT 'Employee ' + CAST(@EmployeeID AS VARCHAR) + ' merged successfully.';
END;
GO

-- Grant execute permission
GRANT EXECUTE ON dbo.usp_MergeEmployees TO [your_pipeline_user];
```

### 1.3 Test the Merge Procedure

```sql
-- Test merge with sample data
EXEC dbo.usp_MergeEmployees
    @EmployeeID = 2,
    @EmployeeName = 'Mo (Synced from Fabric)',
    @ModifiedBy = 'Fabric Pipeline',
    @LastModifiedDate = GETDATE();

-- Verify
SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
```

---

## Step 2: Create Sync-Back Pipeline in Fabric

### 2.1 Navigate to Workspace

1. Go to Fabric portal
2. Navigate to workspace: **Fabric Writeback Demo**
3. Click **+ New** → **Data pipeline**
4. Name: `SyncBackEmployees`
5. Description: "Sync employee updates from Fabric SQL DB back to on-prem SQL Server"

### 2.2 Add Copy Activity

1. In pipeline canvas, search for **Copy data** in activities
2. Drag **Copy data** to canvas
3. Name the activity: `CopyUpdatedEmployees`

---

## Step 3: Configure Source (Fabric SQL Database)

### 3.1 Source Settings

1. Click on the **Copy data** activity
2. Go to **Source** tab
3. Configure:
   - **Data store type**: Workspace
   - **Workspace data store type**: SQL database in Fabric
   - **SQL database**: Select `HRData`

### 3.2 Source Query

**Option A: Incremental Sync (Recommended)**

Only sync records modified in the last hour:

```sql
SELECT 
    EmployeeID,
    EmployeeName,
    LastModifiedDate,
    ModifiedBy
FROM dbo.Employees
WHERE LastModifiedDate >= DATEADD(HOUR, -1, GETDATE())
ORDER BY LastModifiedDate DESC
```

**Why this approach?**
- Reduces network traffic
- Only syncs what changed
- Faster execution
- Less load on on-prem server

**Option B: Full Refresh**

Sync all records every time:

```sql
SELECT 
    EmployeeID,
    EmployeeName,
    LastModifiedDate,
    ModifiedBy
FROM dbo.Employees
ORDER BY EmployeeID
```

**Choose Option A for production**, Option B for testing or if you have few records.

### 3.3 Configure Source Settings

1. **Use query**: Select **Query**
2. **Query**: Paste the query from Option A (recommended)
3. Click **Preview data** to test

---

## Step 4: Configure Destination (On-Prem SQL Server)

### 4.1 Destination Settings

1. Go to **Destination** tab
2. Configure:
   - **Data store type**: External
   - **Connection**: Select your on-prem SQL Server connection (e.g., `OnPremSQLServer`)
   - If connection doesn't exist, create it:
     - Click **+ New connection**
     - Connection type: **SQL Server**
     - Server: Your on-prem SQL Server address
     - Database: Your database name
     - Authentication: Windows or SQL authentication
     - Test connection

### 4.2 Use Stored Procedure

**Important**: To ensure proper MERGE logic, use the stored procedure:

1. **Destination type**: **Stored procedure**
2. **Stored procedure name**: `[dbo].[usp_MergeEmployees]`

### 4.3 Map Parameters

The stored procedure expects these parameters:
- `@EmployeeID`
- `@EmployeeName`
- `@ModifiedBy`
- `@LastModifiedDate`

**Parameter mapping** (should auto-map, verify):
- Source column `EmployeeID` → Parameter `@EmployeeID`
- Source column `EmployeeName` → Parameter `@EmployeeName`
- Source column `ModifiedBy` → Parameter `@ModifiedBy`
- Source column `LastModifiedDate` → Parameter `@LastModifiedDate`

---

## Step 5: Add Error Handling (Optional but Recommended)

### 5.1 Add Variables for Logging

1. In pipeline canvas, click on empty space
2. Go to **Variables** tab
3. Add variables:

**Variable 1:**
- Name: `SyncStartTime`
- Type: String
- Default value: (leave empty)

**Variable 2:**
- Name: `SyncStatus`
- Type: String
- Default value: `Running`

### 5.2 Add Set Variable Activity (Start)

1. Add **Set variable** activity before Copy activity
2. Connect with success path (green)
3. Configure:
   - Name: `SetStartTime`
   - Variable name: `SyncStartTime`
   - Value: `@utcnow()`

### 5.3 Add Set Variable Activity (Success)

1. Add **Set variable** activity after Copy activity
2. Connect from Copy activity success path (green)
3. Configure:
   - Name: `SetSuccessStatus`
   - Variable name: `SyncStatus`
   - Value: `Success`

### 5.4 Add Set Variable Activity (Failure)

1. Add **Set variable** activity
2. Connect from Copy activity **failure path** (red)
3. Configure:
   - Name: `SetFailureStatus`
   - Variable name: `SyncStatus`
   - Value: `Failed`

---

## Step 6: Add Notification (Optional)

### 6.1 Send Email on Failure

1. Add **Office 365 Outlook** activity
2. Connect from failure path
3. Configure:
   - **To**: Your email
   - **Subject**: `Pipeline Failed: SyncBackEmployees`
   - **Body**: 
   ```
   Pipeline execution failed at @{utcnow()}
   
   Please check Fabric portal for details.
   ```

---

## Step 7: Configure Pipeline Settings

### 7.1 Pipeline Parameters (for flexibility)

1. Click on empty space in pipeline canvas
2. Go to **Parameters** tab
3. Add parameter:

**Parameter:**
- Name: `SyncWindowHours`
- Type: Int
- Default value: `1`

### 7.2 Update Source Query to Use Parameter

Modify the source query to use the parameter:

```sql
SELECT 
    EmployeeID,
    EmployeeName,
    LastModifiedDate,
    ModifiedBy
FROM dbo.Employees
WHERE LastModifiedDate >= DATEADD(HOUR, -@{pipeline().parameters.SyncWindowHours}, GETDATE())
ORDER BY LastModifiedDate DESC
```

This allows you to adjust the sync window without editing the pipeline.

---

## Step 8: Test the Pipeline

### 8.1 Manual Test Run

1. Click **Run** (top ribbon)
2. If you added parameters, enter values:
   - `SyncWindowHours`: `24` (to catch all test changes)
3. Click **OK**
4. Monitor execution in **Output** tab

### 8.2 Verify Results

**In Fabric SQL Database:**
```sql
-- Check what was sent
SELECT * FROM dbo.Employees 
WHERE LastModifiedDate >= DATEADD(HOUR, -24, GETDATE())
ORDER BY LastModifiedDate DESC;
```

**In On-Prem SQL Server:**
```sql
-- Check what was received
SELECT * FROM dbo.Employees 
WHERE EmployeeID = 2;
-- Should show: EmployeeName = 'Mo' (or whatever you changed it to)
```

---

## Step 9: Schedule the Pipeline

### 9.1 Create Schedule Trigger

1. In pipeline, click **Settings** (top ribbon)
2. Click **Triggers** → **+ New trigger**
3. Choose **Schedule**

### 9.2 Configure Schedule

**For near-real-time sync (recommended):**
- **Name**: `SyncEvery5Minutes`
- **Recurrence**: Recurring
- **Repeat every**: `5` minutes
- **Start time**: Now
- **End**: No end

**For less frequent sync:**
- **Recurrence**: Recurring
- **Repeat every**: `1` hour
- Or use **Daily** at specific times

**For testing:**
- **Repeat every**: `15` minutes

### 9.3 Activate Trigger

1. Click **Save**
2. Toggle trigger to **Active**
3. Click **OK**

---

## Step 10: Monitor and Validate

### 10.1 Monitor Pipeline Runs

1. In Fabric portal, go to workspace
2. Click on `SyncBackEmployees` pipeline
3. View **Run history** tab
4. Check for:
   - ✅ Success status
   - Duration
   - Rows copied

### 10.2 End-to-End Test

**Complete workflow test:**

1. **Update in Power BI**:
   - Open Power BI report
   - Select EmployeeID = 3 (Sarah)
   - Change name to "Sarah Johnson"
   - Click Update button

2. **Verify in Fabric SQL DB** (immediate):
   ```sql
   SELECT * FROM dbo.Employees WHERE EmployeeID = 3;
   -- Should show: EmployeeName = 'Sarah Johnson'
   ```

3. **Wait for pipeline** (5 minutes if using 5-min schedule)

4. **Verify in On-Prem SQL Server**:
   ```sql
   SELECT * FROM dbo.Employees WHERE EmployeeID = 3;
   -- Should show: EmployeeName = 'Sarah Johnson'
   ```

---

## Troubleshooting

### Pipeline Fails - Connection Issues
- **Check gateway**: Ensure on-prem data gateway is running
- **Test connection**: In pipeline, test the on-prem SQL Server connection
- **Firewall**: Verify firewall allows outbound connections from Fabric

### Records Not Syncing
- **Check time window**: Increase `SyncWindowHours` parameter
- **Verify timestamps**: Check `LastModifiedDate` in Fabric SQL DB
- **Test query**: Run source query manually in Fabric SQL DB

### Duplicate Key Errors
- **Stored procedure**: Ensure `usp_MergeEmployees` uses MERGE (not INSERT)
- **Primary key**: Verify EmployeeID is primary key on on-prem table

### Performance Issues
- **Reduce frequency**: Change schedule from 5 minutes to 15 minutes or hourly
- **Add indexes**: Index on `LastModifiedDate` in Fabric SQL DB
- **Batch size**: Adjust copy activity settings

---

## Production Recommendations

### 1. Add Comprehensive Logging

Create a log table on-prem:

```sql
CREATE TABLE dbo.PipelineSyncLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    PipelineName NVARCHAR(100),
    StartTime DATETIME,
    EndTime DATETIME,
    Status NVARCHAR(50),
    RowsCopied INT,
    ErrorMessage NVARCHAR(MAX)
);
```

### 2. Implement Change Data Capture

For better performance with large datasets, use CDC instead of timestamp-based queries.

### 3. Add Conflict Resolution

If both sides can be modified simultaneously, implement conflict resolution logic in the merge procedure.

### 4. Set Up Alerts

Configure Azure Monitor alerts for:
- Pipeline failures
- Long-running pipelines
- Zero rows copied (potential issue)

---

## Next Steps

✅ **Writeback solution complete!**

You now have:
1. ✅ Data ingestion from on-prem to Fabric
2. ✅ Power Automate writeback in Fabric SQL Database
3. ✅ Scheduled sync back to on-prem

**Optional enhancements:**
- Add more fields to update (Department, Salary, etc.)
- Implement approval workflows
- Add row-level security
- Build admin dashboard for monitoring
