# Pattern 2: UDF, Lakehouse, and Spark notebook

Use this pattern when the system of record is a Lakehouse and queued, eventual writeback is acceptable. The UDF does not update a Delta row directly. It appends one immutable JSON command to OneLake, and a scheduled PySpark notebook applies commands later.

## Why a queue

A UDF Lakehouse connection supports writing Lakehouse files, while access through the Lakehouse SQL analytics endpoint is read-only. Writing a small command file keeps the user-facing function short and append-only. Spark owns validation, deduplication, Delta mutation, and auditing.

## Deploy

1. Create a **Lakehouse** item. The sample uses `HRData_lh`.
2. Create a PySpark Fabric notebook with the **Microsoft Fabric Runtime** kernel and attach that Lakehouse as its default.
3. To create sample source data, copy and run [`01-create-sample-source.py`](../scripts/lakehouse/01-create-sample-source.py) as a notebook cell. Skip this step when an `Employees` Delta table already exists with the expected columns.
4. Import [`notebook-content.py`](../fabric-items/Apply_Employee_Lakehouse_Writeback.Notebook/notebook-content.py) as a Fabric notebook, or reproduce its cells in the notebook from step 2. Attach the destination Lakehouse again if import did not preserve the binding.
5. Create a **User data functions** item named `EmployeeWriteback2`.
6. In **Manage connections**, add the Lakehouse and set its alias to `HRDatalh`.
7. Replace the generated function source with [`function_app.py`](../fabric-items/EmployeeWriteback2.UserDataFunction/function_app.py).
8. Test and publish `queue_employee_update`.
9. Run the processing notebook once. It creates `Employees_Native`, `Employee_Writeback_Audit`, and `Files/writeback/inbox` when needed.
10. Schedule the notebook or invoke it from a pipeline. Configure the orchestration so only one run is active at a time.

The source table contract is:

| Column | Expected type/meaning |
| --- | --- |
| `EmployeeID` | Integer employee key |
| `EmployeeName` | Employee display name |
| `LastModifiedDate` | Timestamp used for stale-command detection |
| `ModifiedBy` | Audit identity |

The notebook writes to `Employees_Native` so it owns the target rather than mutating an externally managed ingestion table.

## Connect Power BI

Configure a Power BI **Data function** button for `EmployeeWriteback2.queue_employee_update` and map the selected employee ID plus the name input. The success message means the command was queued, not that the Delta table was already updated.

Build the report over `Employees_Native`, not the immutable JSON inbox. New values become visible only after the notebook commits the merge and the report's storage mode observes the updated table.

## Command lifecycle

Each invocation creates `Files/writeback/inbox/<requestId>.json` with:

```json
{
  "schemaVersion": 1,
  "requestId": "a generated invocation ID",
  "operation": "UPDATE_EMPLOYEE",
  "employeeId": 1001,
  "employeeName": "Avery Morgan",
  "modifiedBy": "invoking-user@example.com",
  "submittedAtUtc": "an ISO 8601 UTC timestamp"
}
```

The notebook rejects malformed or unknown commands, ignores already-audited request IDs, keeps only the latest command per employee in a run, rejects stale changes, merges eligible updates, and appends outcomes to `Employee_Writeback_Audit`.

## Operate

- Alert on notebook failures and on `REJECTED` outcomes.
- Archive or remove old inbox files after their request IDs are present in the audit table. The sample intentionally leaves them in place for inspection.
- Keep only one merge consumer active. Session high concurrency and capacity queueing do not serialize Delta transactions for you.
- For stronger immediate concurrency, conflict reporting, or cross-table transaction requirements, use the SQL Database pattern.

See [concurrency and limitations](limitations.md) for the failure modes that matter in production.