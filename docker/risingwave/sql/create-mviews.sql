CREATE MATERIALIZED VIEW IF NOT EXISTS mv_oracle_cdc_test AS
SELECT
    id,
    name,
    description,
    payload_xml,
    binary_data
FROM oracle_cdc_test;