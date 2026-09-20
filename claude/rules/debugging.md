# Debugging Rules

Use evidence-driven debugging.

Do not shotgun-debug.

Find the first layer where expected behavior disappears.

For CDC:

Oracle
→ LogMiner
→ Debezium
→ Kafka
→ RisingWave
→ Materialized View
→ Superset

For Kubernetes:

Pod
→ Container
→ Logs
→ Service
→ DNS
→ Network
→ Dependency

Change one relevant thing at a time when diagnosing a failure.
