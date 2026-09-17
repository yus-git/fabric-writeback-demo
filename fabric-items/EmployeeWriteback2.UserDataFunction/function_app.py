import datetime
import json
import logging
import uuid

import fabric.functions as fn


udf = fn.UserDataFunctions()


@udf.connection(argName="lakehouse", alias="HRDatalh")
@udf.context(argName="udfContext")
@udf.function()
def queue_employee_update(
    lakehouse: fn.FabricLakehouseClient,
    udfContext: fn.UserDataFunctionContext,
    employeeId: int,
    employeeName: str,
) -> str:
    """Write an immutable employee update command to the Lakehouse inbox."""
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

    invocation_id = udfContext.invocation_id
    request_id = (
        invocation_id
        if invocation_id
        and invocation_id != "00000000-0000-0000-0000-000000000000"
        else str(uuid.uuid4())
    )
    executing_user = udfContext.executing_user or {}
    modified_by = (
        executing_user.get("PreferredUsername")
        or executing_user.get("Oid")
        or "unknown"
    )

    command = {
        "schemaVersion": 1,
        "requestId": request_id,
        "operation": "UPDATE_EMPLOYEE",
        "employeeId": employee_id,
        "employeeName": normalized_name,
        "modifiedBy": modified_by,
        "submittedAtUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    payload = (json.dumps(command, separators=(",", ":")) + "\n").encode("utf-8")

    files = None
    command_file = None
    try:
        files = lakehouse.connectToFiles()
        directory = files
        for directory_name in ("writeback", "inbox"):
            directory = directory.get_sub_directory_client(directory_name)
            try:
                directory.create_directory()
            except Exception as error:
                if getattr(error, "status_code", None) != 409:
                    raise

        command_file = directory.get_file_client(f"{request_id}.json")
        command_file.create_file()
        command_file.append_data(payload, offset=0, length=len(payload))
        command_file.flush_data(len(payload))
    except Exception:
        logging.exception("Failed to queue employee update %s", request_id)
        raise fn.UserThrownError(
            "The employee update could not be queued. Try again later."
        )
    finally:
        for resource in (command_file, files):
            if resource is not None:
                try:
                    resource.close()
                except Exception:
                    logging.exception("Failed to close a Lakehouse resource")

    return (
        f"Update queued for {normalized_name} "
        f"(Employee ID: {employee_id}). Request ID: {request_id}"
    )