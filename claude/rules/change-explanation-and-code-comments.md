# Change Explanation and Code Comment Rules

## 1. Purpose

These rules control how Claude Code should make changes to this repository.

The goal is to make every meaningful change understandable before it is executed.

Claude must not silently modify project files without explaining the purpose and expected result.

---

# 2. Before Any Meaningful Change

Before modifying, creating, deleting, moving, or significantly rewriting a file, Claude must first explain:

### 1. What

What exactly is going to change?

### 2. Why

Why is this change necessary?

### 3. Goal

What specific result should this change achieve?

### 4. Files

Which files will be affected?

### 5. Relationship

How is each affected file connected to the rest of the project?

### 6. Validation

How will the result be verified?

---

## 3. Required Format

Use this structure:

```text
Change:
<what will change>

Why:
<why this change is required>

Goal:
<expected outcome>

Files:
- <file>
- <file>

Relationships:
- <file> → <related file/component>
- <file> → <related file/component>

Validation:
<how the change will be tested>
```

Keep this explanation concise.

Do not write a large essay before a simple change.

---

# 4. One Change at a Time

Prefer:

```text
Explain
→ change
→ validate
→ report result
→ next change
```

Do not make a large collection of unrelated changes before validation.

---

# 5. Before Code / Configuration Blocks

Before a meaningful block of code or configuration, add a short comment when the purpose is not obvious.

The comment should explain:

```text
purpose
reason
important dependency
important constraint
```

Example:

```yaml
# Expose Kafka's internal listener so Debezium can reach the broker through the Kubernetes network.
ports:
  - name: internal
    port: 9092
```

---

# 6. Bad Comments

Do not write comments that merely repeat the syntax.

Bad:

```yaml
# Port
port: 9092
```

Bad:

```yaml
# Create service
kind: Service
```

Bad:

```python
# Increment i
i += 1
```

---

# 7. Good Comments

Good comments explain non-obvious intent.

Example:

```yaml
# Keep this Service name stable because Debezium uses it as the Kafka bootstrap address.
metadata:
  name: kafka
```

Example:

```sql
-- Measure latency from the CDC source commit timestamp to downstream arrival time.
SELECT ...
```

---

# 8. Do Not Over-Comment

Do not add comments to every line.

Comments should be used when the reader may reasonably ask:

```text
Why is this here?
Why this value?
Why this dependency?
Why this implementation?
```

---

# 9. Kubernetes Changes

Before modifying Kubernetes resources, identify the Docker component being migrated or matched.

Example:

```text
Change:
Modify k8s/connect/deployment.yaml.

Why:
The Kubernetes Debezium deployment must reproduce the working Docker Connect configuration.

Goal:
Make Debezium Connect start with the same required driver, environment, and connector connectivity.

Files:
- k8s/connect/deployment.yaml
- docker/connect/Dockerfile
- docker/connect/connectors/oracle-source.json

Relationships:
- Dockerfile → Debezium runtime image
- deployment.yaml → Kubernetes Connect pod
- oracle-source.json → Oracle CDC connector configuration

Validation:
Verify the pod is Ready, the connector is RUNNING, and a test Oracle event reaches Kafka.
```

---

# 10. CDC Changes

For CDC-related changes, explicitly identify the pipeline boundary.

Examples:

```text
Oracle → Debezium
Debezium → Kafka
Kafka → RisingWave
RisingWave → Materialized View
```

Do not describe the entire pipeline as one undifferentiated component.

---

# 11. Debugging

Before changing configuration during debugging, provide:

```text
Observation:
<what is currently known>

Hypothesis:
<likely explanation>

Evidence:
<what supports the hypothesis>

Change:
<minimal change being proposed>

Validation:
<test that will confirm or reject the hypothesis>
```

Do not present an unverified hypothesis as a fact.

---

# 12. Unknowns

If the repository does not provide enough evidence:

Do not guess.

Say what is unknown and identify the file or command needed to determine it.

Example:

```text
I cannot safely modify the Kafka listener configuration yet.

Unknown:
The current advertised.listeners value.

Why it matters:
Kafka clients may bootstrap successfully but fail when the broker advertises an unreachable address.

Needed evidence:
docker/compose/docker-compose.yml
and the current k8s/kafka/statefulset.yaml
```

---

# 13. Destructive Changes

Before:

```text
delete
reset
drop
truncate
PVC deletion
volume deletion
force push
Git history rewrite
```

Claude must explicitly state:

```text
what will be lost
why it is necessary
what can be recovered
how the action will be validated
```

Ask for confirmation when the operation can cause meaningful data or history loss.

---

# 14. Git

Before changing Git state, identify:

```text
current branch
target branch
target remote
working tree state
```

Never assume the intended remote.

In particular:

```text
origin
```

is the team remote and must not be modified or pushed to unless explicitly requested.

---

# 15. File Relationships

When creating a new file, explain:

```text
Why this file exists
Who consumes it
What it depends on
What depends on it
```

Example:

```text
k8s/configmaps/risingwave-sql-configmap.yaml

Purpose:
Store SQL initialization used by the RisingWave deployment.

Consumed by:
k8s/risingwave/statefulset.yaml

Related:
docker/risingwave/sql/create-source-table.sql
docker/risingwave/sql/create-mviews.sql
```

---

# 16. Migration Rule

When migrating Docker → Kubernetes:

```text
Docker behavior
      ↓
Identify dependency
      ↓
Explain mapping
      ↓
Implement Kubernetes resource
      ↓
Validate
```

Never blindly translate Docker YAML into Kubernetes YAML.

---

# 17. Completion Report

After a change, report:

```text
Changed:
<files>

Reason:
<why>

Result:
<what happened>

Validation:
<tests performed>

Remaining:
<any unresolved issue>
```

If validation was not performed, explicitly say:

```text
Not yet validated.
```

Do not claim success based only on syntax or `kubectl apply`.

---

# 18. Core Principle

Every meaningful change must answer:

```text
Why are we doing this?
What does it achieve?
Which file implements it?
Which files is it connected to?
How will we prove it works?
```

The user should be able to understand the purpose of a change before Claude executes it.
