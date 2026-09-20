# Kubernetes Rules

* Compare every Kubernetes component against its Docker counterpart before modifying it.
* Preserve image, command, environment, ports, volumes, healthchecks, and startup behavior unless there is a Kubernetes-specific reason to change them.
* Use Services for stable service discovery.
* Use StatefulSets for stateful workloads where stable identity/storage matters.
* Use Deployments for stateless workloads.
* Use PVCs for persistent data.
* Use ConfigMaps for non-secret configuration.
* Use Secrets for credentials.
* Use readiness/liveness probes where meaningful.
* Do not expose internal services externally without a reason.
