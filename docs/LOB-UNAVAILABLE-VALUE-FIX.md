# CDC Pipeline: Fixing __debezium_unavailable_value for LOB Columns

## Problem Summary
When verifying CDC payload after UPDATE operations, CLOB, XMLTYPE, and BLOB columns return `__debezium_unavailable_value` instead of actual data.

## Root Cause Analysis

### 1. **Missing Column-Level Supplemental Logging** ⚠️ PRIMARY ISSUE
The most critical issue is your Oracle initialization script only enables database-level supplemental logging:
```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```

But LOB columns require **specific column-level logging configuration** in the redo logs. Without this, Debezium's LogMiner cannot read the LOB data.

### 2. **Incomplete Connector Configuration**
Missing critical LOB-handling parameters:
- No `lob.chunk.size` configuration
- No `database.fetch.size` setting  
- No JDBC LOB batch settings
- `log.mining.select.all.tables` set to `true` (should be more specific)

### 3. **ReselectColumnsPostProcessor Usage**
While configured, it's not effective without proper Oracle-side logging setup.

## Solution: Step-by-Step Implementation

### Step 1: Add LOB Supplemental Logging to Oracle

Create a new initialization script or run manually:

**File**: `docker/oracle/initdb/04-configure-cdc-lob-logging.sql`

```sql
ALTER SESSION SET CONTAINER = XEPDB1;

-- Enable column-level supplemental logging for LOB columns
ALTER TABLE APPUSER.CDC_TEST ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Explicitly configure LOB logging
ALTER TABLE APPUSER.CDC_TEST MODIFY (DESCRIPTION LOB (CACHE LOGGING));
ALTER TABLE APPUSER.CDC_TEST MODIFY (PAYLOAD_XML LOB (CACHE LOGGING));
ALTER TABLE APPUSER.CDC_TEST MODIFY (BINARY_DATA LOB (CACHE LOGGING));
```

**Key Points**:
- `SUPPLEMENTAL LOG DATA (ALL) COLUMNS` logs all columns for this table
- `LOB (CACHE LOGGING)` ensures LOB data is logged to redo logs, not stored separately
- Must run as SYSDBA or have appropriate privileges

### Step 2: Update Debezium Connector Configuration

**File**: `docker/connect/connectors/oracle-source.json`

Critical additions/changes:

```json
{
  "lob.enabled": "true",
  "lob.chunk.size": "102400",           // NEW: 100KB chunks for LOB data
  "lob.erase.poll.interval.ms": "0",
  
  "log.mining.continuous.mine": "true",
  "log.mining.select.all.tables": "false",  // CHANGED: Be specific about tables
  "log.mining.include.regex.table_list": "APPUSER.CDC_TEST",  // NEW
  
  "database.fetch.size": "5000",         // NEW: JDBC fetch size
  "jdbc.lob.chunk.size": "102400",       // NEW: JDBC LOB handling
  "jdbc.batch.size": "20000",            // NEW: Batch processing
  
  "post.processors": "reselectColumns",
  "post.processors.reselectColumns.type": "io.debezium.processors.reselect.ReselectColumnsPostProcessor",
  "post.processors.reselectColumns.reselect.columns.include.list": "APPUSER.CDC_TEST:DESCRIPTION,PAYLOAD_XML,BINARY_DATA"
}
```

### Step 3: Execution Order

#### Option A: Start Fresh (Recommended for Testing)
```powershell
# 1. Stop all containers
.\docker\compose\docker-compose down -v

# 2. Delete volumes to reset
docker volume rm cdc_scb_oracle-data cdc_scb_kafka-data

# 3. Update oracle init scripts to include LOB logging
# Place 04-configure-cdc-lob-logging.sql in docker/oracle/initdb/

# 4. Update connector configuration
# Copy oracle-source-FIXED.json to oracle-source.json

# 5. Start fresh
.\docker\compose\docker-compose up -d
```

#### Option B: Apply to Existing Setup
```sql
-- Run in Oracle container as SYSDBA
-- (If tables already exist)

ALTER SESSION SET CONTAINER = XEPDB1;

-- For each LOB column:
ALTER TABLE APPUSER.CDC_TEST MODIFY (DESCRIPTION LOB (CACHE LOGGING));
ALTER TABLE APPUSER.CDC_TEST MODIFY (PAYLOAD_XML LOB (CACHE LOGGING));
ALTER TABLE APPUSER.CDC_TEST MODIFY (BINARY_DATA LOB (CACHE LOGGING));

-- Then restart connector with updated config
```

### Step 4: Verify the Fix

After making changes, test with:

```powershell
# 1. Insert or update data
.\docker\connect\scripts\quick-insert-test.ps1
# or
.\docker\connect\scripts\quick-update-test.ps1

# 2. Verify CDC payload
.\docker\connect\scripts\verify-cdc-payload.ps1
```

Expected output should show actual data instead of `__debezium_unavailable_value`:

**Before Fix** ❌:
```json
{
  "DESCRIPTION": "__debezium_unavailable_value",
  "PAYLOAD_XML": "__debezium_unavailable_value",
  "BINARY_DATA": "__debezium_unavailable_value"
}
```

**After Fix** ✅:
```json
{
  "DESCRIPTION": "updated clob text for id 4",
  "PAYLOAD_XML": "<root><id>4</id><name>updated-name-2</name><status>updated</status></root>",
  "BINARY_DATA": "CAFEBABE"
}
```

## Key Configuration Parameters Explained

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `lob.enabled` | true | Enable LOB column capture |
| `lob.chunk.size` | 102400 | Read LOBs in 100KB chunks |
| `log.mining.select_all_tables` | false | Only monitor specified tables (better performance) |
| `log.mining.include.regex.table_list` | APPUSER.CDC_TEST | Specific table monitoring |
| `database.fetch.size` | 5000 | JDBC fetch size for result sets |
| `jdbc.lob.chunk.size` | 102400 | JDBC LOB chunk size matching LOB size |
| `post.processors.reselectColumns` | Enabled | Re-read LOBs from source table after capture |

## Common Issues & Troubleshooting

### Issue 1: `__debezium_unavailable_value` Still Appearing
```
Cause: Supplemental logging not applied
Solution: 
  1. Verify with: SELECT * FROM all_log_groups WHERE table_owner='APPUSER'
  2. Re-run the LOB logging SQL
  3. Restart connector
```

### Issue 2: Large LOB Handling Performance
```
Cause: Chunk size too large or too many concurrent LOBs
Solution:
  - Reduce lob.chunk.size to 51200 (50KB)
  - Increase jdbc.batch.size to 50000
  - Increase database.fetch.size to 10000
```

### Issue 3: Connector Crashes on LOB Columns
```
Cause: Memory overflow or JDBC driver issue
Solution:
  - Verify ojdbc11.jar in docker/connect/drivers/
  - Increase Connect container memory: -e _JAVA_OPTIONS="-Xmx2G"
  - Reduce lob.chunk.size to 51200
```

## Files Changed

1. ✅ Created: `docker/oracle/initdb/04-configure-cdc-lob-logging.sql`
2. 📝 Update: `docker/connect/connectors/oracle-source.json` (use oracle-source-FIXED.json as reference)
3. ✅ Created: `docker/connect/connectors/oracle-source-FIXED.json` (reference implementation)

## Related Documentation

- [Debezium Oracle Connector LOB Handling](https://debezium.io/documentation/reference/stable/connectors/oracle.html#oracle-logminer-lob)
- [Oracle Supplemental Logging Guide](https://docs.oracle.com/cd/E96310_01/ADMIN/configuring-oracle-database.html#GUID-8D5B3B23-D559-4FA2-B3AF-7E9DF1FA89E5)
- [Kafka Connect JDBC Configuration](https://debezium.io/documentation/reference/stable/development/connector-properties.html)

## Next Steps for RisingWave Integration

Once CDC payload verification shows full data (no unavailable values):
1. The same data flows to RisingWave
2. RisingWave materialized views will have access to complete LOB data
3. No additional transformation needed for LOB columns
4. Ensure RisingWave source table DDL matches Oracle schema with appropriate TEXT/STRING types for LOBs
