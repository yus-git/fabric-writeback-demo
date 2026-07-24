# Pipeline 1: Ingest Employees (On-Prem → Fabric SQL DB)

## Objective
Copy data from on-prem SQL Server to Fabric SQL Database on a scheduled or triggered basis.

---

## Step 1: Create Connection to On-Prem SQL Server

### In Fabric Portal:

1. Navigate to your workspace: **Fabric Writeback Demo**
2. Click **+ New** → **More options** → **Connection**
3. Select **SQL Server** connection type
4. Configure connection:
   ```
   Connection name: OnPremSQLServer
   Server: <your-server-address>  (e.g., 192.168.1.100 or sqlserver.yourcompany.com)
   Port: 1433 (default)
   Database: HRSystem
   Authentication: SQL Authentication
   Username: <your-sql-username>
   Password: <your-sql-password>
   ```
5. **Test Connection** → **Create**

> **Note**: Since you're using direct connection, ensure:
> - SQL Server is configured to allow remote connections
> - Firewall rules allow inbound traffic on port 1433
> - TCP/IP protocol is enabled in SQL Server Configuration Manager

---

## Step 2: Create Connection to Fabric SQL Database

1. In the same workspace, click **+ New** → **More options** → **Connection**
2. Select **SQL database (Fabric)** connection type
3. Configure:
   ```
   Connection name: FabricSQLDB_HRData
   Workspace: Fabric Writeback Demo
   SQL Database: HRData
   Authentication: Organizational account (your Fabric credentials)
   ```
4. **Test Connection** → **Create**

---

## Step 3: Create Data Pipeline

### 3.1 Create Pipeline

1. In workspace, click **+ New** → **Data Pipeline**
2. Name: `IngestEmployees`
3. Description: "Copy employee data from on-prem SQL Server to Fabric SQL Database"

### 3.2 Add Copy Activity

1. In the pipeline canvas, add **Copy data** activity
2. Name the activity: `CopyEmployees`

### 3.3 Configure Source (On-Prem SQL Server)

**Source Tab:**
- **Connection**: Select `OnPremSQLServer`
- **Source type**: Table
- **Table**: `dbo.Employees`
- **Query**: Leave as "Table" or use custom query:
  ```sql
  SELECT 
      EmployeeID,
      EmployeeName,
      LastModifiedDate,
      ModifiedBy
  FROM dbo.Employees
  ```

**Advanced settings:**
- **Query timeout**: 120 seconds
- **Isolation level**: Read Committed

### 3.4 Configure Destination (Fabric SQL Database)

**Destination Tab:**
- **Connection**: Select `FabricSQLDB_HRData`
- **Destination type**: Table
- **Table**: `dbo.Employees`
- **Write behavior**: 
  - Choose **Truncate** (for full refresh), OR
  - Choose **Upsert** (requires mapping key columns - recommended)

**If using Upsert:**
- **Key columns**: `EmployeeID`
- This will update existing records and insert new ones

### 3.5 Configure Mapping

**Mapping Tab:**
- Auto-map columns (should map 1:1):
  - EmployeeID → EmployeeID
  - EmployeeName → EmployeeName
  - LastModifiedDate → LastModifiedDate
  - ModifiedBy → ModifiedBy

### 3.6 Configure Settings

**Settings Tab:**
- **Enable staging**: No (for small datasets)
- **Degree of copy parallelism**: Auto
- **Data consistency verification**: Enabled

---

## Step 4: Add Schedule (Optional)

1. Click **Schedule** at the top of the pipeline
2. Configure:
   - **Recurrence**: Every 15 minutes / hourly / daily (your choice)
   - **Start date/time**: Now
   - **Time zone**: Your timezone
3. **Save**

---

## Step 5: Test the Pipeline

1. Click **Run** at the top
2. In the run dialog, click **Run**
3. Monitor the pipeline run:
   - Go to **Monitor** tab
   - View pipeline runs
   - Check activity output

### Expected Output:
```
Rows read: 5
Rows written: 5
Copy duration: ~2-5 seconds
Status: Succeeded
```

---

## Step 6: Validate Data Transfer

Run this query in **Fabric SQL Database (HRData)**:

```sql
SELECT * FROM dbo.Employees;
```

You should see:
- 5 records (or however many you inserted)
- Data matches the on-prem source

---

## Troubleshooting

### Portal UI Issues

**Problem: "Failed to render content" or "Cannot read properties of undefined" JavaScript error**

This is a known Fabric portal UI bug. Solutions:

1. **Use "Enter Manually" Checkbox**
   - In the Destination tab, check ✅ **"Enter manually"**
   - Type: `dbo.Employees`
   - Continue with configuration

2. **Try Different Browser**
   - Use Microsoft Edge instead of Chrome (or vice versa)
   - Try InPrivate/Incognito mode
   - Clear browser cache: Ctrl+Shift+Delete → Clear all

3. **Refresh Portal**
   - Hard refresh: Ctrl+F5
   - Close and reopen pipeline editor
   - Sign out and sign back in to Fabric

4. **Verified Table Details** (for manual entry):
   ```
   Server: h6enaovurivu5g64nvhfbn65yy-ccysav34sjcudjfe2ikkgcii7a.database.fabric.microsoft.com
   Database: HRData-ff4e35af-d4bd-4ffa-822a-0e649cbf9c7a
   Table: dbo.Employees
   
   Schema:
   - EmployeeID (INT, PRIMARY KEY)
   - EmployeeName (NVARCHAR)
   - LastModifiedDate (DATETIME2)
   - ModifiedBy (NVARCHAR, NULLABLE)
   ```

### Common Connection Issues:

1. **Connection failed to on-prem SQL Server**
   - Check server address and port
   - Verify firewall rules
   - Ensure SQL Server allows remote connections
   - Test with SQL Server Management Studio first

2. **Authentication failed**
   - Verify username/password
   - Check SQL Server authentication mode (should be mixed mode)

3. **Column mapping errors**
   - Verify schemas match between source and destination
   - Check data types compatibility

4. **Timeout errors**
   - Increase query timeout in source settings
   - Check network latency

5. **Table dropdown shows "Failed More"**
   - This means the destination table doesn't exist yet OR
   - There's a connection/permission issue
   - Solution: Check "Enter manually" and type table name directly

---

## Alternative: Verify Database Connection from Command Line

If the portal UI continues to have issues, verify the destination database works:

```powershell
# Set connection details
$SQL_SERVER="h6enaovurivu5g64nvhfbn65yy-ccysav34sjcudjfe2ikkgcii7a.database.fabric.microsoft.com"
$SQL_DB="HRData-ff4e35af-d4bd-4ffa-822a-0e649cbf9c7a"

# Test connection and verify table exists
sqlcmd -S $SQL_SERVER -d $SQL_DB -G -Q "SELECT COUNT(*) as TableExists FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='Employees'"

# View table schema
sqlcmd -S $SQL_SERVER -d $SQL_DB -G -Q "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Employees' ORDER BY ORDINAL_POSITION"

# Check current data
sqlcmd -S $SQL_SERVER -d $SQL_DB -G -Q "SELECT * FROM dbo.Employees"
```

If these commands work, your destination is properly configured. The issue is only with the Fabric portal UI.

---

## Next Steps

Once Pipeline 1 is working and data is successfully copied to Fabric SQL Database:
- Proceed to `03-semantic-model-setup.md` to create the semantic model and report with writeback capability
