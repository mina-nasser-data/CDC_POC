# CDC Debugging Skill

Use this skill when CDC events are missing, delayed, duplicated, malformed, or contain unexpected values.

## Trace the Event

1. Oracle source DML
2. Transaction/commit
3. Redo/archive logs
4. LogMiner
5. Debezium
6. Kafka
7. RisingWave source
8. RisingWave transformation/materialized view
9. Final query/UI

## Evidence

At every layer determine:

* Did the event exist?
* What did it contain?
* What timestamp did it have?
* What changed from the previous layer?

## LOB/XML

For XML/CLOB/BLOB values inspect the actual representation at each layer.

Never assume that an unavailable or null downstream value means Oracle lost the value.

Find the first layer where the value changed or disappeared.
