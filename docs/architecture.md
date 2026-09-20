# CDC_SCB Architecture

## 1. Overview

The CDC_SCB project demonstrates a streaming data pipeline that captures database changes and makes them available for downstream streaming processing and analytics.

The primary architecture is:

```text
Oracle
  ↓
Redo / Archive Logs
  ↓
LogMiner
  ↓
Debezium
  ↓
Kafka
  ↓
RisingWave
  ↓
Materialized Views
  ↓
Superset
```

A PostgreSQL CDC path is also available:

```text
PostgreSQL
  ↓
Debezium
  ↓
Kafka
  ↓
RisingWave
  ↓
Materialized Views
  ↓
Superset
```

---

## 2. Why CDC

Traditional batch pipelines repeatedly read a source table:

```text
Source DB
   ↓
Periodic query
   ↓
Extract
   ↓
Transform
   ↓
Load
```

CDC instead captures changes as they happen:

```text
INSERT
UPDATE
DELETE
   ↓
Change event
   ↓
Streaming pipeline
```

This reduces the need to repeatedly scan the entire source dataset and enables lower-latency downstream processing.

---

## 3. Oracle CDC Flow

Oracle records transactional changes in redo information.

The CDC flow is:

```text
Application Transaction
        ↓
Oracle Database
        ↓
Redo / Archive Logs
        ↓
Oracle LogMiner
        ↓
Debezium Oracle Connector
        ↓
Kafka Topic
        ↓
RisingWave
```

The application does not directly send the database row to Kafka.

The CDC connector derives the change from Oracle's transaction/logging mechanisms.

---

## 4. Debezium's Role

Debezium acts as the CDC capture layer.

Its responsibilities include:

* connecting to the source database;
* reading database change information;
* interpreting changes;
* generating CDC events;
* publishing events to Kafka.

The connector must therefore be considered part of the database capture mechanism rather than simply a generic Kafka producer.

---

## 5. Kafka's Role

Kafka provides the event transport layer.

Conceptually:

```text
Debezium
   ↓
Kafka Producer
   ↓
Kafka Topic
   ↓
RisingWave Consumer
```

Kafka decouples the producer and consumer.

This allows:

* buffering;
* replay through offsets;
* independent consumer processing;
* asynchronous downstream systems.

---

## 6. RisingWave's Role

RisingWave consumes streaming data and performs streaming SQL processing.

It can maintain:

```text
Sources
   ↓
Streaming transformations
   ↓
Materialized Views
```

This allows downstream applications such as Superset to query continuously maintained results rather than repeatedly recomputing the same transformations.

---

## 7. Superset's Role

Superset is the visualization and analytics interface.

It is not part of the CDC capture mechanism.

Therefore:

```text
Superset failure
≠
CDC pipeline failure
```

A CDC pipeline should be validated independently of Superset.

---

## 8. Kubernetes Architecture

The Minikube implementation maps the same logical architecture to Kubernetes:

```text
Namespace
│
├── Oracle StatefulSet
│      └── Oracle Service
│
├── Kafka StatefulSet
│      └── Kafka Service
│
├── Debezium Connect Deployment
│      └── Connect Service
│
├── RisingWave StatefulSet
│      └── RisingWave Service
│
├── PostgreSQL StatefulSet
│      └── PostgreSQL Service
│
├── Superset Deployment
│      └── Superset Service
│
└── Kafdrop Deployment
       └── Kafdrop Service
```

Persistent components use PVCs where required.

Configuration is separated into:

```text
ConfigMaps
Secrets
```

---

## 9. Docker → Kubernetes Principle

Docker Compose describes:

```text
container
environment
port
volume
dependency
health
```

Kubernetes represents these using:

```text
Pod
Deployment / StatefulSet
Service
ConfigMap
Secret
PersistentVolumeClaim
Probes
```

The migration should preserve behavior rather than simply translate YAML syntax.

---

## 10. Important Dependency Chain

The most important runtime dependency chain is:

```text
Oracle
 ↓
Kafka connectivity
 ↓
Debezium
 ↓
Kafka topic
 ↓
RisingWave source
 ↓
Materialized View
```

If a downstream component fails, do not immediately modify it.

First verify the upstream component.

---

## 11. End-to-End Event

A successful INSERT should conceptually follow:

```text
INSERT INTO Oracle
        ↓
Oracle transaction commits
        ↓
Redo information
        ↓
LogMiner
        ↓
Debezium event
        ↓
Kafka topic
        ↓
RisingWave source
        ↓
Materialized View
        ↓
Query result
```

UPDATE and DELETE must be validated separately because their CDC semantics differ.

---

## 12. Architecture Changes

Any architectural change must explicitly document:

```text
current behavior
reason for change
expected benefit
affected components
affected files
compatibility impact
validation method
```

Do not introduce architectural changes merely to make Kubernetes manifests look cleaner.
