# CDC_SCB — Project Context

## 1. Purpose

This repository contains a Change Data Capture (CDC) and Streaming ELT proof of concept for Suez Canal Bank.

The project demonstrates how transactional changes can move from Oracle and PostgreSQL into a streaming platform and become queryable analytics data with low latency.

The current Docker implementation is the behavioral reference implementation.

The Kubernetes / Minikube implementation is the deployment target and should preserve the behavior of the Docker implementation unless a change is explicitly required.

---

## 2. Core Architecture

### Oracle CDC path

```text
Oracle XE
   |
   | Database transaction
   v
Redo Logs / Archive Logs
   |
   v
Oracle LogMiner
   |
   v
Debezium Oracle Connector
   |
   v
Kafka
   |
   v
RisingWave
   |
   v
Materialized Views
   |
   v
Superset
```

### PostgreSQL CDC path

```text
PostgreSQL
   |
   v
Debezium PostgreSQL Connector
   |
   v
Kafka
   |
   v
RisingWave
   |
   v
Materialized Views
   |
   v
Superset
```

---

## 3. Repository Structure

```text
CDC_SCB/
│
├── .env
├── .gitignore.txt
├── README.md
│
├── docker/
│   ├── compose/
│   │   └── docker-compose.yml
│   │
│   ├── connect/
│   │   ├── Dockerfile
│   │   ├── connectors/
│   │   ├── drivers/
│   │   └── scripts/
│   │
│   ├── oracle/
│   │   ├── healthcheck/
│   │   └── initdb/
│   │
│   ├── postgres/
│   │   └── initdb/
│   │
│   ├── risingwave/
│   │   ├── README.md
│   │   ├── start-risingwave.sh
│   │   └── sql/
│   │
│   └── superset/
│
├── k8s/
│   ├── namespace.yaml
│   ├── configmaps/
│   ├── connect/
│   ├── kafdrop/
│   ├── kafka/
│   ├── oracle/
│   ├── postgres/
│   ├── risingwave/
│   ├── secrets/
│   └── superset/
│
├── scripts/
│   ├── host/
│   └── sql/
│
└── docs/
```

---

## 4. Docker Is the Reference

Docker Compose represents the currently working implementation.

When migrating a component to Kubernetes:

1. Inspect its Docker implementation.
2. Identify its image.
3. Identify its command / entrypoint.
4. Identify environment variables.
5. Identify ports.
6. Identify volumes.
7. Identify health checks.
8. Identify dependencies.
9. Identify startup ordering.
10. Identify configuration files.
11. Identify initialization scripts.
12. Only then design the Kubernetes equivalent.

Do not redesign the architecture merely because Kubernetes supports a different pattern.

---

## 5. Known Main Components

### Oracle

Current Oracle image:

```text
gvenzl/oracle-xe:21-slim
```

Primary PDB:

```text
XEPDB1
```

Main CDC schema:

```text
APPUSER
```

Main source table:

```text
APPUSER.STMT_ENTRY
```

Relevant columns include:

```text
ENTRY_ID
ACCOUNT_NUMBER
BOOKING_DATE
TXN_CODE
AMOUNT
CURRENCY
TXN_METADATA
AUDIT_TRAIL
DIGITAL_RECEIPT
```

The last three fields may involve XML / CLOB / BLOB behavior and therefore require special CDC validation.

Oracle initialization is represented under:

```text
docker/oracle/initdb/
```

Important initialization files include:

```text
01-enable-archivelog.sh
01-enable-archivelog.sql
02-configure-cdc.sql
03-create-app-schema.sql
04-seed-sample-data.sql
05-configure-cdc-lob-logging.sql
```

---

## 6. Debezium

Debezium Connect image:

```text
quay.io/debezium/connect:3.6
```

Oracle JDBC driver:

```text
ojdbc11.jar
```

Docker driver location:

```text
docker/connect/drivers/
```

Connector configurations:

```text
docker/connect/connectors/
```

Oracle connector configurations include:

```text
oracle-source.json
oracle-source-config-only.json
```

PostgreSQL connector configurations include:

```text
postgres-source.json
postgres-source-config.json
```

Debezium REST API is exposed by the Connect service.

Connector registration and validation scripts are under:

```text
docker/connect/scripts/
```

---

## 7. Kafka

Kafka currently uses:

```text
confluentinc/cp-kafka:7.8.0
```

Kafka is configured using KRaft rather than ZooKeeper.

Known listener roles include:

```text
9092  -> internal Kafka communication
29092 -> external access
9093  -> controller
```

The exact listener configuration must always be taken from the actual Docker/Kubernetes configuration rather than assumed from this document.

---

## 8. Known Kafka Topics

Oracle CDC topic:

```text
oracle21.APPUSER.STMT_ENTRY
```

PostgreSQL CDC topic:

```text
postgres16.public.stmt_entry
```

Topic names must be validated against the actual connector configuration.

Do not rename topics during migration unless explicitly required.

---

## 9. RisingWave

Current version:

```text
v2.0.5
```

Known SQL endpoint:

```text
4566
```

Known HTTP endpoint:

```text
5691
```

RisingWave SQL definitions are under:

```text
docker/risingwave/sql/
```

Important files:

```text
create-source-table.sql
create_cdc_event.sql
create-mviews.sql
validation-queries.sql
```

RisingWave is responsible for streaming SQL processing and materialized views.

Do not assume that every PostgreSQL feature is supported by RisingWave.

---

## 10. PostgreSQL

PostgreSQL is used as an additional CDC source / test path.

Known database:

```text
cdcdb
```

Known table:

```text
public.stmt_entry
```

The PostgreSQL CDC topic is:

```text
postgres16.public.stmt_entry
```

Some PostgreSQL types may need adaptation before being consumed by RisingWave.

For example, `amount` was changed to `DOUBLE PRECISION` in the PostgreSQL CDC path because the previous numeric definition was not supported as required by the RisingWave source.

This behavior should be preserved unless there is a documented reason to change it.

---

## 11. Superset

Superset is the visualization layer.

Docker-specific files:

```text
docker/superset/Dockerfile
docker/superset/requirements.txt
docker/superset/superset_config.py
docker/superset/init/
```

Superset consumes queryable data exposed through RisingWave.

Known historical compatibility issue:

```text
Unable to load columns
```

with logs involving:

```text
pg_catalog.pg_sequence
```

This is a compatibility concern and should not automatically be interpreted as a CDC failure.

---

## 12. CDC Debugging Chain

When a CDC result is missing or incorrect, debug in this order:

```text
Oracle transaction
        ↓
Redo / Archive Logs
        ↓
LogMiner
        ↓
Debezium
        ↓
Kafka topic
        ↓
Kafka message
        ↓
RisingWave source
        ↓
RisingWave transformation
        ↓
Materialized View
        ↓
Superset
```

Never skip directly to the last layer.

---

## 13. LOB / XML Behavior

The project contains Oracle data types that require special CDC handling:

```text
SYS.XMLTYPE
CLOB
BLOB
```

Known Debezium behavior may include:

```text
__debezium_unavailable_value
```

especially when LOB/XML data is updated and the required value is not available in the emitted event.

XML redo operations may also appear as lower-level operations such as:

```text
DOC BEGIN
DOC WRITE
DOC END
```

These are not necessarily application-level row events.

Always distinguish:

1. Oracle redo behavior
2. LogMiner behavior
3. Debezium event behavior
4. Kafka payload
5. RisingWave parsing

---

## 14. Timestamp Semantics

The project performs CDC latency benchmarking.

Different timestamps represent different events.

Examples include:

```text
Oracle commit timestamp
Debezium source timestamp
Kafka / downstream arrival timestamp
RisingWave processing timestamp
```

Do not calculate latency by blindly subtracting timestamps with different meanings.

Every latency metric must document:

```text
start event
end event
timestamp source
time unit
timezone assumptions
```

---

## 15. Kubernetes Target

The Kubernetes implementation lives under:

```text
k8s/
```

Target environment:

```text
Minikube
```

The goal is:

```text
same project behavior
+
Kubernetes deployment
+
Minikube compatibility
```

not:

```text
new architecture
```

unless explicitly requested.

---

## 16. Kubernetes Component Mapping

Expected high-level mapping:

```text
Docker Compose service
        ↓
Kubernetes workload
        ↓
Service
        ↓
ConfigMap / Secret
        ↓
PersistentVolumeClaim where persistence is required
```

Current Kubernetes structure:

```text
k8s/oracle/
k8s/kafka/
k8s/connect/
k8s/risingwave/
k8s/postgres/
k8s/superset/
k8s/kafdrop/
```

---

## 17. Configuration Ownership

Use:

```text
ConfigMap
```

for non-sensitive configuration.

Use:

```text
Secret
```

for passwords, credentials, and other sensitive values.

Never commit real credentials into Kubernetes manifests.

The repository's `.env` file and existing secret-related configuration must be inspected before introducing new secret mechanisms.

---

## 18. Claude Code Working Contract

Before making a meaningful change, Claude must explain:

### What

What exactly will be changed?

### Why

Why is the change necessary?

### Goal

What specific result should the change achieve?

### Files

Which files will be created, modified, or deleted?

### Relationships

How are those files connected to the rest of the project?

### Validation

How will the change be verified?

Example:

```text
I will modify k8s/kafka/service.yaml.

Why:
Debezium needs a stable Kubernetes DNS endpoint to reach Kafka.

Goal:
Allow the Debezium Connect pod to resolve and connect to Kafka internally.

Related files:
- k8s/kafka/statefulset.yaml
- k8s/connect/deployment.yaml
- k8s/connect/service.yaml

Validation:
I will verify Service endpoints, DNS resolution, broker connectivity,
and then publish a CDC event and confirm it reaches Kafka.
```

---

## 19. Code Comment Contract

Before a meaningful block of code/configuration, Claude should add a short comment explaining its purpose when the purpose is not already obvious.

Good:

```yaml
# Expose Kafka's internal listener to CDC components inside the cluster.
ports:
  - name: internal
    port: 9092
```

Bad:

```yaml
# This is a port.
port: 9092
```

Do not add comments to every line.

Comments should explain:

```text
purpose
reason
non-obvious dependency
important constraint
```

---

## 20. Change Discipline

Prefer:

```text
small change
→ validate
→ next change
```

over:

```text
change everything
→ deploy
→ debug everything simultaneously
```

For troubleshooting, isolate one component whenever possible.

---

## 21. Definition of Done

A change is not considered complete merely because:

```text
kubectl apply
```

succeeds.

The relevant behavior must be verified.

For CDC components this normally means validating:

```text
pod health
service connectivity
configuration
source connectivity
event production
event transport
event consumption
data correctness
```

For end-to-end CDC:

```text
Oracle DML
→ Debezium
→ Kafka
→ RisingWave
→ Materialized View
```

must be verified.

---

## 22. Source of Truth Priority

When information conflicts, use this priority:

1. Actual working Docker configuration
2. Existing working scripts
3. Existing SQL/configuration files
4. Existing verification results
5. Project documentation
6. General assumptions

Do not overwrite working behavior based on generic Kubernetes best practices without evidence.

---

## 23. Unknown Information

If an important implementation detail is unknown:

Do not guess.

Instead:

1. identify the missing information;
2. tell the user why it matters;
3. identify which file or command can provide it;
4. request or inspect that evidence;
5. continue only after the ambiguity is resolved.

---

## 24. Git Safety

There are two conceptual remotes:

```text
origin -> team repository
mine   -> personal repository
```

Do not modify, push to, force-push, reset, or delete anything on `origin` unless explicitly requested.

When Git operations are requested, verify:

```text
current branch
current remote
target branch
working tree
```

before executing destructive or remote-changing operations.
