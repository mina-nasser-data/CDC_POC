# CDC Pipeline Setup Checklist - LOB Column Fix

## Phase 1: Oracle Database Setup ✓

- [ ] Stop all containers: `docker-compose down`
- [ ] Delete volumes: `docker volume rm cdc_scb_oracle-data cdc_scb_kafka-data`
- [ ] Create/update file: `docker/oracle/initdb/04-configure-cdc-lob-logging.sql`
- [ ] Verify file contents include:
  - [ ] `ALTER TABLE APPUSER.CDC_TEST ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;`
  - [ ] `ALTER TABLE APPUSER.CDC_TEST MODIFY (DESCRIPTION LOB (CACHE LOGGING));`
  - [ ] `ALTER TABLE APPUSER.CDC_TEST MODIFY (PAYLOAD_XML LOB (CACHE LOGGING));`
  - [ ] `ALTER TABLE APPUSER.CDC_TEST MODIFY (BINARY_DATA LOB (CACHE LOGGING));`

## Phase 2: Connector Configuration ✓

- [ ] Update: `docker/connect/connectors/oracle-source.json`
- [ ] Add/verify these properties:
  ```json
  "lob.enabled": "true",
  "lob.chunk.size": "102400",
  "log.mining.select.all.tables": "false",
  "log.mining.include.regex.table.list": "APPUSER.CDC_TEST",
  "database.fetch.size": "5000",
  "jdbc.lob.chunk.size": "102400",
  "jdbc.batch.size": "20000"
  ```
- [ ] Verify `post.processors` configuration is present for LOB re-reading
- [ ] Backup original config (save as oracle-source-BACKUP.json)

## Phase 3: Container Startup ✓

- [ ] Start containers: `docker-compose up -d` from `docker/compose/`
- [ ] Wait for Oracle to be healthy: `docker logs oracle` (wait ~2 min)
- [ ] Wait for Kafka to be healthy: `docker logs kafka` (wait ~30s)
- [ ] Wait for Connect to be healthy: `docker logs connect` (wait ~1 min)
- [ ] Verify all containers running: `docker ps | grep oracle|kafka|connect`

## Phase 4: Connector Registration ✓

- [ ] Register connector: `.\docker\connect\scripts\register-oracle-connector.ps1`
- [ ] Check connector status: `.\docker\connect\scripts\check-connector-status.ps1`
- [ ] Verify response shows state: "RUNNING" or "PROVISIONING"

## Phase 5: CDC Functionality Test ✓

- [ ] Run INSERT test: `.\docker\connect\scripts\quick-insert-test.ps1`
- [ ] Verify payload has full data: `.\docker\connect\scripts\verify-cdc-payload.ps1`
- [ ] Check that LOB columns contain actual data (NOT `__debezium_unavailable_value`)

- [ ] Run UPDATE test: `.\docker\connect\scripts\quick-update-test.ps1`
- [ ] Verify payload has before/after values: `.\docker\connect\scripts\verify-cdc-payload.ps1`
- [ ] Check before/after have full LOB data

## Phase 6: Verification Criteria ✓

**Expected Outcomes - All Must Pass**:

- [ ] DESCRIPTION column shows actual CLOB text (not `__debezium_unavailable_value`)
- [ ] PAYLOAD_XML column shows XML content (not `__debezium_unavailable_value`)
- [ ] BINARY_DATA column shows hex values (not `__debezium_unavailable_value`)
- [ ] Kafka messages parse as valid JSON with `payload.before` and `payload.after`
- [ ] For UPDATE operations, both before and after values present
- [ ] No errors in connector logs: `docker logs connect | grep -i "error"`
- [ ] Topic exists: `docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list | grep oracle21`

## Phase 7: Troubleshooting (If Needed)

- [ ] Check Oracle supplemental logging:
  ```sql
  SELECT * FROM all_log_groups WHERE table_owner='APPUSER';
  ```
  Expected: Should show log groups for APPUSER.CDC_TEST

- [ ] Check Debezium connector logs:
  ```powershell
  docker logs connect -f | Select-String -Pattern "ERROR|WARN|LOB"
  ```

- [ ] Reset connector if needed:
  ```powershell
  .\docker\connect\scripts\delete-oracle-connector.ps1
  .\docker\connect\scripts\register-oracle-connector.ps1
  ```

- [ ] Check Kafka topic content directly:
  ```bash
  docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 \
    --topic oracle21.APPUSER.CDC_TEST --from-beginning --max-messages 5
  ```

## Phase 8: Ready for RisingWave

Once all verifications pass:

- [ ] Create RisingWave source table with TEXT/STRING types for LOB columns
- [ ] Start RisingWave: `.\scripts\host\04-start-risingwave.ps1`
- [ ] Verify source creation in RisingWave
- [ ] Create materialized views based on source
- [ ] Test with UPDATE to verify full LOB data in RisingWave

## Files Modified

| File | Changes |
|------|---------|
| `docker/oracle/initdb/04-configure-cdc-lob-logging.sql` | NEW - table supplemental logging config |
| `docker/connect/connectors/oracle-source.json` | UPDATED - LOB parameters |
| `docs/LOB-UNAVAILABLE-VALUE-FIX.md` | NEW - Detailed explanation |
| `docker/connect/connectors/oracle-source-FIXED.json` | NEW - Reference implementation |

## Quick Command Reference

```powershell
# Full reset and test
cd d:\work\Suez Canal Bank\Project 1 - Streaming ELT\CDC_SCB
docker-compose -f docker\compose\docker-compose.yml down -v
docker-compose -f docker\compose\docker-compose.yml up -d
Start-Sleep -Seconds 180
.\docker\connect\scripts\register-oracle-connector.ps1
Start-Sleep -Seconds 10
.\docker\connect\scripts\quick-insert-test.ps1
.\docker\connect\scripts\verify-cdc-payload.ps1
```

## Success Indicators

✅ When complete, you should see:
- Kafka topic `oracle21.APPUSER.CDC_TEST` populated
- JSON messages with full payload including actual LOB data
- No `__debezium_unavailable_value` in any CLOB/XML/BLOB fields
- Ready to consume in RisingWave with complete data
