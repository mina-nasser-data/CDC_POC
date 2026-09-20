# CDC_SCB Implementation Checklist

## 1. Purpose

This checklist defines the implementation process for changes and migrations in the CDC_SCB project.

It is primarily intended for the Docker → Kubernetes / Minikube migration, but it also applies to significant infrastructure, CDC, configuration, and integration changes.

The goal is to ensure that implementation is:

* evidence-driven;
* incremental;
* traceable;
* reversible where possible;
* behavior-preserving;
* validated before moving to the next component.

---

# 2. Mandatory Workflow

Claude must follow this workflow for meaningful implementation tasks:

```text
Understand
   ↓
Inspect
   ↓
Explain
   ↓
Plan
   ↓
Implement
   ↓
Validate
   ↓
Document
   ↓
Move to next component
```

Do not skip directly from the user's request to implementation.

---

# 3. Before Starting

## Project Understanding

* [ ] Read `CLAUDE.md`
* [ ] Read relevant `.claude/rules/`
* [ ] Read relevant `.claude/skills/`
* [ ] Read `docs/project-context.md`
* [ ] Read relevant architecture documentation
* [ ] Identify whether the task affects Docker, Kubernetes, CDC, data, networking, or analytics

## Repository Understanding

* [ ] Inspect the relevant existing files
* [ ] Identify the current implementation
* [ ] Identify related files
* [ ] Identify dependencies
* [ ] Identify configuration sources
* [ ] Identify existing scripts/tests
* [ ] Identify existing documentation

---

# 4. Mandatory Pre-Change Explanation

Before making a meaningful change, Claude must explain:

```text
Change:
What will be changed?

Why:
Why is this change necessary?

Goal:
What should this change achieve?

Files:
Which files will be modified / created?

Relationships:
How are those files connected to the architecture?

Validation:
How will the change be verified?
```

Do not modify files before this explanation for meaningful changes.

For trivial read-only operations, this explanation is not required.

---

# 5. Docker Reference Inspection

For every Docker → Kubernetes migration component:

* [ ] Identify the Docker Compose service
* [ ] Inspect its image
* [ ] Inspect command
* [ ] Inspect entrypoint
* [ ] Inspect environment variables
* [ ] Inspect ports
* [ ] Inspect volumes
* [ ] Inspect healthcheck
* [ ] Inspect dependencies
* [ ] Inspect mounted configuration
* [ ] Inspect initialization scripts
* [ ] Inspect restart behavior
* [ ] Inspect networking assumptions

Record the relevant findings before implementing the Kubernetes equivalent.

---

# 6. Component Migration Order

Unless there is a documented reason to change the order, migrate and validate components in dependency order.

Recommended logical order:

```text
1. Namespace / configuration
2. Oracle
3. PostgreSQL
4. Kafka
5. Debezium Connect
6. RisingWave
7. Superset
8. Kafdrop
9. End-to-end validation
```

The exact order may change if a dependency requires it.

Any deviation should be explained.

---

# 7. Namespace

* [ ] `k8s/namespace.yaml` exists
* [ ] Namespace name is identified
* [ ] Resources are deployed into the intended namespace
* [ ] No accidental deployment into `default`
* [ ] Resource names are consistent

Validation:

```bash
kubectl get namespaces
kubectl get all -n <namespace>
```

---

# 8. Secrets and Configuration

## ConfigMaps

* [ ] Non-sensitive configuration identified
* [ ] ConfigMaps created where appropriate
* [ ] Existing Docker configuration mapped correctly
* [ ] No configuration silently changed

Relevant directory:

```text
k8s/configmaps/
```

## Secrets

* [ ] Credentials identified
* [ ] Secrets created where required
* [ ] No real credentials hardcoded into manifests
* [ ] Environment variable names match the application
* [ ] Secret references are correct

Relevant directory:

```text
k8s/secrets/
```

---

# 9. Oracle Implementation

## Kubernetes Resources

* [ ] `k8s/oracle/statefulset.yaml`
* [ ] `k8s/oracle/service.yaml`
* [ ] `k8s/oracle/pvc.yaml`

## Validation

* [ ] Pod starts
* [ ] Pod becomes Ready
* [ ] PVC is Bound
* [ ] Oracle service resolves
* [ ] Oracle listener is reachable
* [ ] PDB `XEPDB1` exists
* [ ] `APPUSER` exists
* [ ] `APPUSER.STMT_ENTRY` exists

## CDC Prerequisites

* [ ] Archive logging configured
* [ ] CDC-related configuration applied
* [ ] Required table logging configured
* [ ] LOB/XML-related configuration verified
* [ ] Debezium CDC user can access required objects

Do not proceed to Debezium validation until Oracle is confirmed operational.

---

# 10. PostgreSQL Implementation

## Kubernetes Resources

* [ ] `k8s/postgres/statefulset.yaml`
* [ ] `k8s/postgres/service.yaml`
* [ ] `k8s/postgres/pvc.yaml`

## Validation

* [ ] Pod starts
* [ ] PVC is Bound
* [ ] PostgreSQL service resolves
* [ ] Database `cdcdb` exists
* [ ] `public.stmt_entry` exists
* [ ] Required schema is correct

## CDC

* [ ] Debezium PostgreSQL configuration is available
* [ ] Connector can connect
* [ ] Expected Kafka topic is produced
* [ ] RisingWave can consume the topic

---

# 11. Kafka Implementation

## Kubernetes Resources

* [ ] `k8s/kafka/statefulset.yaml`
* [ ] `k8s/kafka/service.yaml`
* [ ] `k8s/kafka/pvc.yaml`

## KRaft

* [ ] Kafka is configured for KRaft
* [ ] Controller configuration is correct
* [ ] Broker configuration is correct
* [ ] Required listeners exist
* [ ] Advertised listeners are correct

Known ports:

```text
9092  -> internal
29092 -> external
9093  -> controller
```

The actual Kubernetes configuration remains authoritative.

## Validation

* [ ] Pod is Ready
* [ ] Service exists
* [ ] Kafka process is listening
* [ ] Kafka metadata can be retrieved
* [ ] Topic creation/access works
* [ ] Producer can publish
* [ ] Consumer can consume

---

# 12. Debezium Connect Implementation

## Kubernetes Resources

* [ ] `k8s/connect/deployment.yaml`
* [ ] `k8s/connect/service.yaml`
* [ ] `k8s/connect/connector-job.yaml`

## Runtime

* [ ] Correct Debezium image
* [ ] Oracle JDBC driver available
* [ ] Required environment variables present
* [ ] Kafka bootstrap address correct
* [ ] Oracle connection address correct

Known Debezium image:

```text
quay.io/debezium/connect:3.6
```

## Connector Configuration

* [ ] Oracle connector configuration available
* [ ] PostgreSQL connector configuration available where required
* [ ] Table include list is correct
* [ ] Topic prefix is correct
* [ ] Database credentials are correct
* [ ] CDC mode is correct

## Validation

* [ ] Connect pod is Ready
* [ ] Connect REST endpoint reachable
* [ ] Connector exists
* [ ] Connector status is correct
* [ ] Task status is correct
* [ ] Oracle INSERT produces Kafka event
* [ ] UPDATE produces Kafka event
* [ ] DELETE produces Kafka event

---

# 13. RisingWave Implementation

## Kubernetes Resources

* [ ] `k8s/risingwave/statefulset.yaml`
* [ ] `k8s/risingwave/service.yaml`
* [ ] `k8s/risingwave/pvc.yaml`

## Configuration

* [ ] SQL ConfigMap is correct
* [ ] Kafka bootstrap address is correct
* [ ] Topic names are correct
* [ ] Source schema matches Kafka payload
* [ ] Required SQL initialization is available

Relevant files:

```text
k8s/configmaps/risingwave-sql-configmap.yaml

docker/risingwave/sql/
```

## Validation

* [ ] RisingWave pod is Ready
* [ ] SQL endpoint reachable
* [ ] Kafka source created
* [ ] Source receives events
* [ ] Data types are correct
* [ ] Materialized views created
* [ ] Materialized views update after CDC

---

# 14. Superset Implementation

## Kubernetes Resources

* [ ] `k8s/superset/deployment.yaml`
* [ ] `k8s/superset/service.yaml`
* [ ] `k8s/superset/init-job.yaml`

## Configuration

* [ ] Superset configuration mounted
* [ ] Database connection configured
* [ ] Required initialization completed
* [ ] Credentials provided through Secrets
* [ ] RisingWave connection configured correctly

## Validation

* [ ] Pod is Ready
* [ ] UI is accessible
* [ ] Superset can connect to intended database
* [ ] Tables / views can be queried
* [ ] Known compatibility issues are documented

---

# 15. Kafdrop Implementation

## Kubernetes Resources

* [ ] `k8s/kafdrop/deployment.yaml`
* [ ] `k8s/kafdrop/service.yaml`

## Validation

* [ ] Pod starts
* [ ] UI is accessible
* [ ] Kafka broker is reachable
* [ ] CDC topics are visible

Kafdrop is a debugging / observability convenience.

It is not required for the core CDC data path.

Therefore:

```text
Kafdrop failure
≠
CDC pipeline failure
```

---

# 16. Service Connectivity

For every component-to-component connection:

```text
Source
  ↓
Kubernetes Service
  ↓
Target Pod
```

verify:

* [ ] Service exists
* [ ] Service selector matches target pods
* [ ] Endpoints exist
* [ ] Port is correct
* [ ] Target port is correct
* [ ] DNS resolves
* [ ] TCP connection succeeds
* [ ] Application protocol succeeds

Do not consider a Service healthy merely because the Service object exists.

---

# 17. Persistent Storage

For stateful components:

* [ ] PVC exists
* [ ] PVC is Bound
* [ ] correct mount path
* [ ] correct filesystem permissions
* [ ] data survives pod restart where expected
* [ ] no unnecessary data deletion

Never delete a PVC as a generic troubleshooting step.

---

# 18. Health Checks

For every important workload:

* [ ] readiness behavior understood
* [ ] liveness behavior understood
* [ ] startup behavior understood
* [ ] probe path/port is valid
* [ ] probe does not execute before the application can reasonably start

A failing probe should be diagnosed before simply increasing delays.

---

# 19. CDC End-to-End Validation

After infrastructure migration, perform:

```text
Oracle
 ↓
Debezium
 ↓
Kafka
 ↓
RisingWave
 ↓
Materialized View
```

## INSERT

* [ ] Insert unique test row
* [ ] Commit
* [ ] Verify Oracle
* [ ] Verify Debezium
* [ ] Verify Kafka
* [ ] Verify RisingWave
* [ ] Verify Materialized View

## UPDATE

* [ ] Update existing test row
* [ ] Commit
* [ ] Verify Kafka event
* [ ] Verify RisingWave
* [ ] Verify final state

## DELETE

* [ ] Delete test row
* [ ] Commit
* [ ] Verify DELETE event
* [ ] Verify downstream state

---

# 20. LOB / XML Validation

Test separately:

* [ ] XML INSERT
* [ ] XML UPDATE
* [ ] XML DELETE
* [ ] CLOB INSERT
* [ ] CLOB UPDATE
* [ ] CLOB DELETE
* [ ] BLOB INSERT
* [ ] BLOB UPDATE
* [ ] BLOB DELETE

Record:

```text
actual value
NULL
__debezium_unavailable_value
```

Do not classify the result until the responsible layer is identified.

---

# 21. Latency Validation

Before measuring latency:

* [ ] define start timestamp
* [ ] define end timestamp
* [ ] define timestamp semantics
* [ ] define unit
* [ ] verify timezone assumptions
* [ ] verify clock behavior

Example:

```text
Oracle commit timestamp
        ↓
RisingWave arrival timestamp
```

Then:

```text
latency_ms =
arrival_ms - commit_ms
```

Collect multiple samples.

Do not use a single event as a representative benchmark.

---

# 22. Docker vs Kubernetes Comparison

For each migrated component:

```text
Docker
vs
Kubernetes
```

compare:

* [ ] startup behavior
* [ ] connectivity
* [ ] configuration
* [ ] CDC behavior
* [ ] data correctness
* [ ] timestamps
* [ ] latency where relevant

The goal is behavioral equivalence, not identical implementation details.

---

# 23. Documentation During Implementation

Whenever a non-trivial change is made:

* [ ] explain why it was made
* [ ] document affected files
* [ ] document relationships
* [ ] document validation
* [ ] document limitations
* [ ] update relevant documentation

Do not leave important architectural decisions only inside chat history.

---

# 24. Code / Configuration Comments

Before a meaningful code or configuration block, add a short comment when the purpose is not obvious.

Good:

```yaml
# Keep this Service stable because Debezium uses it as the Kafka bootstrap endpoint.
metadata:
  name: kafka
```

Avoid comments that merely repeat syntax.

Do not over-comment obvious code.

---

# 25. Git Safety Checklist

Before Git operations:

* [ ] inspect current branch
* [ ] inspect remotes
* [ ] inspect working tree
* [ ] identify target remote
* [ ] identify target branch
* [ ] verify intended files

Before destructive Git operations:

* [ ] explain consequence
* [ ] explain recovery path
* [ ] obtain confirmation when appropriate

Never push to the team remote accidentally.

---

# 26. Failure Handling

If a validation step fails:

```text
STOP
   ↓
Record observation
   ↓
Identify failed boundary
   ↓
Form hypothesis
   ↓
Collect evidence
   ↓
Make minimal change
   ↓
Revalidate
```

Do not continue migrating unrelated components while a critical dependency is known to be broken.

---

# 27. Completion Criteria

The implementation is complete only when:

* [ ] required Kubernetes resources exist
* [ ] pods are healthy
* [ ] services are reachable
* [ ] configuration is correct
* [ ] persistent storage works where required
* [ ] Debezium connectors work
* [ ] Kafka topics receive events
* [ ] RisingWave consumes events
* [ ] materialized views update
* [ ] INSERT works
* [ ] UPDATE works
* [ ] DELETE works
* [ ] required LOB/XML behavior is validated
* [ ] Docker behavior has been compared
* [ ] limitations are documented
* [ ] implementation documentation is updated

---

# 28. Final Rule

Never mark a component as:

```text
DONE
```

based only on:

```text
kubectl apply succeeded
```

or:

```text
Pod is Running
```

A component is done only when its intended behavior has been demonstrated and validated.
