# Local CDC Streaming POC

Architecture:

Oracle XE -> Oracle LogMiner -> Kafka Connect + Debezium Oracle -> Kafka -> RisingWave -> Superset

PostgreSQL is used initially as Superset metadata database.

This project is built in two stages:
1. Docker Compose validation
2. Kubernetes / Minikube deployment