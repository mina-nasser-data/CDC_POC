# Testing Rules

Configuration validity is not behavioral validation.

For CDC changes, test:

1. INSERT
2. UPDATE
3. DELETE

For Kubernetes changes, verify:

* Pod readiness
* Service connectivity
* DNS
* logs
* dependency connectivity
* actual application behavior

Do not declare success only because Pods are Running.
