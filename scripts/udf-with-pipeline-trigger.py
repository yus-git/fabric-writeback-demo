import datetime
import fabric.functions as fn
import logging
import requests
import json

# =============================================================================
# CONFIGURATION - Update these with your actual IDs
# =============================================================================
WORKSPACE_ID = "YOUR_WORKSPACE_ID"  # Replace with your workspace ID
PIPELINE_ID = "YOUR_PIPELINE_ID"    # Replace with your sync pipeline ID

udf = fn.UserDataFunctions()

# =============================================================================
# HELPER FUNCTION - Trigger Fabric Pipeline
# =============================================================================
def trigger_pipeline(workspace_id: str, pipeline_id: str, employee_id: int = None) -> tuple:
    """
    Trigger a Fabric pipeline via REST API.
    
    Parameters:
    - workspace_id: Fabric workspace ID
    - pipeline_id: Pipeline ID to trigger
    - employee_id: Optional employee ID to pass as parameter
    
    Returns:
    - (success: bool, message: str)
    """
    try:
        # Construct Fabric Pipeline API URL
        url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items/{pipeline_id}/jobs/instances?jobType=Pipeline"
        
        # Optional: Add parameters if your pipeline accepts them
        payload = {}
        if employee_id:
            payload = {
                "executionData": {
                    "parameters": {
                        "EmployeeID": employee_id
                    }
                }
            }
        
        # Get authentication token from Fabric context
        # In Fabric UDFs, authentication is handled automatically
        headers = {
            "Content-Type": "application/json"
        }
        
        # Make POST request to trigger pipeline
        response = requests.post(
            url, 
            headers=headers, 
            json=payload,
            timeout=10
        )
        
        if response.status_code in [200, 201, 202]:
            logging.info(f"✅ Pipeline triggered successfully for Employee ID {employee_id}")
            return (True, "Pipeline triggered successfully")
        else:
            logging.warning(f"⚠️ Pipeline trigger returned status {response.status_code}: {response.text}")
            return (False, f"Pipeline trigger failed with status {response.status_code}")
            
    except Exception as e:
        logging.error(f"❌ Pipeline trigger error: {str(e)}")
        return (False, f"Pipeline trigger error: {str(e)}")


# =============================================================================
# UPDATE EMPLOYEE - Main writeback function with automatic pipeline trigger
# =============================================================================
@udf.connection(argName="sqlDB", alias="HRData")
@udf.function()
def update_employee(sqlDB: fn.FabricSqlConnection, employeeId: int, employeeName: str, modifiedBy: str) -> str:
    """
    Update employee record in Fabric SQL Database and automatically trigger sync pipeline.
    Called from Power BI translytical task flows.
    
    Parameters:
    - employeeId: Employee ID to update
    - employeeName: New employee name
    - modifiedBy: User email (auto-populated from Power BI using USERPRINCIPALNAME())
    
    Returns:
    - Success or error message as string
    """
    try:
        # Input validation
        if not employeeName or employeeName.strip() == "":
            return "❌ Error: Employee name cannot be empty."
        
        if employeeId <= 0:
            return "❌ Error: Invalid Employee ID."
        
        # Log the update attempt
        logging.info(f"Updating Employee ID {employeeId} to '{employeeName}' by {modifiedBy}")
        
        # Connect to SQL Database
        connection = sqlDB.connect()
        cursor = connection.cursor()
        
        # Execute stored procedure
        sql = """
        EXEC dbo.usp_UpdateEmployee 
            @EmployeeID = ?, 
            @EmployeeName = ?, 
            @ModifiedBy = ?
        """
        
        cursor.execute(sql, (employeeId, employeeName, modifiedBy))
        connection.commit()
        
        # Close resources
        cursor.close()
        connection.close()
        
        # Log success
        logging.info(f"✅ Successfully updated Employee ID {employeeId}")
        
        # =====================================================================
        # AUTOMATIC PIPELINE TRIGGER
        # =====================================================================
        pipeline_message = ""
        if WORKSPACE_ID != "YOUR_WORKSPACE_ID" and PIPELINE_ID != "YOUR_PIPELINE_ID":
            # Only trigger if IDs are configured
            success, message = trigger_pipeline(WORKSPACE_ID, PIPELINE_ID, employeeId)
            
            if success:
                pipeline_message = " | 🔄 Sync pipeline triggered"
            else:
                pipeline_message = f" | ⚠️ Update successful but sync pipeline failed: {message}"
                logging.warning(f"Pipeline trigger warning for Employee ID {employeeId}: {message}")
        else:
            pipeline_message = " | ⚠️ Pipeline IDs not configured - sync not triggered"
            logging.warning("Pipeline IDs not configured in UDF")
        
        # Return success message with pipeline status
        return f"✅ Successfully updated {employeeName} (ID: {employeeId}) by {modifiedBy}{pipeline_message}"
        
    except Exception as e:
        # Log error
        logging.error(f"Error updating employee: {str(e)}")
        
        # Return friendly error message
        return f"❌ Error updating employee: {str(e)}"


# =============================================================================
# UPDATE EMPLOYEE (Without Auto-Sync) - Alternative version
# =============================================================================
@udf.connection(argName="sqlDB", alias="HRData")
@udf.function()
def update_employee_no_sync(sqlDB: fn.FabricSqlConnection, employeeId: int, employeeName: str, modifiedBy: str) -> str:
    """
    Update employee record WITHOUT triggering sync pipeline.
    Use this if you prefer manual pipeline triggering or scheduled sync.
    """
    try:
        # Input validation
        if not employeeName or employeeName.strip() == "":
            return "❌ Error: Employee name cannot be empty."
        
        if employeeId <= 0:
            return "❌ Error: Invalid Employee ID."
        
        logging.info(f"Updating Employee ID {employeeId} to '{employeeName}' by {modifiedBy}")
        
        connection = sqlDB.connect()
        cursor = connection.cursor()
        
        sql = """
        EXEC dbo.usp_UpdateEmployee 
            @EmployeeID = ?, 
            @EmployeeName = ?, 
            @ModifiedBy = ?
        """
        
        cursor.execute(sql, (employeeId, employeeName, modifiedBy))
        connection.commit()
        
        cursor.close()
        connection.close()
        
        logging.info(f"✅ Successfully updated Employee ID {employeeId}")
        
        return f"✅ Successfully updated {employeeName} (ID: {employeeId}) by {modifiedBy}"
        
    except Exception as e:
        logging.error(f"Error updating employee: {str(e)}")
        return f"❌ Error updating employee: {str(e)}"


# =============================================================================
# MANUAL PIPELINE TRIGGER - Can be called separately from Power BI
# =============================================================================
@udf.function()
def trigger_sync_pipeline() -> str:
    """
    Manually trigger the sync pipeline.
    Can be called from a Power BI button if you want manual control.
    
    Returns:
    - Status message
    """
    try:
        if WORKSPACE_ID == "YOUR_WORKSPACE_ID" or PIPELINE_ID == "YOUR_PIPELINE_ID":
            return "❌ Error: Pipeline IDs not configured in UDF code"
        
        success, message = trigger_pipeline(WORKSPACE_ID, PIPELINE_ID)
        
        if success:
            return f"✅ Sync pipeline triggered successfully | Job submitted to workspace"
        else:
            return f"❌ Failed to trigger sync pipeline: {message}"
            
    except Exception as e:
        logging.error(f"Error triggering pipeline: {str(e)}")
        return f"❌ Error: {str(e)}"


# =============================================================================
# GET EMPLOYEE INFO - Display current employee data
# =============================================================================
@udf.connection(argName="sqlDB", alias="HRData")
@udf.function()
def get_employee_info(sqlDB: fn.FabricSqlConnection, employeeId: int) -> str:
    """
    Get current employee information for display in Power BI.
    
    Parameters:
    - employeeId: Employee ID to retrieve
    
    Returns:
    - Employee details or error message
    """
    try:
        connection = sqlDB.connect()
        cursor = connection.cursor()
        
        sql = """
        SELECT EmployeeName, LastModifiedDate, ModifiedBy 
        FROM dbo.Employees 
        WHERE EmployeeID = ?
        """
        
        cursor.execute(sql, (employeeId,))
        row = cursor.fetchone()
        
        cursor.close()
        connection.close()
        
        if row:
            return f"📋 Employee: {row[0]} | Last Modified: {row[1]} by {row[2]}"
        else:
            return f"❌ Employee ID {employeeId} not found"
            
    except Exception as e:
        logging.error(f"Error retrieving employee: {str(e)}")
        return f"❌ Error: {str(e)}"


# =============================================================================
# LIST ALL EMPLOYEES - Optional helper function
# =============================================================================
@udf.connection(argName="sqlDB", alias="HRData")
@udf.function()
def list_employees(sqlDB: fn.FabricSqlConnection) -> list:
    """
    List all employees in the database.
    Returns a list of dictionaries with employee data.
    """
    try:
        connection = sqlDB.connect()
        cursor = connection.cursor()
        
        sql = "SELECT EmployeeID, EmployeeName, LastModifiedDate, ModifiedBy FROM dbo.Employees ORDER BY EmployeeID"
        cursor.execute(sql)
        
        employees = []
        for row in cursor.fetchall():
            employees.append({
                "EmployeeID": row[0],
                "EmployeeName": row[1],
                "LastModifiedDate": str(row[2]),
                "ModifiedBy": row[3]
            })
        
        cursor.close()
        connection.close()
        
        return employees
        
    except Exception as e:
        logging.error(f"Error listing employees: {str(e)}")
        return []


# =============================================================================
# CONFIGURATION INSTRUCTIONS
# =============================================================================
"""
SETUP STEPS:
============

1. GET YOUR WORKSPACE AND PIPELINE IDs:
   Run this PowerShell script: get-fabric-pipeline-ids.ps1
   
   Or manually:
   - Open Fabric portal
   - Workspace URL: https://app.fabric.microsoft.com/groups/WORKSPACE_ID/...
   - Pipeline URL: .../datapipelines/PIPELINE_ID?...

2. UPDATE CONFIGURATION:
   Replace the constants at the top of this file:
   - WORKSPACE_ID = "your-actual-workspace-id"
   - PIPELINE_ID = "your-actual-pipeline-id"

3. DEPLOY THIS UDF:
   - Save this file in your Fabric workspace
   - The UDF will be available in Power BI

4. TEST:
   - Call update_employee() from Power BI or directly
   - Check logs to confirm pipeline trigger
   - Verify data syncs to on-prem

AUTHENTICATION NOTE:
====================
Fabric UDFs run with the workspace identity and have automatic authentication
to Fabric APIs. No additional authentication code is needed.

OPTIONAL FEATURES:
==================
- update_employee() - Auto-triggers pipeline after update
- update_employee_no_sync() - Update only, no pipeline trigger
- trigger_sync_pipeline() - Manual pipeline trigger from Power BI button
"""
