# Live demo script: CDC Streaming Pipeline

This script is the live part of `CDC_Project_Presentation.pptx`. Steps 1–7 match the seven steps on slide 19 ("Watch one row travel: insert, update, delete"). Budget: 7 minutes.

The demo runs against the Minikube stack in namespace `cdc-scb`. Every command below was written against the live schema of `APPUSER.STMT_ENTRY` (11 columns, including `SRC_TS_US`) and the RisingWave objects that exist in the cluster on 27 Sep 2026. **Rehearse every step on the day.** Nothing here has been executed as a full dry run yet.

> Never show `.env`, `k8s/secrets/*.yaml` or the connector JSON on the projector: they contain plaintext credentials (see PRESENTATION_QA.md).

---

## 0. What the audience should leave believing

1. A change committed in Oracle shows up, queryable, in RisingWave within about 3 seconds.
2. Updates and deletes are applied as changes, not appended as duplicates.
3. XML, CLOB and BLOB values arrive intact, but the *old* LOB value is not available on updates.
4. We can say exactly where the seconds went, stage by stage.

---

## 1. Setup

### The day before

- [ ] Rehearse steps 1–7 end to end, twice, with rehearsal IDs (`DEMO-R1`, `DEMO-R2`). Delete those rows afterwards.
- [ ] Record a screen capture of one successful rehearsal. It is the fallback if the live demo fails, and must be introduced as a recording.
- [ ] Fix the Superset latency chart. The `cdc_latency_stages` dataset includes two manual test inserts (`TXN_2028`) whose `SRC_TS_US` is a dummy value, which yields a ~56-year "latency". Add `AND src_ts_us > 1700000000000000` to each `WHERE` in the dataset SQL, or do not open that chart.
- [ ] Decide the demo row ID. This script uses `DEMO-0001`. If it already exists, the INSERT fails with ORA-00001; use the next number.
- [ ] Set up the DBeaver connections (credentials come from `k8s/secrets/`, not from this file):
  - Oracle: `localhost:1521`, service name `XEPDB1`, user `APPUSER`. The password is `ORACLE_APP_PASSWORD` in `oracle-secret.yaml`.
  - RisingWave: PostgreSQL driver, `localhost:4566`, database `dev`, user `root`, no password.

### 60 minutes before: start the stack

Run from the repository root:

```powershell
.\scripts\host\10-start-minikube.ps1
```

This starts Minikube with 4 CPUs, waits for every pod to be Ready, and port-forwards Oracle 1521, Kafka 9092, Connect 8083, RisingWave 4566 and 5691, Kafdrop 9000 and Superset 8088 to `localhost`.

```powershell
kubectl get pods -n cdc-scb
```

Expected: `oracle-0`, `kafka-0`, `risingwave-0`, `superset-db-0`, `connect-…`, `superset-…` and `kafdrop-…` show `1/1 Running`. Oracle can take several minutes to open after a cold start.

### 30 minutes before: prove the pipeline is streaming

```powershell
Invoke-RestMethod http://localhost:8083/connectors/oracle-cdc-connector/status
```

Expected: `connector.state = RUNNING` and `tasks[0].state = RUNNING`. You can also run `.\docker\connect\scripts\check-connector-status.ps1`, which calls the same endpoint.

```powershell
kubectl logs -n cdc-scb deploy/connect --since=30m | Select-String "Starting streaming|Snapshot|typeName|ERROR"
```

Expected: `Starting streaming`, and no `typeName` error. If you see snapshot messages, wait until they finish. After a connector failure, the healer CronJob resets offsets and forces a re-snapshot of all ~100,000 rows.

Then do a smoke test: run steps 1, 4 and 6 once with ID `DEMO-R0`, and confirm the row appears in RisingWave and disappears again.

### 10 minutes before: screen layout

| Window | What is open |
| --- | --- |
| DBeaver, tab 1 | Oracle editor with the step 1, 5 and 6 SQL pasted, not yet executed |
| DBeaver, tab 2 | RisingWave editor with query Q1 (step 4). Set the result auto-refresh to 1 s: results panel, refresh drop-down |
| DBeaver, tab 3 | RisingWave editor with queries Q2 and Q3 (steps 5–7) |
| Browser tab 1 | Kafdrop: `http://localhost:9000`, then topic `T24.APPUSER.STMT_ENTRY` |
| Browser tab 2 | Superset dashboard "CDC Proof Of Concept": `http://localhost:8088` |
| Terminal | Optional: the Kafka console consumer from step 2 |
| PowerPoint | Slide 19, plus slides 12–15 ready for the fallback |

---

## 2. The demo, step by step

### Step 1 — Modify Oracle (slide 19, step 1)

**Action.** In the Oracle editor, insert one statement-entry row with XML, CLOB and BLOB values, then commit. The row carries its own microsecond timestamp (`SRC_TS_US`), exactly as in the benchmark.

**SQL** (DBeaver, as APPUSER):

```sql
INSERT INTO appuser.stmt_entry
  (entry_id, account_number, booking_date, txn_code, amount, currency,
   txn_metadata, audit_trail, digital_receipt, txn_metadata_binary, src_ts_us)
SELECT 'DEMO-0001', '200000000999999', TRUNC(SYSDATE), 'PAY', 1250.75, 'EGP',
       XMLTYPE('<transaction><vendor>VENDOR_DEMO</vendor><channel>CHANNEL_LIVE</channel><terminal_id>TXN_42</terminal_id></transaction>'),
       'LOB AUDIT RECORD - live demo',
       UTL_RAW.CAST_TO_RAW('DIGITAL_RECEIPT_DEMO'),
       UTL_RAW.CAST_TO_RAW('<transaction><vendor>VENDOR_DEMO</vendor><channel>CHANNEL_LIVE</channel><terminal_id>TXN_42</terminal_id></transaction>'),
       ROUND((EXTRACT(DAY FROM d) * 86400 + EXTRACT(HOUR FROM d) * 3600
            + EXTRACT(MINUTE FROM d) * 60 + EXTRACT(SECOND FROM d)) * 1000000)
FROM (SELECT SYS_EXTRACT_UTC(SYSTIMESTAMP) - TIMESTAMP '1970-01-01 00:00:00' AS d FROM dual);
COMMIT;
```

**CLI fallback** (PowerShell; the here-string's closing `'@` must stay at column 0):

```powershell
@'
ALTER SESSION SET CONTAINER = XEPDB1;
INSERT INTO appuser.stmt_entry (entry_id, account_number, booking_date, txn_code, amount, currency, txn_metadata, audit_trail, digital_receipt, txn_metadata_binary, src_ts_us)
SELECT 'DEMO-0001', '200000000999999', TRUNC(SYSDATE), 'PAY', 1250.75, 'EGP', XMLTYPE('<transaction><vendor>VENDOR_DEMO</vendor><channel>CHANNEL_LIVE</channel><terminal_id>TXN_42</terminal_id></transaction>'), 'LOB AUDIT RECORD - live demo', UTL_RAW.CAST_TO_RAW('DIGITAL_RECEIPT_DEMO'), UTL_RAW.CAST_TO_RAW('<transaction><vendor>VENDOR_DEMO</vendor><channel>CHANNEL_LIVE</channel><terminal_id>TXN_42</terminal_id></transaction>'), ROUND((EXTRACT(DAY FROM d) * 86400 + EXTRACT(HOUR FROM d) * 3600 + EXTRACT(MINUTE FROM d) * 60 + EXTRACT(SECOND FROM d)) * 1000000)
FROM (SELECT SYS_EXTRACT_UTC(SYSTIMESTAMP) - TIMESTAMP '1970-01-01 00:00:00' AS d FROM dual);
COMMIT;
EXIT;
'@ | kubectl exec -i -n cdc-scb oracle-0 -- sqlplus -s / as sysdba
```

**Expected result.** `1 row inserted`, then `Commit complete`.

**What to say.** "This is an ordinary transaction against the source table: an amount, an XML document, a CLOB and a BLOB. Nothing in the application knows that CDC exists."

**Business meaning.** Capture needs no change to the application or to T24's write path.

### Step 2 — Capture (slide 19, step 2)

**Action.** Nothing to type. Talk while Debezium picks the change up. To make capture visible, start this consumer *before* step 1; it waits for the next event:

```powershell
$line = kubectl exec -n cdc-scb kafka-0 -- kafka-console-consumer --bootstrap-server localhost:9092 --topic T24.APPUSER.STMT_ENTRY --partition 0 --offset latest --max-messages 1 --timeout-ms 120000
$evt = $line | ConvertFrom-Json
$evt | Select-Object op, ts_ms, @{n='commit_scn'; e={$_.source.commit_scn}}
```

**Expected result.** Within about 2–3 seconds of the commit, the consumer returns one event with `op = c` and a `commit_scn`.

**What to say.** "Oracle has written the change to its redo log. Debezium reads that log through LogMiner in batches, about every three seconds. This is where most of our latency lives, as slide 12 showed."

**Business meaning.** The source database is read through its log, not by repeated queries.

### Step 3 — Kafka (slide 19, step 3)

**Action.** In Kafdrop, open the topic `T24.APPUSER.STMT_ENTRY`, choose View Messages, and go to the newest offset. Or show `$evt` from step 2:

```powershell
$evt.after | Format-List ENTRY_ID, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT
```

**Expected result.**
- `op` is `c`, `before` is null, and `after` holds every column.
- `AMOUNT` is the string `"1250.75"`, because `decimal.handling.mode = string`.
- `TXN_METADATA` is the XML as text; `AUDIT_TRAIL` is the text.
- `DIGITAL_RECEIPT` is base64: `RElHSVRBTF9SRUNFSVBUX0RFTU8=` is `DIGITAL_RECEIPT_DEMO`.

**What to say.** "This is Debezium's envelope: operation, before image, after image and the source position. Kafka keeps it for seven days, so any consumer can replay it."

**Business meaning.** One captured stream can feed many consumers without touching Oracle again.

### Step 4 — RisingWave (slide 19, step 4)

**Action.** Point at the auto-refreshing RisingWave tab.

**Q1** (RisingWave, auto-refresh 1 s):

```sql
SELECT entry_id, amount, currency, txn_code, audit_trail,
       convert_from(digital_receipt, 'UTF8') AS digital_receipt,
       txn_metadata
FROM cdc_stmt_entry_main
WHERE entry_id = 'DEMO-0001';
```

Optionally, the business view, with the XML fields extracted:

```sql
SELECT entry_id, amount, vendor, channel, terminal_id
FROM cdc_stmt_entry_final
WHERE entry_id = 'DEMO-0001';
```

**CLI fallback:**

```powershell
@'
SELECT entry_id, amount, currency, audit_trail, convert_from(digital_receipt, 'UTF8') AS digital_receipt, txn_metadata FROM cdc_stmt_entry_main WHERE entry_id = 'DEMO-0001';
'@ | kubectl exec -i -n cdc-scb superset-db-0 -- psql -h risingwave -p 4566 -U root -d dev
```

**Expected result.** One row appears, usually about 3 s after the commit; up to about 6 s is normal (P99 is 5.6 s). The CLOB text, the BLOB bytes and the XML match what was inserted. The business view shows `VENDOR_DEMO`, `CHANNEL_LIVE` and `TXN_42`.

**What to say.** "The row is queryable in a Postgres-compatible database, and the view has already parsed the XML. Nobody ran a batch job."

**Business meaning.** Fresh, queryable data and transformations in SQL that analysts already know.

### Step 5 — Update (slide 19, step 5)

**Action.** Change only the amount. Stamp a fresh source timestamp, so the update's latency is measured too.

```sql
UPDATE appuser.stmt_entry
   SET amount    = 9999.99,
       src_ts_us = (SELECT ROUND((EXTRACT(DAY FROM d) * 86400 + EXTRACT(HOUR FROM d) * 3600
                                + EXTRACT(MINUTE FROM d) * 60 + EXTRACT(SECOND FROM d)) * 1000000)
                      FROM (SELECT SYS_EXTRACT_UTC(SYSTIMESTAMP) - TIMESTAMP '1970-01-01 00:00:00' AS d FROM dual))
 WHERE entry_id = 'DEMO-0001';
COMMIT;
```

Then show the raw envelope.

**Q2** (RisingWave):

```sql
SELECT op,
       "before" ->> 'AMOUNT'      AS before_amount,
       "after"  ->> 'AMOUNT'      AS after_amount,
       "before" ->> 'AUDIT_TRAIL' AS before_clob,
       "after"  ->> 'AUDIT_TRAIL' AS after_clob,
       kafka_offset
FROM cdc_stmt_entry_audit
WHERE COALESCE("after" ->> 'ENTRY_ID', "before" ->> 'ENTRY_ID') = 'DEMO-0001'
ORDER BY kafka_offset::bigint;
```

**Expected result.** This follows the team's B4 and B7 tests; confirm it in rehearsal.
- Q1 shows `amount = 9999.99` in a single row, with no duplicate.
- In Q2 the `u` event has `before_amount = 1250.75` and `after_amount = 9999.99`.
- `after_clob` still holds the CLOB text, re-selected from Oracle.
- `before_clob` is `__debezium_unavailable_value`.
- For the BLOB column, the placeholder appears base64-encoded: `X19kZWJleml1bV91bmF2YWlsYWJsZV92YWx1ZQ==`.

**What to say.** "The update replaced the row; it did not add a second one. And here is the limitation from slide 11, live: the new LOB value is complete, because Debezium re-read it from Oracle, but the old LOB value does not exist in the event."

**Business meaning.** Current state is exact, but use cases that need old LOB values, such as audit or diff, need another design.

### Step 6 — Delete (slide 19, step 6)

```sql
DELETE FROM appuser.stmt_entry WHERE entry_id = 'DEMO-0001';
COMMIT;
```

**Expected result.**
- Within about 3 s, Q1 returns no rows.
- Q2 shows a `d` event, whose `before` holds the old scalar values, followed by a tombstone: a row with an empty `op`.

**What to say.** "Deletes are applied as deletes. The row is gone from RisingWave, and Kafka carries both the delete event and a tombstone that lets compacted topics forget the key."

**Business meaning.** No stale rows downstream, which is the difference between CDC and append-only extraction.

### Step 7 — Latency (slide 19, step 7)

**Q3** (RisingWave):

```sql
SELECT op,
       round(oracle_to_debezium_ms)   AS capture_ms,
       debezium_to_kafka_ms           AS handoff_ms,
       kafka_to_risingwave_ms         AS processing_ms,
       round(oracle_to_risingwave_ms) AS total_ms,
       oracle_to_risingwave_1s_ms     AS total_ms_1s_resolution
FROM cdc_stmt_entry_latency_full
WHERE entry_id = 'DEMO-0001'
ORDER BY kafka_offset::bigint;
```

**Expected result.**
- The `c` and `u` rows show capture ≈ 1–4 s, hand-off ≤ 0.5 s and processing ≤ 1 s, and the three add up to `total_ms`, typically around 3 s.
- The `d` row has no microsecond timestamp: a delete has no after image. Only `total_ms_1s_resolution` is filled, and it reads up to about 1 s high.

**What to say.** "Every event carries four timestamps, so we can split its latency by stage. Capture dominates, exactly as in the 100,000-event benchmark."

**Business meaning.** We know which knob to turn: Oracle capture, not Kafka or RisingWave.

### Close

Switch back to PowerPoint: slide 20, production evolution.

---

## 3. Reset between rehearsals

```sql
DELETE FROM appuser.stmt_entry WHERE entry_id LIKE 'DEMO-%';
COMMIT;
```

Past events remain in Kafka and in RisingWave's append-only latency tables. That is expected and harmless. Use a new ID for each run.

---

## 4. Emergency recovery

| Symptom | Likely cause | What to do on stage |
| --- | --- | --- |
| Row not in RisingWave after 10 s | Connector not streaming, or RisingWave lagging | Check Kafdrop. If the event is in Kafka, give RisingWave 5 more seconds. If it is not, run the connector status call from §1. Talk through slide 12 while waiting. |
| Connector `FAILED`, or a `typeName` error | Known XMLTYPE schema-history bug after a restart | The healer CronJob resets it within about 1 minute, followed by a re-snapshot that can take minutes. Switch to the fallback. |
| `ORA-00001` on INSERT | Demo ID already used | Change the ID to `DEMO-0002` in all four statements. |
| DBeaver cannot connect | Port-forward died | Re-run `.\scripts\host\10-start-minikube.ps1`: it restarts every forward. Use the CLI fallbacks meanwhile. |
| Pods not Ready | Cold start; Oracle opening | `kubectl get pods -n cdc-scb`. Oracle can take minutes. Do not restart pods on stage. |
| Superset latency chart shows absurd values | Dummy-timestamp test rows (`TXN_2028`) | Skip the chart, or apply the dataset filter from §1. |

**Fallback, if live CDC fails.** Say so plainly: "The live environment is not cooperating; here is the same flow recorded on 27 September." Then show the rehearsal recording, and slides 12–15, which hold the recorded 100,000-event results. Never present a recording as live.
