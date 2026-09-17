# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   }
# META }

# MARKDOWN ********************

# # Apply Employee Lakehouse Writeback
#
# This notebook consumes immutable commands from `Files/writeback/inbox`,
# validates and deduplicates them, and applies eligible changes to an owned
# Delta table. Configure the scheduler or pipeline so only one run is active.
#
# **Flow:** inbox -> validation and idempotency -> `Employees_Native` -> audit

# CELL ********************

from delta.tables import DeltaTable
from pyspark.sql import DataFrame, Window
from pyspark.sql import functions as F
from pyspark.sql import types as T

INBOX_PATH = "Files/writeback/inbox"
SOURCE_TABLE = "Employees"
TARGET_TABLE = "Employees_Native"
AUDIT_TABLE = "Employee_Writeback_Audit"

context = notebookutils.runtime.context
default_lakehouse_name = context.get("defaultLakehouseName")
if not default_lakehouse_name:
    raise RuntimeError("Attach a default Lakehouse before running this notebook.")

notebook_run_id = (
    context.get("currentRunId")
    or context.get("activityId")
    or "interactive"
)

print(f"Using attached Lakehouse: {default_lakehouse_name}")
print(f"Notebook run ID: {notebook_run_id}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

EMPLOYEE_COLUMNS = {
    "EmployeeID",
    "EmployeeName",
    "LastModifiedDate",
    "ModifiedBy",
}

AUDIT_SCHEMA = T.StructType(
    [
        T.StructField("requestId", T.StringType(), False),
        T.StructField("employeeId", T.IntegerType(), True),
        T.StructField("operation", T.StringType(), True),
        T.StructField("status", T.StringType(), False),
        T.StructField("reason", T.StringType(), True),
        T.StructField("modifiedBy", T.StringType(), True),
        T.StructField("submittedAtUtc", T.TimestampType(), True),
        T.StructField("processedAtUtc", T.TimestampType(), False),
        T.StructField("sourceFile", T.StringType(), True),
        T.StructField("notebookRunId", T.StringType(), False),
    ]
)


def require_columns(
    dataframe: DataFrame,
    required: set[str],
    table_name: str,
) -> None:
    missing = sorted(required.difference(dataframe.columns))
    if missing:
        raise RuntimeError(
            f"Lakehouse table {table_name} is missing columns: {', '.join(missing)}"
        )


if not spark.catalog.tableExists(SOURCE_TABLE):
    raise RuntimeError(
        f"The attached Lakehouse must expose the source table {SOURCE_TABLE}."
    )

source_employees = spark.table(SOURCE_TABLE)
require_columns(source_employees, EMPLOYEE_COLUMNS, SOURCE_TABLE)

if not spark.catalog.tableExists(TARGET_TABLE):
    latest_source_employees = (
        source_employees.select(
            F.col("EmployeeID").cast("int").alias("EmployeeID"),
            F.trim(F.col("EmployeeName")).cast("string").alias("EmployeeName"),
            F.col("LastModifiedDate").cast("timestamp").alias("LastModifiedDate"),
            F.col("ModifiedBy").cast("string").alias("ModifiedBy"),
        )
        .withColumn(
            "_sourceRank",
            F.row_number().over(
                Window.partitionBy("EmployeeID").orderBy(
                    F.col("LastModifiedDate").desc_nulls_last()
                )
            ),
        )
        .filter(F.col("_sourceRank") == 1)
        .drop("_sourceRank")
    )
    (
        latest_source_employees.write.format("delta")
        .mode("errorifexists")
        .saveAsTable(TARGET_TABLE)
    )
    print(f"Created owned Delta table {TARGET_TABLE} from {SOURCE_TABLE}.")
else:
    require_columns(spark.table(TARGET_TABLE), EMPLOYEE_COLUMNS, TARGET_TABLE)
    DeltaTable.forName(spark, TARGET_TABLE)
    print(f"Using existing owned Delta table {TARGET_TABLE}.")

if not spark.catalog.tableExists(AUDIT_TABLE):
    (
        spark.createDataFrame([], AUDIT_SCHEMA)
        .write.format("delta")
        .mode("errorifexists")
        .saveAsTable(AUDIT_TABLE)
    )
    print(f"Created audit Delta table {AUDIT_TABLE}.")
else:
    require_columns(
        spark.table(AUDIT_TABLE),
        {field.name for field in AUDIT_SCHEMA.fields},
        AUDIT_TABLE,
    )

notebookutils.fs.mkdirs(INBOX_PATH)
print(f"Command inbox is ready at {INBOX_PATH}.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

COMMAND_SCHEMA = T.StructType(
    [
        T.StructField("schemaVersion", T.IntegerType(), True),
        T.StructField("requestId", T.StringType(), True),
        T.StructField("operation", T.StringType(), True),
        T.StructField("employeeId", T.IntegerType(), True),
        T.StructField("employeeName", T.StringType(), True),
        T.StructField("modifiedBy", T.StringType(), True),
        T.StructField("submittedAtUtc", T.StringType(), True),
        T.StructField("_corruptRecord", T.StringType(), True),
    ]
)

command_files = sorted(
    item.path
    for item in notebookutils.fs.ls(INBOX_PATH)
    if not item.isDir and item.name.lower().endswith(".json")
)

if command_files:
    raw_commands = (
        spark.read.option("columnNameOfCorruptRecord", "_corruptRecord")
        .schema(COMMAND_SCHEMA)
        .json(command_files)
        .withColumn("sourceFile", F.input_file_name())
    )
else:
    raw_commands = spark.createDataFrame(
        [],
        COMMAND_SCHEMA.add(T.StructField("sourceFile", T.StringType(), True)),
    )

commands = (
    raw_commands.withColumn(
        "requestId",
        F.when(
            F.length(F.trim(F.col("requestId"))) > 0,
            F.trim(F.col("requestId")),
        ).otherwise(
            F.sha2(
                F.concat_ws(
                    "|",
                    F.col("sourceFile"),
                    F.coalesce(F.col("_corruptRecord"), F.lit("")),
                ),
                256,
            )
        ),
    )
    .withColumn("operation", F.upper(F.trim(F.col("operation"))))
    .withColumn("employeeName", F.trim(F.col("employeeName")))
    .withColumn("modifiedBy", F.trim(F.col("modifiedBy")))
    .withColumn("submittedAtUtc", F.to_timestamp(F.col("submittedAtUtc")))
)

print(f"Discovered {len(command_files)} command file(s).")
display(
    commands.select(
        "requestId",
        "operation",
        "employeeId",
        "employeeName",
        "modifiedBy",
        "submittedAtUtc",
        "sourceFile",
    ).orderBy(F.col("submittedAtUtc").desc_nulls_last())
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

REQUEST_ID_PATTERN = (
    r"(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-"
    r"[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
)

processed_request_ids = spark.table(AUDIT_TABLE).select("requestId").distinct()

unprocessed_commands = (
    commands.join(processed_request_ids, on="requestId", how="left_anti")
    .withColumn(
        "_requestRank",
        F.row_number().over(
            Window.partitionBy("requestId").orderBy(
                F.col("submittedAtUtc").desc_nulls_last(),
                F.col("sourceFile").desc(),
            )
        ),
    )
    .filter(F.col("_requestRank") == 1)
    .drop("_requestRank")
)

validated_commands = unprocessed_commands.withColumn(
    "validationReason",
    F.when(F.col("_corruptRecord").isNotNull(), "Malformed JSON command")
    .when(~F.col("requestId").rlike(REQUEST_ID_PATTERN), "requestId must be a GUID")
    .when(
        F.col("schemaVersion").isNull() | (F.col("schemaVersion") != 1),
        "Unsupported schemaVersion",
    )
    .when(
        F.col("operation").isNull() | (F.col("operation") != "UPDATE_EMPLOYEE"),
        "Unsupported operation",
    )
    .when(
        F.col("employeeId").isNull() | (F.col("employeeId") <= 0),
        "employeeId must be greater than zero",
    )
    .when(
        F.col("employeeName").isNull() | (F.length(F.col("employeeName")) == 0),
        "employeeName is required",
    )
    .when(F.length(F.col("employeeName")) > 200, "employeeName is too long")
    .when(
        F.col("modifiedBy").isNull() | (F.length(F.col("modifiedBy")) == 0),
        "modifiedBy is required",
    )
    .when(F.length(F.col("modifiedBy")) > 256, "modifiedBy is too long")
    .when(F.col("submittedAtUtc").isNull(), "submittedAtUtc is invalid"),
)

invalid_commands = validated_commands.filter(F.col("validationReason").isNotNull())
valid_commands = validated_commands.filter(F.col("validationReason").isNull())

target_state = spark.table(TARGET_TABLE).select(
    F.col("EmployeeID").alias("targetEmployeeId"),
    F.col("LastModifiedDate").alias("currentLastModifiedDate"),
)

matched_commands = valid_commands.join(
    target_state,
    valid_commands.employeeId == target_state.targetEmployeeId,
    "left",
)

unknown_employee_commands = matched_commands.filter(
    F.col("targetEmployeeId").isNull()
)
known_employee_commands = matched_commands.filter(
    F.col("targetEmployeeId").isNotNull()
).drop("targetEmployeeId")

ranked_employee_commands = known_employee_commands.withColumn(
    "_employeeRank",
    F.row_number().over(
        Window.partitionBy("employeeId").orderBy(
            F.col("submittedAtUtc").desc(),
            F.col("requestId").desc(),
        )
    ),
)

superseded_commands = ranked_employee_commands.filter(F.col("_employeeRank") > 1)
latest_employee_commands = ranked_employee_commands.filter(
    F.col("_employeeRank") == 1
).drop("_employeeRank")

stale_commands = latest_employee_commands.filter(
    F.col("currentLastModifiedDate").isNotNull()
    & (F.col("submittedAtUtc") <= F.col("currentLastModifiedDate"))
)
commands_to_apply = (
    latest_employee_commands.filter(
        F.col("currentLastModifiedDate").isNull()
        | (F.col("submittedAtUtc") > F.col("currentLastModifiedDate"))
    )
    .drop("currentLastModifiedDate")
    .localCheckpoint(eager=True)
)


def build_audit_rows(dataframe, status, reason_column):
    return dataframe.select(
        F.col("requestId").cast("string").alias("requestId"),
        F.col("employeeId").cast("int").alias("employeeId"),
        F.col("operation").cast("string").alias("operation"),
        F.lit(status).alias("status"),
        reason_column.cast("string").alias("reason"),
        F.col("modifiedBy").cast("string").alias("modifiedBy"),
        F.col("submittedAtUtc").cast("timestamp").alias("submittedAtUtc"),
        F.current_timestamp().alias("processedAtUtc"),
        F.col("sourceFile").cast("string").alias("sourceFile"),
        F.lit(notebook_run_id).alias("notebookRunId"),
    )


audit_rows_to_write = (
    build_audit_rows(invalid_commands, "REJECTED", F.col("validationReason"))
    .unionByName(
        build_audit_rows(
            unknown_employee_commands,
            "REJECTED",
            F.lit("employeeId does not exist in the target table"),
        )
    )
    .unionByName(
        build_audit_rows(
            superseded_commands,
            "SUPERSEDED",
            F.lit("A newer command for this employee was selected"),
        )
    )
    .unionByName(
        build_audit_rows(
            stale_commands,
            "STALE",
            F.lit("The target already contains the same or a newer change"),
        )
    )
    .unionByName(
        build_audit_rows(
            commands_to_apply,
            "APPLIED",
            F.lit(None).cast("string"),
        )
    )
    .localCheckpoint(eager=True)
)

run_summary = {
    row["status"]: row["count"]
    for row in audit_rows_to_write.groupBy("status").count().collect()
}
audit_count = sum(run_summary.values())
apply_count = run_summary.get("APPLIED", 0)

if apply_count:
    (
        DeltaTable.forName(spark, TARGET_TABLE)
        .alias("target")
        .merge(
            commands_to_apply.alias("source"),
            "target.EmployeeID = source.employeeId",
        )
        .whenMatchedUpdate(
            set={
                "EmployeeName": "source.employeeName",
                "LastModifiedDate": "source.submittedAtUtc",
                "ModifiedBy": "source.modifiedBy",
            }
        )
        .execute()
    )

if audit_count:
    (
        audit_rows_to_write.write.format("delta")
        .mode("append")
        .saveAsTable(AUDIT_TABLE)
    )

commands_to_apply.unpersist()
audit_rows_to_write.unpersist()

print(
    {
        "commandFiles": len(command_files),
        "newRequests": audit_count,
        "applied": run_summary.get("APPLIED", 0),
        "rejected": run_summary.get("REJECTED", 0),
        "superseded": run_summary.get("SUPERSEDED", 0),
        "stale": run_summary.get("STALE", 0),
    }
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## Verify the writeback
#
# Re-running the processing cell does not apply an audited `requestId` again.

# CELL ********************

current_employees = spark.table(TARGET_TABLE).orderBy("EmployeeID")
recent_writeback_activity = (
    spark.table(AUDIT_TABLE)
    .orderBy(F.col("processedAtUtc").desc())
    .limit(100)
)

print(f"Current rows in {TARGET_TABLE}: {current_employees.count()}")
display(current_employees)

print(f"Most recent outcomes from {AUDIT_TABLE}:")
display(recent_writeback_activity)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }