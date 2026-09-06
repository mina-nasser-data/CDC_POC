-- Debezium CDC from Kafka into RisingWave
-- Use CREATE TABLE, not CREATE SOURCE, for Debezium CDC semantics.

CREATE TABLE IF NOT EXISTS oracle_cdc_main_table (
    recid INT PRIMARY KEY,
    xmlrecord VARCHAR
)
WITH (
    connector = 'kafka',
    topic = 'oracle21.APPUSER.CDC_MAIN_TABLE',
    properties.bootstrap.server = 'kafka:9092',
    scan.startup.mode = 'latest'
)
FORMAT DEBEZIUM ENCODE JSON;