from datetime import datetime, timezone

from pyspark.sql import types as T


schema = T.StructType(
    [
        T.StructField("EmployeeID", T.IntegerType(), False),
        T.StructField("EmployeeName", T.StringType(), False),
        T.StructField("LastModifiedDate", T.TimestampType(), False),
        T.StructField("ModifiedBy", T.StringType(), False),
    ]
)

seeded_at = datetime.now(timezone.utc).replace(tzinfo=None)
employees = spark.createDataFrame(
    [
        (1001, "Avery Morgan", seeded_at, "seed"),
        (1002, "Jordan Lee", seeded_at, "seed"),
        (1003, "Riley Patel", seeded_at, "seed"),
    ],
    schema,
)

employees.write.format("delta").mode("overwrite").saveAsTable("Employees")
display(spark.table("Employees").orderBy("EmployeeID"))