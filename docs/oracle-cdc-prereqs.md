# Oracle CDC Prerequisites

## 1. Purpose

This document describes the prerequisites for capturing Oracle changes through Debezium and LogMiner.

The exact SQL configuration in:

```text
docker/oracle/initdb/
```

is authoritative.

---

## 2. Oracle Environment

Current Oracle implementation:

```text
Image:
gvenzl/oracle-xe:21-slim

PDB:
XEPDB1

Application schema:
APPUSER
```

The project also uses a Debezium database user for CDC access.

Exact usernames, privileges, and passwords must be taken from the repository configuration rather than guessed.

---

## 3. Archive / Redo Logging

Oracle CDC through LogMiner depends on database logging infrastructure.

The project contains:

```text
01-enable-archivelog.sh
01-enable-archivelog.sql
```

These files are responsible for the relevant archive-log setup.

---

## 4. CDC Configuration

The project contains:

```text
02-configure-cdc.sql
```

and:

```text
05-configure-cdc-lob-logging.sql
```

These files define CDC-related database configuration.

They should be treated as part of the CDC implementation rather than optional setup documentation.

---

## 5. CDB$ROOT vs PDB

Oracle XE uses a multitenant architecture.

Important locations include:

```text
CDB$ROOT
XEPDB1
```

A user existing in one container does not necessarily mean the same user exists or has the same privileges in another container.

Therefore, whenever troubleshooting:

```text
user
schema
table
privilege
```

verify the current Oracle container.

---

## 6. Source Schema

The primary application schema is:

```text
APPUSER
```

The main source table is:

```text
APPUSER.STMT_ENTRY
```

The connector's table include list must match the actual source table.

---

## 7. Table Logging

CDC requires the relevant table changes to be available to the capture mechanism.

For the source table, verify:

```text
table exists
schema is correct
table is included in connector configuration
required logging is enabled
```

For LOB/XML fields, also verify the specialized logging configuration.

---

## 8. Transaction Semantics

A CDC test must distinguish:

```text
DML executed
```

from:

```text
transaction committed
```

For example:

```sql
INSERT INTO ...;

COMMIT;
```

is different from:

```sql
INSERT INTO ...;
```

without commit.

When an event does not appear, verify whether the transaction was committed before investigating downstream systems.

---

## 9. LogMiner Chain

The capture chain is:

```text
Oracle transaction
      ↓
Redo logs
      ↓
Archive logs where applicable
      ↓
LogMiner
      ↓
Debezium
```

A failure anywhere in this chain may prevent a Kafka event from appearing.

---

## 10. Debezium Prerequisites

Before debugging Kafka:

Verify:

```text
Connect is running
Oracle connector exists
connector state is RUNNING
task state is RUNNING
Oracle credentials are valid
Oracle service is reachable
PDB is reachable
source table is included
```

Use the existing scripts under:

```text
docker/connect/scripts/
```

whenever possible.

---

## 11. Source Connector

The Oracle connector configuration is stored under:

```text
docker/connect/connectors/
```

Important configuration includes:

```text
database connection
schema
table include list
topic prefix
capture mode
LogMiner settings
LOB-related settings
```

The actual JSON file is authoritative.

---

## 12. Kafka Validation

Once Debezium is confirmed healthy:

Verify the expected topic.

For the primary Oracle source:

```text
oracle21.APPUSER.STMT_ENTRY
```

Then inspect the raw event.

Do not infer successful CDC merely from connector status.

---

## 13. Minimal Oracle CDC Test

A minimal test should:

```text
1. Insert a unique row.
2. Commit.
3. Verify Debezium receives the change.
4. Verify Kafka receives the event.
5. Verify RisingWave receives the event.
6. Verify the final query result.
```

Then repeat independently for:

```text
UPDATE
DELETE
```

---

## 14. LOB / XML Tests

Do not use only scalar columns when validating Oracle CDC.

Test separately:

```text
scalar INSERT
scalar UPDATE
XML INSERT
XML UPDATE
CLOB INSERT
CLOB UPDATE
BLOB INSERT
BLOB UPDATE
```

Compare the source value with the actual Kafka event.

---

## 15. Troubleshooting Rule

If an event is missing:

```text
Oracle
→ transaction
→ commit
→ redo/archive
→ LogMiner
→ Debezium
→ Kafka
```

must be checked in order.

Do not immediately recreate Kafka topics or RisingWave sources unless the evidence points there.

---

## 16. Verification Principle

A successful connector status means only:

```text
connector/task is operational
```

It does not prove:

```text
DML
→ Kafka
```

is working.

Always perform an actual DML test.
