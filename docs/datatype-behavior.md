# CDC Data Type Behavior

## 1. Purpose

This document records important data-type behavior across:

```text
Oracle
→ Debezium
→ Kafka
→ RisingWave
```

CDC debugging must distinguish between:

```text
database type
event representation
Kafka serialization
streaming SQL type
```

A type being valid in Oracle does not guarantee that it will have the same representation downstream.

---

## 2. Main Oracle Types

The main source table contains fields representing:

```text
NUMBER / numeric values
DATE / timestamp values
VARCHAR values
SYS.XMLTYPE
CLOB
BLOB
```

The exact Oracle DDL remains the authoritative source.

---

## 3. Scalar Values

Scalar values are generally easier to propagate through CDC.

Examples:

```text
ENTRY_ID
ACCOUNT_NUMBER
TXN_CODE
AMOUNT
CURRENCY
BOOKING_DATE
```

Validation should compare:

```text
Oracle value
→ Debezium payload
→ Kafka message
→ RisingWave value
```

---

## 4. XMLTYPE

The project uses:

```text
SYS.XMLTYPE
```

XML changes can produce more complicated redo / LogMiner behavior than ordinary scalar columns.

Possible low-level redo operations include:

```text
DOC BEGIN
DOC WRITE
DOC END
```

Therefore XML CDC behavior should not be diagnosed solely from the final Kafka payload.

---

## 5. CLOB

CLOB data is a LOB type.

Depending on connector configuration and the operation being captured, the complete value may not always be available directly in the CDC event.

Possible representations can include:

```text
actual value
```

or:

```text
__debezium_unavailable_value
```

when the connector cannot provide the required value.

---

## 6. BLOB

BLOB is also a LOB type.

Its CDC behavior must be tested independently from:

```text
VARCHAR
NUMBER
DATE
```

Do not assume that a successful scalar UPDATE proves BLOB UPDATE correctness.

---

## 7. __debezium_unavailable_value

This value indicates that Debezium does not have the requested column value available for the event under the current conditions/configuration.

It should not automatically be interpreted as:

```text
Kafka corruption
```

or:

```text
RisingWave parsing failure
```

The investigation should determine where the value became unavailable.

---

## 8. Type Debugging Procedure

When a value is incorrect:

### Step 1

Check the source database:

```sql
SELECT ...
FROM APPUSER.STMT_ENTRY;
```

### Step 2

Check the Debezium connector status.

### Step 3

Inspect the raw Kafka event.

### Step 4

Check the Kafka JSON/schema representation.

### Step 5

Inspect the RisingWave source schema.

### Step 6

Inspect transformations / materialized views.

### Step 7

Compare the final query result.

---

## 9. RisingWave Compatibility

RisingWave is PostgreSQL-compatible in many areas but is not identical to PostgreSQL.

Therefore:

```text
PostgreSQL syntax
≠
guaranteed RisingWave support
```

When a type or function fails:

1. verify RisingWave documentation / actual version behavior;
2. inspect the source schema;
3. inspect the incoming Kafka payload;
4. determine whether the problem is parsing, typing, or SQL compatibility.

---

## 10. Numeric Values

Numeric fields may need explicit type choices when crossing systems.

A previous PostgreSQL CDC path required:

```text
DOUBLE PRECISION
```

for `amount` rather than the previous numeric definition because of RisingWave compatibility.

This is an integration decision and should not be generalized to every field.

---

## 11. Timestamp Values

Timestamp-related fields can represent different events.

Examples:

```text
Oracle transaction timestamp
Debezium source timestamp
Kafka arrival timestamp
RisingWave processing timestamp
```

Always identify the semantic meaning before using the value in latency calculations.

---

## 12. Type Preservation Rule

When changing a data type, document:

```text
original type
new type
reason
source behavior
downstream behavior
precision implications
validation
```

Do not silently change types simply to make parsing succeed.

---

## 13. Data-Type Validation Matrix

Every important data type should eventually have tests for:

| Operation | Scalar | XML | CLOB | BLOB |
| --------- | -----: | --: | ---: | ---: |
| INSERT    |      ✓ |   ✓ |    ✓ |    ✓ |
| UPDATE    |      ✓ |   ✓ |    ✓ |    ✓ |
| DELETE    |      ✓ |   ✓ |    ✓ |    ✓ |

The exact test implementation should use the project's existing scripts whenever possible.
