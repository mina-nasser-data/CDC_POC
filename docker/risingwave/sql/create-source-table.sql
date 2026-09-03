-- Debezium CDC from Kafka into RisingWave
-- Use CREATE TABLE, not CREATE SOURCE, for Debezium CDC semantics.

CREATE TABLE IF NOT EXISTS oracle_cdc_test (
    id INT PRIMARY KEY,
    name VARCHAR,
    description VARCHAR,
    payload_xml VARCHAR,
    binary_data VARCHAR
)
WITH (
    connector = 'kafka',
    topic = 'oracle21.APPUSER.CDC_TEST',
    properties.bootstrap.server = 'kafka:9092',
    scan.startup.mode = 'earliest'
)
FORMAT DEBEZIUM ENCODE JSON;