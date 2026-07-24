# Semantic Model & Report Setup with Writeback

## Objective
Create a Power BI semantic model connected to Fabric SQL Database and build a report that allows users to edit employee names directly, with changes written back to the database.

---

## Step 1: Create Semantic Model

### 1.1 Create Direct Lake Semantic Model (Recommended for Fabric SQL DB)

1. In Fabric portal, navigate to workspace: **Fabric Writeback Demo**
2. Click **+ New** → **Semantic model**
3. Configure:
   ```
   Name: EmployeeModel
   Description: Employee data with writeback capability
   ```
4. Click **Create**

### 1.2 Connect to Fabric SQL Database

1. In the semantic model, click **Get data**
2. Select **SQL database in Fabric**
3. Choose:
   - **Workspace**: Fabric Writeback Demo
   - **SQL Database**: HRData
4. Click **Connect**

### 1.3 Select Tables

1. Select the `dbo.Employees` table
2. Click **Create**

---

## Step 2: Configure Table for Writeback (UDF Method)

Writeback in Power BI requires a **User-Defined Function (UDF)** in the SQL database.

### 2.1 Create Writeback Stored Procedure (Already Done)

We created `usp_UpdateEmployee` in Step 1 (01-table-creation.sql). Verify it exists:

```sql
-- Run in Fabric SQL Database (HRData)
SELECT name 
FROM sys.objects 
WHERE type = 'P' AND name = 'usp_UpdateEmployee';
```

### 2.2 Configure Writeback in Power BI Desktop

Unfortunately, **Fabric SQL Database writeback via Power BI Service is still in preview** and has limitations. Here's the recommended approach:

#### Option A: Use Power BI Desktop for Writeback (Full Control)

1. **Download Power BI Desktop** (if not installed)
2. **Connect to Fabric SQL Database** from Power BI Desktop:
   - Get Data → Azure → Azure SQL Database
   - Server: Find your Fabric SQL DB endpoint:
     - In Fabric portal → SQL Database (HRData) → **Connection strings**
     - Copy the SQL endpoint URL
   - Database: HRData
   - Data connectivity mode: **DirectQuery** (required for writeback)
   - Advanced options → Command timeout: 600
3. **Load Employees table**

#### Option B: Use Fabric Built-in Report (Limited Writeback)

Fabric SQL Database has a built-in **Edit data** feature in the web interface.

---

## Step 3: Create Report with Edit Capability

### Using Power BI Desktop:

#### 3.1 Create Table Visual

1. Add **Table** visual to canvas
2. Add fields:
   - EmployeeID
   - EmployeeName
   - LastModifiedDate
   - ModifiedBy

#### 3.2 Enable Editing (Custom Method)

Since native writeback is limited, we'll use **Power Apps integration**:

1. **Insert Power Apps Visual**:
   - In Power BI Desktop, go to Insert → Power Apps
   - Drag to canvas

2. **Create Power Apps Form**:
   - When prompted, create a new Power App
   - Connect to Fabric SQL Database (HRData)
   - Create an **Edit form** for Employees table

3. **Configure Form**:
   ```
   Data source: Fabric SQL Database (HRData)
   Table: Employees
   Form type: Edit
   Fields to show: EmployeeID (read-only), EmployeeName (editable)
   ```

4. **Add Submit Button**:
   - OnSelect: 
   ```powerapps
   Patch(
       Employees,
       LookUp(Employees, EmployeeID = Selected_EmployeeID),
       {
           EmployeeName: TextInput_EmployeeName.Text,
           ModifiedBy: User().FullName,
           LastModifiedDate: Now()
       }
   );
   Notify("Employee updated successfully!", NotificationType.Success)
   ```

#### Alternative: Simpler Table with Button

1. Create a **Table** visual with Employees data
2. Add a **Button** visual: "Sync Changes"
3. Configure button action:
   - Action type: **Web URL**
   - URL: Trigger a Power Automate flow (see below)

---

## Step 4: Alternative - Use Power Automate for Writeback

This is the **most practical approach** for Fabric SQL DB writeback:

### 4.1 Create Power Automate Flow

1. Go to **Power Automate** (flow.microsoft.com)
2. Create **Instant cloud flow**:
   ```
   Name: UpdateEmployeeFromPowerBI
   Trigger: Power BI button
   ```

3. **Add trigger**: Power BI button
   - Add input parameters:
     - EmployeeID (Number)
     - EmployeeName (Text)

4. **Add action**: SQL Server - Execute stored procedure
   - Connection: Create connection to Fabric SQL Database
   - Procedure name: `[dbo].[usp_UpdateEmployee]`
   - Parameters:
     - @EmployeeID: [EmployeeID from Power BI]
     - @EmployeeName: [EmployeeName from Power BI]
     - @ModifiedBy: User email

5. **Save flow**

### 4.2 Add Button to Power BI Report

1. In Power BI Desktop, add **Button** visual
2. Configure:
   - Action: Power Automate
   - Flow: Select `UpdateEmployeeFromPowerBI`
   - Map parameters from selected table row

---

## Step 5: Testing Writeback with SQL Queries

For quick testing before building the full report, use the **Query Editor**:

1. Go to Fabric portal → SQL Database (HRData)
2. Click **New Query** button (top toolbar)
3. Run UPDATE statements to simulate writeback:
   ```sql
   -- Test update
   UPDATE dbo.Employees
   SET EmployeeName = 'Mo',
       LastModifiedDate = GETDATE(),
       ModifiedBy = 'Manual Test'
   WHERE EmployeeID = 2;
   
   -- Verify
   SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
   ```

This is perfect for:
- Testing your stored procedure
- Admin-level updates
- Validating the setup before building the full solution

**Note**: Fabric SQL Database does not have a direct "Edit data in grid" feature. Use Power BI + Power Automate for user-driven writeback.

---

## Step 6: Test Writeback Flow

### Test Scenario:
1. Open your report (or Fabric SQL DB data view)
2. Find "Mohammed" (EmployeeID = 2)
3. Change name to "Mo"
4. Save/Submit
5. Verify update:
   ```sql
   SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
   -- Expected: EmployeeName = 'Mo'
   ```

---

## Recommended Architecture for Production

For a production-ready writeback solution, I recommend:

```
Power BI Report → Button/Selection 
                  ↓
         Power Automate Flow
                  ↓
    Fabric SQL Database (HRData) → usp_UpdateEmployee
                  ↓
          (Updates Employees table)
                  ↓
    Pipeline 2: Sync Back (scheduled)
                  ↓
         On-Prem SQL Server
```

This provides:
- Audit trail (LastModifiedDate, ModifiedBy)
- Error handling in Power Automate
- Scheduled sync back to on-prem (not real-time, but safer)

---

## Next Steps

Once you've tested the writeback mechanism:
- **For Power Automate setup**: Proceed to `05-power-automate-writeback-setup.md`
- **For sync-back pipeline**: Proceed to `06-pipeline-syncback-implementation.md`
