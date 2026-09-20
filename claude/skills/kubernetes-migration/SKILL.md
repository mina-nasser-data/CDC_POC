# Kubernetes Migration Skill

Use this skill when migrating, auditing, or fixing a Docker component in `k8s/`.

## Objective

Make the Kubernetes implementation behaviorally equivalent to the Docker implementation.

## Procedure

### Step 1 — Locate

Find the relevant:

* Docker Compose service
* Dockerfile
* configuration
* scripts
* volumes
* healthchecks
* dependencies

### Step 2 — Understand Docker

Record:

* image
* command
* environment
* ports
* volumes
* healthcheck
* dependencies
* startup behavior

### Step 3 — Inspect Kubernetes

Find the corresponding:

* Deployment/StatefulSet
* Service
* ConfigMap
* Secret
* PVC
* Job

### Step 4 — Compare

Identify differences.

Classify each difference:

* required
* Kubernetes-specific
* harmless
* suspicious
* breaking

### Step 5 — Modify

Make the smallest required change.

### Step 6 — Deploy

Apply only the relevant resources.

### Step 7 — Validate

Check:

* Pod status
* readiness
* Service
* endpoints
* DNS
* logs
* dependency connectivity

### Step 8 — Functional Test

Test actual component behavior.

### Step 9 — Compare

Confirm that the Kubernetes behavior matches the Docker reference.

## Stop Conditions

Stop and report if:

* a required configuration value is unknown
* a change could cause data loss
* a secret is unavailable
* the Docker behavior is ambiguous
* the proposed solution requires architectural redesign
