-- Oracle -> Kafka -> RisingWave CDC pipeline with end-to-end latency.
--
-- PREREQUISITE: run scripts/host/09-create-latency-topic.ps1 first.
-- The cdc_rw_echo topic must exist before step 5, or CREATE TABLE fails with
-- "topic cdc_rw_echo not found".
--
-- Why the design looks like this
-- -----------------------------
-- PROCTIME() is NOT used anywhere. It is a barrier/epoch clock, not a wall
-- clock: on this pipeline it was measured reading 528 ms EARLY on one event and
-- 1005 ms LATE on another, and 12 messages produced 250 ms apart collapsed onto
-- 3 distinct values. It cannot be corrected for, so it is replaced by sinking
-- back through Kafka, where RisingWave's own producer stamps a real wall clock.
--
-- The join key is Kafka partition + offset (the message identity). The earlier
-- key -- entry_id plus commit_ts_ms -- collided whenever two changes hit the
-- same row within one second, because commit_ts_ms has 1-second resolution.
-- That collision was the original source of negative latency values.
--
-- Known limitations
-- -----------------
-- 1. source.commit_ts_ms is truncated to whole seconds by LogMiner (verify:
--    SELECT DISTINCT oracle_commit_ts_ms % 1000 FROM ...  -> 0). So
--    debezium_to_kafka_ms and kafka_to_risingwave_ms are millisecond-accurate,
--    but oracle_to_debezium_ms and oracle_to_risingwave_ms carry +/-1000 ms.
--    Removing that needs a source-side timestamp column (SRC_TS TIMESTAMP(6)),
--    which would be a schema change to APPUSER.STMT_ENTRY.
-- 2. rw_echo_ts marks when RisingWave PROCESSED the row, not when it became
--    queryable. Measured against a single-process reference probe, it runs
--    about 50 ms early (sink reported 31-101 ms where queryable was ~122 ms).
--    Read kafka_to_risingwave_ms as "Connect produced -> RisingWave processed".

-- ============================================================================
-- DROP (reverse dependency order; the sink must go before the MV it reads)
-- ============================================================================
DROP MATERIALIZED VIEW IF EXISTS cdc_stmt_entry_final;
DROP MATERIALIZED VIEW IF EXISTS cdc_stmt_entry_latency_full;
DROP TABLE IF EXISTS cdc_rw_echo;
DROP SINK IF EXISTS cdc_rw_echo_sink;
DROP MATERIALIZED VIEW IF EXISTS cdc_stmt_entry_latency;
DROP TABLE IF EXISTS cdc_stmt_entry_audit;
DROP TABLE IF EXISTS cdc_stmt_entry_main;

-- ============================================================================
-- 1. BUSINESS DATA. 'earliest' rebuilds full state from topic history.
--    FORMAT DEBEZIUM applies insert/update/delete as upserts.
-- ============================================================================
CREATE TABLE cdc_stmt_entry_main (
    entry_id              VARCHAR PRIMARY KEY,
    account_number        VARCHAR,
    booking_date          TIMESTAMP,
    txn_code              VARCHAR,
    amount                DECIMAL,
    currency              VARCHAR,
    txn_metadata          VARCHAR,
    audit_trail           VARCHAR,
    digital_receipt       BYTEA,
    txn_metadata_binary   BYTEA
)
WITH (
    connector = 'kafka',
    topic = 'T24.APPUSER.STMT_ENTRY',
    properties.bootstrap.server = 'kafka:9092',
    scan.startup.mode = 'earliest'
)
FORMAT DEBEZIUM ENCODE JSON;

-- ============================================================================
-- 2. RAW CDC ENVELOPE.
--    'latest' is deliberate: 'earliest' replays old messages and stamps them
--    with the current time, which produced 16-minute phantom latencies.
-- ============================================================================
CREATE TABLE cdc_stmt_entry_audit (
    op        VARCHAR,
    "before"  JSONB,
    "after"   JSONB,
    source    JSONB,
    ts_ms     BIGINT
)
INCLUDE timestamp AS kafka_ts
INCLUDE partition AS kafka_partition
INCLUDE offset    AS kafka_offset
WITH (
    connector = 'kafka',
    topic = 'T24.APPUSER.STMT_ENTRY',
    properties.bootstrap.server = 'kafka:9092',
    scan.startup.mode = 'latest'
)
FORMAT PLAIN ENCODE JSON;

-- ============================================================================
-- 3. LEAN PER-EVENT STREAM. This is what gets echoed back through Kafka.
-- ============================================================================
CREATE MATERIALIZED VIEW cdc_stmt_entry_latency AS
SELECT
    kafka_partition,
    kafka_offset,
    COALESCE("after" ->> 'ENTRY_ID', "before" ->> 'ENTRY_ID') AS entry_id,
    op,
    source ->> 'commit_scn'             AS commit_scn,
    (source ->> 'commit_ts_ms')::BIGINT AS oracle_commit_ts_ms,   -- 1s resolution
    ts_ms                               AS debezium_ts_ms,
    kafka_ts
FROM cdc_stmt_entry_audit
WHERE op IN ('c','u','d');       -- excludes snapshot 'r' and null tombstones

-- ============================================================================
-- 4. ECHO OUT. RisingWave's own Kafka producer stamps CreateTime with a real
--    wall clock. This is the valid replacement for PROCTIME().
-- ============================================================================
CREATE SINK cdc_rw_echo_sink FROM cdc_stmt_entry_latency
WITH (
    connector = 'kafka',
    topic = 'cdc_rw_echo',
    properties.bootstrap.server = 'kafka:9092'
)
FORMAT PLAIN ENCODE JSON (force_append_only = 'true');

-- ============================================================================
-- 5. ECHO BACK IN. rw_echo_ts is that wall clock, now an ordinary column.
--    Requires the topic from 09-create-latency-topic.ps1.
-- ============================================================================
CREATE TABLE cdc_rw_echo (
    kafka_partition VARCHAR,
    kafka_offset    VARCHAR,
    entry_id        VARCHAR
)
INCLUDE timestamp AS rw_echo_ts
WITH (
    connector = 'kafka',
    topic = 'cdc_rw_echo',
    properties.bootstrap.server = 'kafka:9092',
    scan.startup.mode = 'latest'
)
FORMAT PLAIN ENCODE JSON;

-- ============================================================================
-- 6. PER-EVENT LATENCY.
-- ============================================================================
CREATE MATERIALIZED VIEW cdc_stmt_entry_latency_full AS
SELECT
    l.entry_id, l.op, l.commit_scn,
    l.kafka_partition, l.kafka_offset,
    l.oracle_commit_ts_ms,
    l.debezium_ts_ms,
    l.kafka_ts,
    e.rw_echo_ts,

    l.debezium_ts_ms - l.oracle_commit_ts_ms                          AS oracle_to_debezium_ms,
    (EXTRACT(EPOCH FROM l.kafka_ts)*1000)::BIGINT - l.debezium_ts_ms  AS debezium_to_kafka_ms,
    (EXTRACT(EPOCH FROM e.rw_echo_ts)*1000)::BIGINT
      - (EXTRACT(EPOCH FROM l.kafka_ts)*1000)::BIGINT                 AS kafka_to_risingwave_ms,
    (EXTRACT(EPOCH FROM e.rw_echo_ts)*1000)::BIGINT
      - l.oracle_commit_ts_ms                                         AS oracle_to_risingwave_ms
FROM cdc_stmt_entry_latency l
JOIN cdc_rw_echo e
  ON l.kafka_partition = e.kafka_partition
 AND l.kafka_offset    = e.kafka_offset;

-- ============================================================================
-- 7. BUSINESS VIEW FOR SUPERSET: latest state + its measured latency.
-- ============================================================================
CREATE MATERIALIZED VIEW cdc_stmt_entry_final AS
WITH latest_event AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY entry_id ORDER BY rw_echo_ts DESC) AS rn
    FROM cdc_stmt_entry_latency_full
)
SELECT
    s.entry_id, s.account_number, s.booking_date, s.txn_code, s.amount, s.currency,
    (regexp_match(s.txn_metadata, '<vendor>([^<]+)</vendor>'))[1]           AS vendor,
    (regexp_match(s.txn_metadata, '<channel>([^<]+)</channel>'))[1]         AS channel,
    (regexp_match(s.txn_metadata, '<terminal_id>([^<]+)</terminal_id>'))[1] AS terminal_id,
    s.audit_trail, s.digital_receipt, s.txn_metadata_binary,
    'oracle' AS source_name,
    e.op, e.commit_scn,
    e.oracle_commit_ts_ms, e.debezium_ts_ms, e.kafka_ts, e.rw_echo_ts,
    e.oracle_to_debezium_ms, e.debezium_to_kafka_ms,
    e.kafka_to_risingwave_ms, e.oracle_to_risingwave_ms
FROM cdc_stmt_entry_main s
LEFT JOIN latest_event e ON s.entry_id = e.entry_id AND e.rn = 1;

-- ============================================================================
-- VERIFY (run after inserting a row in Oracle; MVs start empty because the
-- instrument tables use scan.startup.mode = 'latest')
-- ============================================================================
-- SELECT entry_id, op,
--        oracle_to_debezium_ms   AS a_logminer,
--        debezium_to_kafka_ms    AS b_kafka,
--        kafka_to_risingwave_ms  AS c_risingwave,
--        oracle_to_risingwave_ms AS total_ms
-- FROM cdc_stmt_entry_latency_full
-- ORDER BY rw_echo_ts DESC;
--
-- SELECT entry_id, amount, vendor, channel, op,
--        oracle_to_risingwave_ms AS total_latency_ms
-- FROM cdc_stmt_entry_final
-- WHERE oracle_to_risingwave_ms IS NOT NULL
-- ORDER BY rw_echo_ts DESC;
