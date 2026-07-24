# 🚀 Automated Demo Setup Guide

This guide will walk you through creating the complete writeback demo with step-by-step commands and scripts.

---

## ⚠️ Prerequisites Check

Before starting, ensure:
- [ ] You have a Microsoft Fabric workspace: **"Fabric Writeback Demo"**
- [ ] You have Fabric Contributor or Admin permissions
- [ ] You have created a SQL Database artifact named: **"HRData"**
- [ ] You have access to your on-prem SQL Server (or Azure SQL DB for testing)

---

## 🔐 Step 0: Sign In to Fabric (REQUIRED)

If you haven't already, sign in to Fabric in VS Code:

1. Install the **Fabric Data Engineering extension** in VS Code (if not installed)
2. Click on the Fabric icon in the left sidebar
3. Click **"Sign in to Microsoft Fabric"**
4. Follow the authentication flow
5. Verify you can see your workspaces

---

## 📋 Step 1: Create Table in Fabric SQL Database

### Option A: Via Fabric Portal (Easiest)

1. Go to https://app.fabric.microsoft.com
2. Navigate to workspace: **Fabric Writeback Demo**
3. Open SQL Database: **HRData**
4. Click **"New Query"** button
5. Paste and run this SQL:

```sql
-- Create Employees table
CREATE TABLE dbo.Employees (
    EmployeeID INT PRIMARY KEY,
    EmployeeName NVARCHAR(255) NOT NULL,
    LastModifiedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedBy NVARCHAR(100) DEFAULT SYSTEM_USER
);

-- Create index for efficient merge operations
CREATE INDEX IX_Employees_LastModifiedDate ON dbo.Employees(LastModifiedDate);

-- Create stored procedure for writeback updates
CREATE OR ALTER PROCEDURE dbo.usp_UpdateEmployee
    @EmployeeID INT,
    @EmployeeName NVARCHAR(255),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE dbo.Employees
    SET 
        EmployeeName = @EmployeeName,
        LastModifiedDate = GETDATE(),
        ModifiedBy = @ModifiedBy
    WHERE EmployeeID = @EmployeeID;
    
    -- Return the updated record
    SELECT * FROM dbo.Employees WHERE EmployeeID = @EmployeeID;
END;

-- Verify table created
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Employees';
```

✅ **Validation**: You should see the Employees table listed.

### Option B: Via Azure Data Studio

1. Get connection string:
   - In Fabric portal → SQL Database (HRData) → **"Connection strings"**
   - Copy the SQL connection string
2. Open Azure Data Studio
3. Connect using the connection string
4. Run the SQL script above

---

## 📋 Step 2: Create Table in On-Prem SQL Server

### On your SQL Server (SSMS or Azure Data Studio):

```sql
-- Create database (if needed)
CREATE DATABASE HRSystem;
GO

USE HRSystem;
GO

-- Create Employees table
CREATE TABLE dbo.Employees (
    EmployeeID INT PRIMARY KEY,
    EmployeeName NVARCHAR(255) NOT NULL,
    LastModifiedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedBy NVARCHAR(100) DEFAULT SYSTEM_USER
);

-- Create index
CREATE INDEX IX_Employees_LastModifiedDate ON dbo.Employees(LastModifiedDate);

-- Insert sample data
INSERT INTO dbo.Employees (EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy)
VALUES 
    (1, 'Yusra', GETDATE(), 'System'),
    (2, 'Mohammed', GETDATE(), 'System'),
    (3, 'Sarah Johnson', GETDATE(), 'System'),
    (4, 'Michael Chen', GETDATE(), 'System'),
    (5, 'Emily Davis', GETDATE(), 'System');

-- Create merge stored procedure
CREATE OR ALTER PROCEDURE dbo.usp_MergeEmployees
    @EmployeeID INT,
    @EmployeeName NVARCHAR(255),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    MERGE INTO dbo.Employees AS Target
    USING (
        SELECT 
            @EmployeeID AS EmployeeID,
            @EmployeeName AS EmployeeName,
            @ModifiedBy AS ModifiedBy
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
END;

-- Verify
SELECT * FROM dbo.Employees;
```

✅ **Validation**: You should see 5 employee records.

---

## 🔌 Step 3: Create Connections in Fabric Portal

### 3.1 Connection to On-Prem SQL Server

1. In Fabric portal, go to workspace: **Fabric Writeback Demo**
2. Click **⚙️ Settings** (bottom left) → **Manage connections and gateways**
3. Click **+ New connection**
4. Select **SQL Server**
5. Configure:
   ```
   Connection name: OnPremSQLServer
   Server: [Your SQL Server address/IP]
   Database: HRSystem
   Authentication kind: SQL
   Username: [your username]
   Password: [your password]
   
   Gateway: [Leave off for direct connection, or select if using OPDG]
   ```
6. Click **Test connection**
7. If successful, click **Create**

### 3.2 Connection to Fabric SQL Database

1. Click **+ New connection**
2. Select **SQL database in Microsoft Fabric**
3. Configure:
   ```
   Connection name: FabricSQLDB_HRData
   Workspace: Fabric Writeback Demo
   SQL Database: HRData
   Authentication kind: Organizational account
   ```
4. Click **Create**

✅ **Validation**: You should see both connections listed.

---

## 🔄 Step 4: Create Pipeline 1 - Ingest (On-Prem → Fabric)

### 4.1 Create Pipeline

1. In workspace, click **+ New** → **Data pipeline**
2. Name: `Pipeline_IngestEmployees`
3. Click **Create**

### 4.2 Add Copy Activity

1. In the pipeline canvas, search for **Copy data** activity
2. Drag it to the canvas
3. Name it: `CopyEmployeesToFabric`

### 4.3 Configure Source

1. Click on the Copy activity
2. Go to **Source** tab
3. Click **+ New** next to Data source
4. Select **SQL Server**
5. Choose connection: `OnPremSQLServer`
6. Click **OK**
7. Configure:
   - **Use query**: Table
   - **Table**: Select `dbo.Employees`

### 4.4 Configure Destination

1. Go to **Destination** tab
2. Click **+ New** next to Data destination
3. Select **SQL database in Microsoft Fabric**
4. Choose connection: `FabricSQLDB_HRData`
5. Click **OK**
6. Configure:
   - **Table option**: Use existing table
   - **Table**: Select `dbo.Employees`
   - **Write method**: Upsert
   - **Key columns**: Select `EmployeeID`

### 4.5 Save and Test

1. Click **💾 Save** (top toolbar)
2. Click **▶️ Run** (top toolbar)
3. Monitor the run:
   - Wait for completion (~30 seconds)
   - Status should be: **Succeeded**
   - Rows copied: **5**

✅ **Validation**: 
```sql
-- Run in Fabric SQL Database (HRData)
SELECT * FROM dbo.Employees;
-- Should show 5 employees
```

---

## 📝 Step 5: Test Writeback

### Option 1: Direct Edit in Fabric Portal (Easiest)

1. In Fabric portal → SQL Database (HRData)
2. Click **Data** tab
3. Click on `dbo.Employees` table
4. Click **Edit data** button (top right)
5. Find Employee ID 2 (Mohammed)
6. Change name to: **"Mo"**
7. Click **Save**

✅ **Validation**:
```sql
SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
-- Should show "Mo"
```

### Option 2: Via SQL Query

```sql
-- Run in Fabric SQL Database (HRData)
UPDATE dbo.Employees
SET EmployeeName = 'Mo',
    ModifiedBy = 'Yusra',
    LastModifiedDate = GETDATE()
WHERE EmployeeID = 2;

-- Verify
SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
```

---

## 🔙 Step 6: Create Pipeline 2 - Sync Back (Fabric → On-Prem)

### 6.1 Create Pipeline

1. In workspace, click **+ New** → **Data pipeline**
2. Name: `Pipeline_SyncBackEmployees`
3. Click **Create**

### 6.2 Add Copy Activity

1. Drag **Copy data** activity to canvas
2. Name it: `SyncUpdatesToOnPrem`

### 6.3 Configure Source (Fabric SQL DB with Filter)

1. Click on the Copy activity → **Source** tab
2. Select connection: `FabricSQLDB_HRData`
3. **Use query**: Query
4. **Query**:
   ```sql
   SELECT 
       EmployeeID,
       EmployeeName,
       ModifiedBy
   FROM dbo.Employees
   WHERE LastModifiedDate >= DATEADD(HOUR, -24, GETDATE())
   ```
   
   *(This only syncs records modified in last 24 hours - adjust as needed)*

### 6.4 Configure Destination (Stored Procedure)

1. Go to **Destination** tab
2. Select connection: `OnPremSQLServer`
3. **Write method**: Stored procedure
4. **Stored procedure name**: `[dbo].[usp_MergeEmployees]`
5. Map parameters:
   - EmployeeID → @EmployeeID
   - EmployeeName → @EmployeeName
   - ModifiedBy → @ModifiedBy

### 6.5 Save and Test

1. Click **💾 Save**
2. Click **▶️ Run**
3. Monitor the run

✅ **Validation**:
```sql
-- Run on On-Prem SQL Server
SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
-- Should now show "Mo" (synced from Fabric)
```

---

## 🔄 Step 7: Schedule Automated Sync

### Schedule Pipeline 1 (Ingest)

1. Open `Pipeline_IngestEmployees`
2. Click **Schedule** button (top toolbar)
3. Configure:
   - **Enabled**: On
   - **Recurrence**: Every 1 hour
   - **Start date/time**: Now
   - **Time zone**: Your timezone
4. Click **Apply**

### Schedule Pipeline 2 (Sync Back)

1. Open `Pipeline_SyncBackEmployees`
2. Click **Schedule** button
3. Configure:
   - **Enabled**: On
   - **Recurrence**: Every 30 minutes
   - **Start date/time**: Now
   - **Time zone**: Your timezone
4. Click **Apply**

---

## 🧪 Step 8: End-to-End Test

### Complete Workflow Test:

1. **Update on-prem**:
   ```sql
   -- On-prem SQL Server
   UPDATE dbo.Employees
   SET EmployeeName = 'Sarah J.'
   WHERE EmployeeID = 3;
   ```

2. **Wait or manually run Pipeline 1** (IngestEmployees)

3. **Verify in Fabric**:
   ```sql
   -- Fabric SQL Database
   SELECT * FROM dbo.Employees WHERE EmployeeID = 3;
   -- Should show 'Sarah J.'
   ```

4. **Update in Fabric**:
   ```sql
   -- Fabric SQL Database
   UPDATE dbo.Employees
   SET EmployeeName = 'Michael C.'
   WHERE EmployeeID = 4;
   ```

5. **Wait or manually run Pipeline 2** (SyncBackEmployees)

6. **Verify on-prem**:
   ```sql
   -- On-prem SQL Server
   SELECT * FROM dbo.Employees WHERE EmployeeID = 4;
   -- Should show 'Michael C.'
   ```

✅ **Success!** Your bidirectional sync is working!

---

## 📊 Architecture Diagram (What You Built)

```
┌─────────────────────────────────────────────────────────────────┐
│                     On-Prem SQL Server                          │
│                        HRSystem.Employees                       │
│   [5 employees: Yusra, Mohammed, Sarah, Michael, Emily]        │
└───────────────────┬─────────────────────────────────────────────┘
                    │                                     ▲
                    │ Pipeline 1: IngestEmployees        │
                    │ (Every 1 hour)                     │
                    │ Copy Activity                       │
                    ▼                                     │
┌─────────────────────────────────────────────────────────────────┐
│                  Fabric SQL Database (HRData)                   │
│                        dbo.Employees                            │
│   [Synced data + user updates]                                 │
└───────────────────┬─────────────────────────────────────────────┘
                    │                                     │
                    │ User updates via:                  │ Pipeline 2: SyncBackEmployees
                    │ - Direct edit                       │ (Every 30 min)
                    │ - SQL query                         │ Stored Procedure: usp_MergeEmployees
                    │ - Power BI report (future)         │
                    └─────────────────────────────────────┘
```

---

## 🎯 What You've Accomplished

✅ Created Employees table in Fabric SQL Database  
✅ Created Employees table in On-Prem SQL Server  
✅ Set up connections to both databases  
✅ Built Pipeline 1: On-Prem → Fabric (ingest)  
✅ Tested writeback capability in Fabric  
✅ Built Pipeline 2: Fabric → On-Prem (sync back with merge logic)  
✅ Scheduled automated bidirectional sync  
✅ Validated end-to-end workflow  

---

## 🚀 Next Steps (Optional Enhancements)

1. **Create Power BI Report with Writeback**
   - Build semantic model on Fabric SQL DB
   - Create report with edit capability
   - Add Power Automate flow for writeback

2. **Add Monitoring & Alerts**
   - Set up email notifications for pipeline failures
   - Create dashboard showing sync metrics

3. **Migrate to OPDG**
   - Install On-Premises Data Gateway
   - Update connections to use gateway
   - Enhanced security and enterprise-ready

4. **Add More Tables**
   - Replicate pattern for Departments, Projects, etc.
   - Build complete HR system

---

## 🆘 Troubleshooting

### Pipeline Fails with "Connection Error"
- Verify connections are working (test in connection settings)
- Check SQL Server credentials
- Ensure SQL Server allows remote connections

### No Data Synced
- Check pipeline run details for specific errors
- Verify table schemas match
- Check LastModifiedDate filter in Pipeline 2 query

### Merge Not Working
- Verify stored procedure exists on on-prem
- Check parameter mapping in Copy activity
- Test stored procedure manually

---

## 📚 Reference Files

- **SQL Scripts**: `01-table-creation.sql`
- **Pipeline Guide**: `02-pipeline-ingest-config.md`, `04-pipeline-syncback-config.md`
- **OPDG Migration**: `OPDG_MIGRATION_GUIDE.md`

---

**Congratulations! You've built a complete bidirectional writeback solution!** 🎉
