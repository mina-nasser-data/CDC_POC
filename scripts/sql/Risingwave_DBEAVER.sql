--##############################################################################################################################
--##############################################################################################################################
-- 														ORACLE
--##############################################################################################################################
--##############################################################################################################################
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
-- 1. BUSINESS DATA.  'earliest' = rebuild full state from topic history.
--    FORMAT DEBEZIUM applies insert/update/delete as upserts.
--    (SRC_TS_US is not declared here: the extra JSON field is simply ignored.)
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

select * from cdc_stmt_entry_main
-- ============================================================================
-- 2. RAW CDC ENVELOPE.
--    partition + offset = the Kafka message identity, a globally unique event
--    key.  The old key (entry_id + commit_ts_ms) collided whenever two changes
--    hit the same row inside one second -- the original negative-latency bug.
--    'latest' is deliberate: 'earliest' would replay old messages.
--    Create this table BEFORE starting the insert run: with 'latest', events
--    produced before it exists are skipped and can never be measured.
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

select * from cdc_stmt_entry_audit

-- ============================================================================
-- 3. LEAN PER-EVENT STREAM.  This is what gets echoed back through Kafka.
--    src_ts_us = Oracle clock (UTC epoch microseconds) taken by the insert
--    script just before the INSERT.  Debezium delivers it as a JSON string
--    (decimal.handling.mode=string), hence the ::BIGINT cast.
-- ============================================================================
CREATE MATERIALIZED VIEW cdc_stmt_entry_latency AS
SELECT
    kafka_partition,
    kafka_offset,
    COALESCE("after" ->> 'ENTRY_ID', "before" ->> 'ENTRY_ID') AS entry_id,
    op,
    source ->> 'commit_scn'             AS commit_scn,
    (source ->> 'commit_ts_ms')::BIGINT AS oracle_commit_ts_ms,   -- 1s resolution, kept for comparison only
    ("after" ->> 'SRC_TS_US')::BIGINT   AS src_ts_us,             -- microsecond Oracle timestamp
    ts_ms                               AS debezium_ts_ms,
    kafka_ts
FROM cdc_stmt_entry_audit
WHERE op IN ('c','u','d');       -- excludes snapshot 'r' and null tombstones

-- ============================================================================
-- 4. ECHO OUT.  RisingWave's OWN Kafka producer stamps CreateTime with a real
--    wall clock.  This is the valid replacement for PROCTIME(), which is a
--    barrier-epoch clock measured running 528 ms early and 1005 ms late.
-- ============================================================================
CREATE SINK cdc_rw_echo_sink FROM cdc_stmt_entry_latency
WITH (
    connector = 'kafka',
    topic = 'cdc_rw_echo',
    properties.bootstrap.server = 'kafka:9092'
)
FORMAT PLAIN ENCODE JSON (force_append_only = 'true');

-- ============================================================================
-- 5. ECHO BACK IN.  rw_echo_ts is that wall clock, now an ordinary column.
--    Requires the Kafka topic cdc_rw_echo to exist (it does).
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
-- 6. PER-EVENT LATENCY.  Every segment from a real wall clock.
--    Start of the Oracle segments = src_ts_us (microseconds).  The *_1s_ms
--    columns use LogMiner's whole-second commit time; they exist only so you can
--    see the quantization error (they are 0..1000 ms higher).  Do not report
--    them as latency.
--    debezium_to_kafka_ms / kafka_to_risingwave_ms are unchanged.
-- ============================================================================
CREATE MATERIALIZED VIEW cdc_stmt_entry_latency_full AS
SELECT
    l.entry_id, l.op, l.commit_scn,
    l.kafka_partition, l.kafka_offset,
    l.oracle_commit_ts_ms,
    l.src_ts_us,
    l.debezium_ts_ms,
    l.kafka_ts,
    e.rw_echo_ts,

    (l.debezium_ts_ms * 1000 - l.src_ts_us) / 1000.0                  AS oracle_to_debezium_ms,
    (EXTRACT(EPOCH FROM l.kafka_ts)*1000)::BIGINT - l.debezium_ts_ms  AS debezium_to_kafka_ms,
    (EXTRACT(EPOCH FROM e.rw_echo_ts)*1000)::BIGINT
      - (EXTRACT(EPOCH FROM l.kafka_ts)*1000)::BIGINT                 AS kafka_to_risingwave_ms,
    ((EXTRACT(EPOCH FROM e.rw_echo_ts)*1000)::BIGINT * 1000
      - l.src_ts_us) / 1000.0                                         AS oracle_to_risingwave_ms,

    l.debezium_ts_ms - l.oracle_commit_ts_ms                          AS oracle_to_debezium_1s_ms,
    (EXTRACT(EPOCH FROM e.rw_echo_ts)*1000)::BIGINT
      - l.oracle_commit_ts_ms                                         AS oracle_to_risingwave_1s_ms
FROM cdc_stmt_entry_latency l
JOIN cdc_rw_echo e
  ON l.kafka_partition = e.kafka_partition
 AND l.kafka_offset    = e.kafka_offset;

-- ============================================================================
-- 7. BUSINESS VIEW FOR SUPERSET: latest state + its measured latency.
--    Heaviest object (join + ROW_NUMBER + regexp on the XML).  For an
--    uncontended benchmark, create THIS one after the run has finished.
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
    e.oracle_commit_ts_ms, e.src_ts_us, e.debezium_ts_ms, e.kafka_ts, e.rw_echo_ts,
    e.oracle_to_debezium_ms, e.debezium_to_kafka_ms,
    e.kafka_to_risingwave_ms, e.oracle_to_risingwave_ms,
    e.oracle_to_debezium_1s_ms, e.oracle_to_risingwave_1s_ms
FROM cdc_stmt_entry_main s
LEFT JOIN latest_event e ON s.entry_id = e.entry_id AND e.rn = 1;


SELECT count(*)
FROM cdc_stmt_entry_final
WHERE oracle_to_risingwave_1s_ms IS NULL;

select count(*) from cdc_stmt_entry_final
--##############################################################################################################################
--CREATING Materialized View for oracle
--##############################################################################################################################




select 'Insert Benchmark ' as type_of_benchmark, min(oracle_to_risingwave_ms) as minimum_latency,round(avg(oracle_to_risingwave_ms),0) as 
average_latency ,percentile_cont(0.5) WITHIN GROUP (ORDER BY oracle_to_risingwave_ms) as median_latency,
max(oracle_to_risingwave_ms) as maximum_latency, count(*) as number_of_rows_tested
from cdc_stmt_entry_final

SELECT count(*) AS measured,
       count(DISTINCT entry_id) AS distinct_rows,
       count(*) FILTER (WHERE oracle_to_risingwave_ms < 0) AS negatives,
       min(oracle_to_risingwave_ms) AS min_ms,
       percentile_cont(0.50) WITHIN GROUP (ORDER BY oracle_to_risingwave_ms) AS p50_ms,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY oracle_to_risingwave_ms) AS p95_ms,
       percentile_cont(0.99) WITHIN GROUP (ORDER BY oracle_to_risingwave_ms) AS p99_ms,
       max(oracle_to_risingwave_ms) AS max_ms
FROM cdc_stmt_entry_latency_full
WHERE op = 'c' AND src_ts_us > 1700000000000000;

SELECT date_trunc('minute', rw_echo_ts) AS minute, count(*) AS rows,
       round(avg(oracle_to_risingwave_ms)) AS avg_ms, max(oracle_to_risingwave_ms) AS max_ms
FROM cdc_stmt_entry_latency_full GROUP BY 1 ORDER BY 1;




