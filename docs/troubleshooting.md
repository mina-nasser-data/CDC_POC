# CDC_SCB Troubleshooting Guide

## 1. Core Principle

Debug from upstream to downstream.

Never assume that the last component showing an error is the root cause.

Use:

```text
Oracle
 ↓
LogMiner
 ↓
Debezium
 ↓
Kafka
 ↓
RisingWave
 ↓
Materialized View
 ↓
Superset
```

---

## 2. First Question

Before changing anything ask:

```text
What exact behavior is failing?
```

Examples:

```text
No Kafka event
Wrong Kafka value
No RisingWave row
Wrong RisingWave value
Superset cannot load columns
High latency
Pod cannot start
Service cannot connect
```

---

## 3. Component Isolation

Only investigate one boundary at a time.

Example:

```text
Oracle → Debezium
```

First establish that this works.

Then:

```text
Debezium → Kafka
```

Then:

```text
Kafka → RisingWave
```

Then:

```text
RisingWave → Superset
```

---

## 4. Oracle Problems

Check:

```text
database is running
PDB is available
schema exists
table exists
DML executed
transaction committed
required logging enabled
```

Do not proceed downstream until the source behavior is established.

---

## 5. Debezium Problems

Check:

```text
Connect pod/container
connector configuration
connector status
task status
database connectivity
table include list
topic prefix
connector logs
```

A connector can be:

```text
RUNNING
```

while the expected data is still not appearing.

Therefore perform a real DML test.

---

## 6. Kafka Problems

Check in this order:

```text
broker running
↓
listeners
↓
advertised listeners
↓
DNS
↓
TCP connectivity
↓
topic existence
↓
producer
↓
consumer
↓
message contents
```

For Kubernetes, advertised listeners are especially important.

---

## 7. RisingWave Problems

Check:

```text
RisingWave service
source exists
source schema
Kafka bootstrap server
Kafka topic
message format
column mapping
data types
SQL compatibility
materialized view
```

Do not debug a materialized view until the source is receiving the expected data.

---

## 8. Superset Problems

If Superset reports:

```text
Unable to load columns
```

first query RisingWave directly.

If RisingWave returns the correct result:

```text
CDC pipeline may be healthy
```

and the issue may be Superset / PostgreSQL compatibility.

Known historical issue:

```text
pg_catalog.pg_sequence
```

appeared in Superset-related logs.

This should be treated as a separate compatibility layer.

---

## 9. Kubernetes Pod Not Starting

Check:

```text
kubectl get pods
kubectl describe pod <pod>
kubectl logs <pod>
```

Then identify whether the issue is:

```text
image
command
environment
volume
permission
probe
dependency
resource
```

Do not modify the manifest before identifying the failure category.

---

## 10. Kubernetes Service Problem

Check:

```text
Service exists
Endpoints exist
Pod labels match selector
Target port is correct
Port is listening
DNS resolves
```

A Service existing does not prove that traffic reaches the intended pod.

---

## 11. Persistent Storage Problems

Check:

```text
PVC status
PV binding
mount path
filesystem permissions
container user
existing data
```

Never delete a PVC as a first troubleshooting step.

That can destroy the evidence or state required to diagnose the problem.

---

## 12. Configuration Problems

When behavior differs between Docker and Kubernetes, compare:

```text
image
command
entrypoint
environment
ports
volumes
configuration files
startup scripts
health checks
network addresses
```

---

## 13. Latency Problems

Define the metric first.

Example:

```text
latency =
RisingWave arrival time
-
Oracle commit time
```

Then verify:

```text
both timestamps use same time basis
both are in same unit
clock skew is understood
timestamp semantics are documented
```

Do not compare arbitrary timestamps.

---

## 14. Common Debugging Mistakes

Avoid:

```text
restarting everything
deleting volumes
recreating topics
changing multiple YAML files
changing source schema and consumer schema simultaneously
```

without evidence.

These actions can hide the original problem.

---

## 15. Evidence Collection

Before changing configuration collect:

```text
current configuration
pod status
logs
connector status
topic name
raw Kafka message
RisingWave source definition
query result
```

Then form a hypothesis.

---

## 16. Hypothesis Format

Use:

```text
Observation:
<what was observed>

Hypothesis:
<what may explain it>

Evidence needed:
<what must be checked>

Change:
<minimal change>

Validation:
<how success will be measured>
```

---

## 17. Stop Conditions

Stop and ask the user before continuing when:

```text
credentials are required
data may be deleted
PVCs may be removed
Git history may be rewritten
architecture must change
production behavior may be affected
the root cause is ambiguous
```
