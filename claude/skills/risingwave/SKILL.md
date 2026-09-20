# RisingWave Skill

When debugging RisingWave:

1. Verify source connectivity.
2. Verify source schema.
3. Inspect actual Kafka payloads.
4. Verify parsing.
5. Verify data types.
6. Verify source/table ingestion.
7. Verify materialized view logic.
8. Verify final query.

Do not assume complete PostgreSQL type compatibility.

For latency measurements, explicitly identify the semantic meaning of every timestamp before calculating latency.
