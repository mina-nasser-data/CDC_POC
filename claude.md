# CDC_SCB — Claude Code Project Instructions

## Project Overview

This repository is a Streaming CDC / ELT proof-of-concept for Suez Canal Bank.

The project currently contains two infrastructure implementations:

* `docker/` — existing Docker Compose implementation and behavioral reference
* `k8s/` — Kubernetes/Minikube implementation being migrated and validated

The objective is to run the same CDC pipeline on Minikube while preserving the behavior of the existing Docker implementation.

---

# 1. Source of Truth

## Docker is the behavioral reference

The `docker/` directory represents the known working/reference implementation.

When evaluating or modifying Kubernetes:

1. Inspect the corresponding Docker configuration first.
2. Understand its behavior.
3. Compare it with the Kubernetes implementation.
4. Identify differences.
5. Fix only the differences that matter.
6. Validate the result.

Do NOT redesign the architecture during migration unless explicitly requested.

The Kubernetes implementation must reproduce the intended behavior of the Docker implementation.

---

# 2. Repository Structure

## Docker

`docker/`

Contains:

* Docker Compose
* Oracle image/configuration
* Debezium Connect image/configuration
* Kafka
* RisingWave
* PostgreSQL
* Superset
* connector configurations
* initialization scripts
* CDC test scripts
* SQL scripts

## Kubernetes

`k8s/`

Contains:

* Namespace
* ConfigMaps
* Secrets
* StatefulSets
* Deployments
* Services
* PVCs
* initialization Jobs
* connector registration Job

## Documentation

`docs/`

Contains existing architecture, troubleshooting, implementation, datatype, Oracle CDC, LOB, and verification documentation.

Read relevant documentation before modifying behavior that is already documented.

## Scripts

`scripts/`

Contains host-side operational scripts and SQL test scripts.

Prefer reusing existing scripts instead of creating duplicate workflows.

---

# 3. Current CDC Architecture

The intended data flow is:

Oracle
→ Oracle Redo / Archive Logs
→ Oracle LogMiner
→ Debezium Oracle Connector
→ Kafka
→ RisingWave
→ Materialized Views
→ Superset

The project also contains PostgreSQL CDC components and supporting infrastructure.

Do not assume that PostgreSQL CDC and Oracle CDC have identical behavior.

---

# 4. Kubernetes Migration Objective

The Kubernetes migration is an infrastructure migration, not an application redesign.

Preserve:

* database configuration
* schemas
* CDC behavior
* connector configuration
* Kafka topics
* source tables
* transformations
* materialized views
* test behavior
* relevant persistence
* required networking

Do not casually change:

* topic names
* table names
* schemas
* database names
* connector names
* credentials
* ports
* data types
* CDC semantics

If a change is necessary, explain why and validate its effect.

---

# 5. Docker → Kubernetes Mapping

When comparing implementations, inspect:

* image
* Dockerfile
* command
* entrypoint
* environment variables
* ports
* volumes
* healthchecks
* dependencies
* startup behavior
* configuration files
* initialization scripts

Map them to appropriate Kubernetes resources:

* Deployment
* StatefulSet
* Service
* ConfigMap
* Secret
* PersistentVolumeClaim
* Job
* readinessProbe
* livenessProbe
* initContainer

Do not use a Kubernetes resource simply because it exists in another project.

Choose it based on the actual workload.

---

# 6. Debugging Method

Always use evidence-driven debugging.

Do not shotgun-debug.

When something fails, determine the first layer where expected behavior disappears.

Preferred investigation chain:

Oracle
→ LogMiner
→ Debezium
→ Kafka
→ RisingWave
→ Materialized View
→ Superset

For Kubernetes infrastructure problems:

Pod
→ Container
→ Logs
→ Service
→ DNS
→ Network
→ Dependency
→ Application behavior

Do not change multiple unrelated components at the same time.

---

# 7. CDC Debugging

When a CDC event is missing or incorrect:

1. Confirm the source DML.
2. Confirm transaction/commit behavior.
3. Confirm Oracle CDC prerequisites.
4. Confirm LogMiner behavior.
5. Confirm Debezium connector status.
6. Confirm Kafka topic/message.
7. Confirm RisingWave ingestion.
8. Confirm transformation/materialized view.
9. Confirm final query/UI.

Never assume that a downstream missing value originated in Oracle.

Find the first layer where it disappears.

---

# 8. XML / CLOB / BLOB / LOB Behavior

This project contains LOB/XML-related CDC behavior.

Treat these as special cases.

When debugging LOB/XML values, distinguish between:

* Oracle stored value
* Oracle redo representation
* LogMiner representation
* Debezium representation
* Kafka payload
* RisingWave representation
* final materialized value

Do not assume that a relational LOB value will appear identically in every layer.

Read the existing documentation under `docs/` before modifying this behavior.

---

# 9. Timestamp and Latency Measurements

When working with CDC latency, do not mix timestamp semantics.

Explicitly identify the meaning of every timestamp, such as:

* Oracle transaction/commit timestamp
* Debezium source timestamp
* Kafka/event timestamp
* downstream arrival timestamp
* processing/materialization timestamp

When calculating latency, document:

`latency = end_timestamp - start_timestamp`

and identify exactly what the start and end timestamps represent.

Do not compare timestamps from different clocks or semantic layers without accounting for the difference.

---

# 10. Kubernetes Validation

A Kubernetes migration is NOT complete merely because YAML files exist or Pods are `Running`.

Validate:

* Namespace
* Pods
* container readiness
* Services
* endpoints
* DNS
* persistent volumes
* configuration
* secrets
* logs
* inter-service connectivity
* actual application behavior

For CDC, perform behavioral tests:

* INSERT
* UPDATE
* DELETE

Then verify the event through the pipeline.

---

# 11. Component-by-Component Workflow

For a multi-component migration or debugging task:

Do NOT modify the entire stack at once.

Use:

1. Inspect
2. Understand
3. Compare
4. Plan
5. Modify
6. Deploy
7. Validate
8. Test
9. Document
10. Continue

Do not move to the next component if the current component has an unresolved fundamental failure.

---

# 12. Existing Files Have Priority

Before creating a new configuration or script:

Search the repository for an existing implementation.

Prefer:

* existing scripts
* existing SQL
* existing ConfigMaps
* existing connector configurations
* existing documentation
* existing Docker configuration

Do not create duplicate files unless there is a clear reason.

---

# 13. Secrets

Never hard-code secrets.

Never expose secret values in output.

Use the project's existing:

* `.env`
* Kubernetes Secrets
* configuration mechanisms

Do not commit credentials.

If a required secret is missing, do not invent one.

---

# 14. Git Safety

Be conservative with Git.

Before pushing:

1. Check current branch.
2. Check remotes.
3. Check status.
4. Review the diff.
5. Confirm the intended destination.

Never:

* force push
* reset user work
* delete branches
* rewrite history
* modify remotes

unless explicitly requested.

Do not assume `origin` is the intended push target.

---

# 15. Change Discipline

Prefer the smallest change that solves the actual problem.

Do not refactor unrelated code.

Do not replace working components simply because another technology may be theoretically better.

If a change affects architecture or behavior, explain:

* what changed
* why
* expected effect
* validation performed

---

# 16. Documentation Rules

Existing documentation is part of the project knowledge.

Relevant documents include:

* `docs/architecture.md`
* `docs/compose-vs-k8s.md`
* `docs/datatype-behavior.md`
* `docs/IMPLEMENTATION-CHECKLIST.md`
* `docs/LOB-UNAVAILABLE-VALUE-FIX.md`
* `docs/oracle-cdc-prereqs.md`
* `docs/troubleshooting.md`
* `docs/verification-checklists.md`

When documentation conflicts with actual configuration:

1. Inspect the implementation.
2. Treat actual working configuration/runtime behavior as evidence.
3. Update documentation if the implementation has intentionally changed.

Do not blindly trust outdated documentation.

---

# 17. Definition of Done

Do not declare a task complete until you can clearly report:

### Changes

* files changed
* resources added/removed
* configuration changes

### Validation

* commands executed
* Pods/Services status
* relevant logs
* functional tests

### CDC

Where applicable:

* INSERT result
* UPDATE result
* DELETE result
* event propagation
* latency measurement

### Remaining Issues

Explicitly list unresolved issues or limitations.

Never claim success based only on configuration generation.
