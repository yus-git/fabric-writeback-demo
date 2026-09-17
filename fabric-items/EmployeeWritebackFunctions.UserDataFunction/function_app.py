import logging

import fabric.functions as fn


udf = fn.UserDataFunctions()


def _executing_user(udf_context: fn.UserDataFunctionContext) -> str:
    executing_user = udf_context.executing_user or {}
    return (
        executing_user.get("PreferredUsername")
        or executing_user.get("Oid")
        or "unknown"
    )


def _close_quietly(resource) -> None:
    if resource is None:
        return
    try:
        resource.close()
    except Exception:
        logging.exception("Failed to close a SQL resource")


@udf.connection(argName="sqlDB", alias="HRData")
@udf.context(argName="udfContext")
@udf.function()
def update_employee(
    sqlDB: fn.FabricSqlConnection,
    udfContext: fn.UserDataFunctionContext,
    employeeId: int,
    employeeName: str,
) -> str:
    """Update one employee in Fabric SQL Database."""
    try:
        employee_id = int(employeeId)
    except (TypeError, ValueError):
        raise fn.UserThrownError("Employee ID must be a valid whole number.")

    normalized_name = employeeName.strip() if employeeName else ""
    if employee_id <= 0:
        raise fn.UserThrownError("Employee ID must be greater than zero.")
    if not normalized_name:
        raise fn.UserThrownError("Employee name cannot be empty.")
    if len(normalized_name) > 200:
        raise fn.UserThrownError("Employee name cannot exceed 200 characters.")

    modified_by = _executing_user(udfContext)
    connection = None
    cursor = None

    try:
        connection = sqlDB.connect()
        cursor = connection.cursor()
        cursor.execute(
            """
            EXEC dbo.usp_UpdateEmployee
                @EmployeeId = ?,
                @EmployeeName = ?,
                @ModifiedBy = ?
            """,
            (employee_id, normalized_name, modified_by),
        )
        connection.commit()
    except Exception:
        if connection is not None:
            connection.rollback()
        logging.exception("Employee update failed for ID %s", employee_id)
        raise fn.UserThrownError(
            "The employee could not be updated. Refresh the report and try again."
        )
    finally:
        _close_quietly(cursor)
        _close_quietly(connection)

    return f"Updated {normalized_name} (Employee ID: {employee_id})."


@udf.connection(argName="sqlDB", alias="HRData")
@udf.function()
def get_employee_info(
    sqlDB: fn.FabricSqlConnection,
    employeeId: int,
) -> str:
    """Return one employee as a display string."""
    try:
        employee_id = int(employeeId)
    except (TypeError, ValueError):
        raise fn.UserThrownError("Employee ID must be a valid whole number.")

    connection = None
    cursor = None
    try:
        connection = sqlDB.connect()
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT EmployeeName, ModifiedDate, ModifiedBy
            FROM dbo.Employees
            WHERE EmployeeId = ?
            """,
            (employee_id,),
        )
        row = cursor.fetchone()
    except Exception:
        logging.exception("Employee lookup failed for ID %s", employee_id)
        raise fn.UserThrownError("Employee details are temporarily unavailable.")
    finally:
        _close_quietly(cursor)
        _close_quietly(connection)

    if row is None:
        return f"Employee ID {employee_id} was not found."
    return f"{row[0]} | Last modified: {row[1]} | Modified by: {row[2]}"


@udf.connection(argName="sqlDB", alias="HRData")
@udf.function()
def list_employees(sqlDB: fn.FabricSqlConnection) -> list:
    """Return all employees for function testing and diagnostics."""
    connection = None
    cursor = None
    try:
        connection = sqlDB.connect()
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT EmployeeId, EmployeeName, ModifiedDate, ModifiedBy
            FROM dbo.Employees
            ORDER BY EmployeeId
            """
        )
        return [
            {
                "EmployeeId": row[0],
                "EmployeeName": row[1],
                "ModifiedDate": str(row[2]),
                "ModifiedBy": row[3],
            }
            for row in cursor.fetchall()
        ]
    except Exception:
        logging.exception("Employee list query failed")
        raise fn.UserThrownError("The employee list is temporarily unavailable.")
    finally:
        _close_quietly(cursor)
        _close_quietly(connection)