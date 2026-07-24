# Power Automate Writeback Setup

## Overview
This guide sets up a Power Automate flow that allows users to update employee records from a Power BI report button, writing changes to Fabric SQL Database.

---

## Architecture

```
Power BI Report (User clicks button)
        ↓
Power Automate Flow (Triggered)
        ↓
Fabric SQL Database → usp_UpdateEmployee
        ↓
Employees table updated
        ↓
Pipeline 2 syncs back to on-prem (scheduled)
```

---

## Step 1: Create Power Automate Flow

### 1.1 Navigate to Power Automate

1. Go to [Power Automate](https://make.powerautomate.com)
2. Sign in with your Microsoft account
3. Ensure you're in the correct environment

### 1.2 Create New Flow

1. Click **+ Create** → **Instant cloud flow**
2. Configure:
   - **Flow name**: `UpdateEmployeeFromPowerBI`
   - **Choose trigger**: **Power BI button**
3. Click **Create**

### 1.3 Configure Power BI Button Trigger

1. The trigger "Power BI button" is automatically added
2. Click **+ Add an input**
3. Add the following inputs (click "+ Add an input" for each):

   **Input 1:**
   - Type: **Number**
   - Input name: `EmployeeID`
   - Please enter your input: (leave as default)

   **Input 2:**
   - Type: **Text**
   - Input name: `EmployeeName`
   - Please enter your input: (leave as default)

### 1.4 Add Initialize Variable (for ModifiedBy)

1. Click **+ New step**
2. Search for **"Initialize variable"**
3. Configure:
   - **Name**: `ModifiedBy`
   - **Type**: String
   - **Value**: Click in the field, then select **Dynamic content** → **User email** (or **User name**)

### 1.5 Add SQL Server Action

1. Click **+ New step**
2. Search for **"SQL Server"**
3. Select action: **Execute stored procedure (V2)**

### 1.6 Configure SQL Connection

**First time only - Create connection:**
- **Authentication Type**: Select based on your setup
  
**For Fabric SQL Database (Recommended):**
- **Authentication Type**: **OAuth**
- **Server name**: Your Fabric SQL endpoint
  - Go to Fabric portal → SQL Database (HRData) → Settings → Copy SQL connection string
  - Extract the server name (format: `xxx.datawarehouse.fabric.microsoft.com`)
- **Database name**: `HRData`
- Click **Create**

### 1.7 Configure Stored Procedure Execution

Once connected, configure:
- **Server name**: (auto-filled from connection)
- **Database name**: `HRData`
- **Procedure name**: Select `[dbo].[usp_UpdateEmployee]` from dropdown

**Parameter mapping:**
- **EmployeeID**: Select from Dynamic content → `EmployeeID` (from Power BI button)
- **EmployeeName**: Select from Dynamic content → `EmployeeName` (from Power BI button)
- **ModifiedBy**: Select from Dynamic content → `ModifiedBy` (the variable we initialized)

### 1.8 Add Success Notification (Optional)

1. Click **+ New step**
2. Search for **"Compose"**
3. Configure:
   - **Inputs**: `Employee updated successfully: @{triggerBody()?['EmployeeName']}`

### 1.9 Save and Test Flow

1. Click **Save** (top right)
2. Click **Test** → **Manually** → **Test**
3. Enter test values:
   - EmployeeID: `2`
   - EmployeeName: `Mo`
4. Click **Run flow**
5. Verify in Fabric SQL Database:
   ```sql
   SELECT * FROM dbo.Employees WHERE EmployeeID = 2;
   ```

---

## Step 2: Create Power BI Report

### 2.1 Option A: Power BI Desktop (Full Control)

1. **Download Power BI Desktop** if not installed
2. **Connect to Fabric SQL Database**:
   - Get Data → More → Azure → SQL Server
   - **Server**: Get from Fabric portal (HRData → Settings → SQL connection string)
     - Format: `xxx.datawarehouse.fabric.microsoft.com`
   - **Database**: `HRData`
   - **Data Connectivity mode**: **DirectQuery** (important!)
   - Click **OK**
3. **Authenticate** with Microsoft account
4. **Select** `dbo.Employees` table
5. Click **Load**

### 2.2 Create Table Visual

1. Add **Table** visual to canvas
2. Add fields:
   - EmployeeID
   - EmployeeName
   - LastModifiedDate
   - ModifiedBy
3. Format the table (optional):
   - Grid → Text size: 12
   - Column headers → Bold

### 2.3 Add Slicer for Selection

1. Add **Slicer** visual
2. Add field: **EmployeeID**
3. Format: **Dropdown** style
4. Place above the table

### 2.4 Add Power Automate Button

1. From ribbon: **Insert** → **Buttons** → **Blank**
2. Format the button:
   - **Button text**: "Update Employee"
   - **Style**: Your preference (Icon + Text recommended)
3. **Configure Action**:
   - Select button → Format → Action → **On**
   - **Type**: **Power Automate**
   - **Flow**: Select `UpdateEmployeeFromPowerBI`
   - **Map fields**:
     - EmployeeID → Select from `dbo.Employees[EmployeeID]` (use selected value from slicer)
     - EmployeeName → Select from `dbo.Employees[EmployeeName]`

**To pass selected values:**
- Add a text box for users to type new name, OR
- Better: Add a **Text input** visual (if available in your version)

### 2.5 Enhanced UI with Text Input

**Better approach using Text Input:**

1. Add a **Single select slicer** → EmployeeID
2. Add a **Table** showing selected employee details
3. Add a **Text box visual** with instructions: "Enter new name below:"
4. Add a **Text input** control (Insert → Text input)
5. Add **Button** → Power Automate
   - Map EmployeeID from slicer
   - Map EmployeeName from text input

### 2.6 Publish Report

1. Click **File** → **Publish** → **Publish to Power BI**
2. Select workspace: **Fabric Writeback Demo**
3. Click **Select**
4. Wait for publish to complete
5. Click **Open [filename] in Power BI** to test

---

## Step 3: Test End-to-End

### 3.1 Test in Power BI Service

1. Open published report in Power BI Service
2. Select **EmployeeID = 2** (Mohammed)
3. Enter new name: **Mo**
4. Click **Update Employee** button
5. Wait for flow to execute (5-10 seconds)
6. Refresh the report page (browser refresh)
7. Verify "Mohammed" is now "Mo"

### 3.2 Verify in Fabric SQL Database

Go to Fabric portal and run:
```sql
SELECT * FROM dbo.Employees 
WHERE EmployeeID = 2;
-- Should show: EmployeeName = 'Mo'
```

---

## Step 4: Alternative - Direct Report Edit (No Button)

For advanced users with Power BI Premium/Fabric capacity:

### 4.1 Enable Report Writeback (if available)

1. In Power BI Desktop, select table visual
2. Format → General → **Advanced options**
3. Look for **Allow data entry** or **Enable editing**
4. Configure to call stored procedure directly

**Note**: This feature availability varies by license and Fabric capacity tier.

---

## Troubleshooting

### Flow Fails to Execute
- **Check connection**: Ensure Fabric SQL Database connection in Power Automate is active
- **Test stored procedure manually** using test-writeback.sql
- **Check permissions**: User running flow needs EXECUTE permission on stored procedure

### Button Doesn't Appear in Report
- **Check Power BI license**: Power Automate buttons require Power BI Pro or Premium
- **Workspace settings**: Ensure Power Automate is enabled in workspace settings

### Changes Don't Appear Immediately
- **DirectQuery cache**: Refresh the report page (F5)
- **Check LastModifiedDate** to verify update actually happened
- **Run query** in Fabric SQL Database to confirm

---

## Security Best Practices

1. **Audit Trail**: The stored procedure captures ModifiedBy and LastModifiedDate
2. **Row-Level Security**: Consider adding RLS to the semantic model
3. **Limit Update Fields**: Only allow specific fields to be edited (EmployeeName in this case)
4. **Approval Workflow**: For production, add approval step in Power Automate before updating database

---

## Next Steps

Once writeback is working:
- Proceed to **06-pipeline-syncback-implementation.md** to sync changes back to on-prem SQL Server
- Set up scheduled refresh to keep data current
- Add monitoring and alerting for failed updates
