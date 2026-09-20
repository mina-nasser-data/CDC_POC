# Docker Compose vs Kubernetes

## 1. Purpose

This document defines how the existing Docker implementation maps to the Kubernetes / Minikube implementation.

Docker is the behavioral reference.

Kubernetes is the deployment target.

---

## 2. High-Level Mapping

| Docker Compose         | Kubernetes                                   |
| ---------------------- | -------------------------------------------- |
| Service                | Deployment / StatefulSet                     |
| Container              | Pod                                          |
| Port mapping           | Service                                      |
| Environment variables  | ConfigMap / Secret                           |
| Volume                 | PersistentVolumeClaim                        |
| Healthcheck            | Liveness / Readiness Probe                   |
| depends_on             | Readiness + application retry logic          |
| Docker network         | Kubernetes Service DNS                       |
| Compose restart policy | Kubernetes controller                        |
| Init scripts           | Init container / Job / mounted configuration |

---

## 3. Stateful vs Stateless

Use StatefulSet when a component requires stable identity or persistent state.

Examples in this project include:

```text
Oracle
Kafka
PostgreSQL
RisingWave
```

Stateless application-style components can use Deployment.

Examples include:

```text
Debezium Connect
Superset
Kafdrop
```

The actual choice must still be verified against the Docker behavior and application requirements.

---

## 4. Volumes

Docker named volumes map conceptually to Kubernetes persistent storage.

Example:

```text
Docker volume
      ↓
PVC
      ↓
Pod
```

Do not remove persistent storage simply because Minikube is a development environment.

CDC systems may depend on persisted database or streaming state.

---

## 5. Networking

Docker Compose commonly allows service-to-service communication through service names.

Kubernetes provides similar discovery through Services.

For example:

```text
docker:

oracle:1521
kafka:9092
```

may become:

```text
oracle.<namespace>.svc.cluster.local:1521
kafka.<namespace>.svc.cluster.local:9092
```

The exact hostname should be derived from the Kubernetes Service.

---

## 6. Kafka Networking

Kafka requires special attention because clients receive broker addresses from Kafka's advertised listeners.

Therefore it is not enough for:

```text
Debezium → Kafka
```

to reach the initial bootstrap endpoint.

The advertised broker address must also be reachable from the client.

Validation must therefore include:

1. DNS resolution;
2. TCP connectivity;
3. Kafka metadata retrieval;
4. topic access;
5. actual message production.

---

## 7. Environment Variables

Non-sensitive configuration should normally be stored in ConfigMaps.

Sensitive values should be stored in Secrets.

Example:

```text
ConfigMap:
  KAFKA_BOOTSTRAP_SERVERS

Secret:
  ORACLE_PASSWORD
```

Never copy real credentials into committed YAML.

---

## 8. Startup Ordering

Docker Compose may express dependencies explicitly.

Kubernetes generally relies on:

```text
readiness
health checks
application retries
```

Therefore a direct conversion of:

```text
depends_on
```

is usually not the correct Kubernetes design.

The application should start when its dependencies become available and retry where appropriate.

---

## 9. Initialization

The project has database initialization scripts under:

```text
docker/oracle/initdb/
docker/postgres/initdb/
```

These scripts are part of the application's behavior.

When migrating them, preserve:

* execution order;
* required environment;
* database target;
* permissions;
* idempotency expectations.

---

## 10. Docker Reference Workflow

The Docker workflow is:

```text
docker compose
   ↓
start infrastructure
   ↓
initialize databases
   ↓
start Debezium
   ↓
register connectors
   ↓
start RisingWave
   ↓
create sources / MVs
   ↓
start Superset
   ↓
run CDC tests
```

The Kubernetes workflow should produce the equivalent runtime state.

---

## 11. Migration Rule

For every component:

```text
Inspect Docker
      ↓
Document behavior
      ↓
Map to Kubernetes
      ↓
Deploy
      ↓
Validate
```

Do not implement all Kubernetes resources first and debug them collectively.

---

## 12. Validation

A Kubernetes component is considered successfully migrated only when:

```text
Pod is healthy
+
Service is reachable
+
configuration is correct
+
dependent component can connect
+
actual project behavior works
```

For CDC:

```text
DML
→ Debezium
→ Kafka
→ RisingWave
```

must be tested.

---

## 13. Known Differences

Kubernetes introduces differences in:

* DNS;
* service discovery;
* advertised addresses;
* persistent storage;
* startup ordering;
* probes;
* resource management;
* networking.

These differences must be handled explicitly rather than hidden.

---

## 14. Non-Goals

The migration should not automatically introduce:

* Helm;
* operators;
* multi-node production architecture;
* cloud-specific resources;
* external load balancers;
* service meshes;
* unnecessary redesigns.

Such additions require explicit justification.
