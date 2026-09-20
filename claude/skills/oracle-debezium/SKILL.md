# Oracle + Debezium Skill

When working with Oracle CDC:

1. Identify the target database/PDB.
2. Distinguish `CDB$ROOT` from the target PDB.
3. Verify the source schema/table.
4. Verify CDC prerequisites.
5. Verify transaction/commit state.
6. Inspect LogMiner behavior.
7. Inspect Debezium connector status.
8. Inspect actual emitted Kafka events.

For LOB/XML columns, treat:

Oracle value
→ redo
→ LogMiner
→ Debezium
→ Kafka

as separate representations.

Do not invent Oracle credentials or configuration.
