# Architecture Rules

* `docker/` is the behavioral reference implementation.
* `k8s/` is the target Minikube/Kubernetes implementation.
* Do not redesign the CDC architecture during migration.
* Preserve Oracle → LogMiner → Debezium → Kafka → RisingWave behavior.
* Treat PostgreSQL CDC separately from Oracle CDC.
* Do not change application logic when an infrastructure/configuration change is sufficient.
* Document intentional architectural deviations.
