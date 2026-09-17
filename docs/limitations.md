# Concurrency and limitations

## Lakehouse concurrency

Fabric Delta tables use optimistic concurrency control with Serializable isolation. A transaction reads a snapshot, prepares files, and validates at commit time. Conflicting writes fail rather than corrupting the table.

| Workload pair | Expected behavior |
| --- | --- |
| UDF command file + UDF command file | Independent file creates are append-only and normally do not conflict |
| Blind Delta append + blind Delta append | Normally does not conflict |
| Overlapping `MERGE`, `UPDATE`, or `DELETE` | Can conflict when operations read or rewrite the same files |
| `OPTIMIZE` + data-changing DML | Can conflict when both touch the same files |

For this sample, **run one processing notebook at a time**. Two overlapping runs can read the same unaudited commands and target the same Delta files. One can then fail with a Delta concurrent-write exception, and duplicate or misleading audit attempts are possible.

The merge into `Employees_Native` and append to `Employee_Writeback_Audit` are two separate Delta transactions. Delta does not make those two table commits atomic as a unit. If the merge succeeds but the audit append fails, a retry sees the newer target timestamp and can classify that command as stale instead of applied. This is acceptable for a demo, but not a substitute for a transactional database when exact cross-object audit semantics are required.

### Scale-out options

1. Keep UDF ingestion parallel and append-only, then serialize the merge consumer.
2. If business domains are physically partitioned, constrain every writer and its merge predicate to a disjoint partition.
3. Retry known transient concurrency exceptions with bounded exponential backoff. Do not retry validation or authorization failures.
4. Schedule `OPTIMIZE` and other maintenance outside the merge window.
5. Move interactive or strongly consistent writeback to Fabric SQL Database.

Spark capacity admission is separate from Delta transaction safety. Fabric can queue scheduled or pipeline-triggered jobs when Spark capacity is full, but interactive and public-API notebook runs are not queued. A job starting successfully does not mean another writer cannot conflict with it later.

## Lakehouse behavior limits

- The report receives a queue acknowledgement, not a committed row update.
- End-to-end latency includes the notebook schedule, Spark startup, merge duration, SQL analytics endpoint metadata/data visibility, and report refresh semantics.
- A Lakehouse UDF can write files, but its SQL analytics endpoint connection is read-only.
- Inbox files accumulate until a retention or archive process is added.
- Last-write-wins ordering depends on trusted UTC timestamps. For hostile or highly regulated inputs, assign ordering in a controlled service rather than trusting client-adjacent timing.
- Partitioning only reduces conflicts when the partition column also appears in each DML predicate.

## UDF service limits

Current Microsoft Learn limits include:

| Limit | Value |
| --- | --- |
| Request payload | 4 MB |
| Function execution | 240 seconds |
| Public endpoint execution | 100 seconds |
| Response | 30 MB |
| Invocation log retention | 30 days |
| Published runtime | Python 3.11 |

Only the item owner can currently edit and publish a UDF, and a two-minute cooldown applies after publishing. Managed UDF connections currently do not support service principal, managed identity, or workspace identity access to connected data sources. Verify regional availability and the live limits page before deployment.

## Power BI deployment limits

- A function must return `str` to be available to a data function button.
- Data function buttons retain an explicit workspace, function set, and function reference. They do not automatically rebind when a report moves to another workspace.
- Rebind each button in the destination report after Git or deployment-pipeline promotion.
- Treat semantic-model RLS and write authorization as separate controls.

See [Microsoft Learn references](microsoft-learn.md) for the source documentation and current details.