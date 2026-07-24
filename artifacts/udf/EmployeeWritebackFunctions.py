import datetime
import fabric.functions as fn
import logging

udf = fn.UserDataFunctions()
# =============================================================================
# UPDATE EMPLOYEE - Main writeback function with full audit trail
# =============================================================================
@udf.connection(argName="sqlDB", alias="HRData")
@udf.function()
def update_employee(sqlDB: fn.FabricSqlConnection, employeeId: int, employeeName: str, modifiedBy: str) -> str:
    """
    Update employee record in Fabric SQL Database.
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
        logging.info(f"Successfully updated Employee ID {employeeId}")
        
        # Return success message
        return f"✅ Successfully updated {employeeName} (ID: {employeeId}) by {modifiedBy}"
        
    except Exception as e:
        # Log error
        logging.error(f"Error updating employee: {str(e)}")
        
        # Return friendly error message
        return f"❌ Error updating employee: {str(e)}"


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
        # Connect to SQL Database
        connection = sqlDB.connect()
        cursor = connection.cursor()
        
        # Query employee data
        sql = """
        SELECT EmployeeName, LastModifiedDate, ModifiedBy 
        FROM dbo.Employees 
        WHERE EmployeeID = ?
        """
        
        cursor.execute(sql, (employeeId,))
        row = cursor.fetchone()
        
        # Close resources
        cursor.close()
        connection.close()
        
        # Return result
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
        
        # Convert to list of dictionaries
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
