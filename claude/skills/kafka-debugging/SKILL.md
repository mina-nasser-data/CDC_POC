# Kafka Debugging Skill

When debugging Kafka:

1. Verify broker health.
2. Verify topic existence.
3. Verify producer activity.
4. Inspect actual messages.
5. Verify consumer connectivity.
6. Inspect offsets.
7. Verify serialization/parsing.
8. Verify downstream consumption.

Separate connectivity problems from message-production problems and downstream parsing problems.

When running inside Kubernetes, verify advertised listeners and Service/DNS configuration carefully.
