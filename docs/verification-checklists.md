# CDC_SCB Verification Checklists

## 1. Purpose

This document defines verification procedures for the CDC pipeline and its Kubernetes migration.

A deployment is not considered successful merely because containers or pods are running.

Behavior must be verified.

---

# 2. Docker Baseline

Before using Kubernetes as a target, confirm Docker behavior.

### Infrastructure

* [ ] Oracle is healthy
* [ ] Kafka is healthy
* [ ] Debezium Connect is healthy
* [ ] RisingWave is healthy
* [ ] PostgreSQL is healthy if used
* [ ] Superset is healthy if used

### CDC

* [ ] Oracle INSERT captured
* [ ] Oracle UPDATE captured
* [ ] Oracle DELETE captured
* [ ] PostgreSQL CDC works if enabled

### Data

* [ ] scalar values are correct
* [ ] timestamps are correct
* [ ] XML behavior is understood
* [ ] CLOB behavior is understood
* [ ] BLOB behavior is understood

---

# 3. Kubernetes Infrastructure

### Namespace

* [ ] namespace exists
* [ ] all resources deployed into intended namespace

### Oracle

* [ ] StatefulSet exists
* [ ] Pod is Ready
* [ ] Service exists
* [ ] PVC is Bound
* [ ] Oracle PDB is accessible

### Kafka

* [ ] StatefulSet exists
* [ ] Pod is Ready
* [ ] PVC is Bound if required
* [ ] Service exists
* [ ] listeners are correct
* [ ] advertised listeners are reachable

### Debezium

* [ ] Deployment exists
* [ ] Pod is Ready
* [ ] Service exists
* [ ] Oracle driver is available
* [ ] connector configuration is available

### RisingWave

* [ ] StatefulSet exists
* [ ] Pod is Ready
* [ ] Service exists
* [ ] SQL endpoint is reachable

### PostgreSQL

* [ ] StatefulSet exists
* [ ] Pod is Ready
* [ ] PVC is Bound if required
* [ ] Service is reachable

### Superset

* [ ] Deployment exists
* [ ] Pod is Ready
* [ ] Service exists
* [ ] initialization completed

---

# 4. Debezium Verification

Check:

```text
connector status
task status
connector logs
```

Then perform:

```text
INSERT
COMMIT
```

Verify:

```text
Kafka topic receives event
```

Repeat for:

```text
UPDATE
DELETE
```

---

# 5. Kafka Verification

For each CDC source:

* [ ] expected topic exists
* [ ] topic name is correct
* [ ] producer can publish
* [ ] consumer can consume
* [ ] message key is correct
* [ ] message payload is correct
* [ ] operation field is correct
* [ ] source metadata is present
* [ ] timestamps are interpretable

---

# 6. RisingWave Verification

* [ ] source exists
* [ ] source points to expected Kafka topic
* [ ] bootstrap address is correct
* [ ] source schema matches payload
* [ ] values are parsed correctly
* [ ] transformations work
* [ ] materialized view exists
* [ ] materialized view updates after CDC events

---

# 7. End-to-End INSERT

```text
1. Insert unique row into Oracle.
2. Commit.
3. Confirm row exists in Oracle.
4. Confirm Debezium is running.
5. Confirm Kafka event exists.
6. Confirm RisingWave source receives event.
7. Confirm materialized view updates.
8. Query final result.
```

Expected:

```text
Oracle row
=
CDC event
=
RisingWave result
```

for fields whose semantics are expected to be preserved.

---

# 8. End-to-End UPDATE

```text
1. Select an existing unique row.
2. Update a scalar field.
3. Commit.
4. Verify Kafka event.
5. Verify RisingWave.
6. Verify materialized view.
```

Then separately test:

```text
XML
CLOB
BLOB
```

updates.

---

# 9. End-to-End DELETE

```text
1. Select a test row.
2. Delete it.
3. Commit.
4. Verify DELETE event.
5. Verify RisingWave state.
6. Verify final materialized view.
```

---

# 10. LOB Verification

Test independently:

* [ ] XML INSERT
* [ ] XML UPDATE
* [ ] XML DELETE
* [ ] CLOB INSERT
* [ ] CLOB UPDATE
* [ ] CLOB DELETE
* [ ] BLOB INSERT
* [ ] BLOB UPDATE
* [ ] BLOB DELETE

Record whether the event contains:

```text
actual value
NULL
__debezium_unavailable_value
```

Do not classify the result without identifying the layer responsible.

---

# 11. Latency Verification

Define:

```text
start timestamp
end timestamp
```

Example:

```text
Oracle commit timestamp
        ↓
RisingWave arrival timestamp
```

Then calculate:

```text
latency_ms =
arrival_timestamp_ms
-
commit_timestamp_ms
```

Verify:

* [ ] timestamps use the same time basis
* [ ] units are milliseconds
* [ ] timezone assumptions are documented
* [ ] clock skew is understood
* [ ] multiple samples are collected

---

# 12. Docker vs Kubernetes Behavioral Comparison

For the same test:

```text
Docker result
vs
Kubernetes result
```

Compare:

```text
event existence
payload
operation
timestamps
data values
latency
```

The migration is successful when the Kubernetes implementation reproduces the intended Docker behavior.

---

# 13. Final Definition of Done

### Infrastructure

* [ ] all required pods healthy
* [ ] services reachable
* [ ] persistent storage working
* [ ] configuration loaded correctly
* [ ] secrets handled correctly

### CDC

* [ ] INSERT works
* [ ] UPDATE works
* [ ] DELETE works

### Data

* [ ] scalar fields correct
* [ ] timestamps correct
* [ ] XML behavior verified
* [ ] CLOB behavior verified
* [ ] BLOB behavior verified

### Streaming

* [ ] Kafka topics correct
* [ ] Kafka events correct
* [ ] RisingWave sources correct
* [ ] materialized views update correctly

### Analytics

* [ ] Superset can query intended data
* [ ] known compatibility issues are documented

### Documentation

* [ ] implementation changes documented
* [ ] validation results recorded
* [ ] known limitations recorded
