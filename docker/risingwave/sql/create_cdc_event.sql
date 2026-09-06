CREATE TABLE cdc_main_table_audit (
    op          VARCHAR,
    "before"    JSONB,
    "after"     JSONB,
    source      JSONB,
    ts_ms       BIGINT,                     -- Debezium event timestamp
    event_ts    TIMESTAMPTZ AS PROCTIME()  -- RisingWave processing time
) WITH (
    connector = 'kafka',
    topic = 'oracle21.APPUSER.CDC_MAIN_TABLE',
    properties.bootstrap.server = 'kafka:9092',
    scan.startup.mode = 'latest'
)
FORMAT PLAIN ENCODE JSON;