# End-to-End CDC Validation Skill

Use the existing project test scripts where possible.

## INSERT

Perform one controlled INSERT.

Verify:

Oracle
→ Debezium
→ Kafka
→ RisingWave
→ final result

## UPDATE

Update the same record.

Verify the changed value through the pipeline.

## DELETE

Delete the record.

Verify the expected downstream current-state result.

## Report

Report:

* test identifier
* operation
* expected result
* observed result
* affected layer
* latency if measured
* errors
* final status
