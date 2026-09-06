CREATE MATERIALIZED VIEW cdc_main_table_final AS
WITH latest_audit AS (
    SELECT
        (after ->> 'RECID')::INT AS recid,
        after ->> 'XMLRECORD' AS xmlrecord,
        op,

        -- Final end-to-end latency:
        -- RisingWave processing time - Oracle commit time
        (
            (EXTRACT(EPOCH FROM event_ts) * 1000)::BIGINT
            - (source ->> 'commit_ts_ms')::BIGINT
        ) AS latency_ms,

        ROW_NUMBER() OVER (
            PARTITION BY (after ->> 'RECID')::INT
            ORDER BY event_ts DESC
        ) AS rn

    FROM cdc_main_table_audit
    WHERE after IS NOT NULL
)

SELECT
    s.recid,

    (regexp_match(
        s.xmlrecord,
        '<id>([^<]+)</id>'
    ))[1]::INT AS id,

    (regexp_match(
        s.xmlrecord,
        '<acount_id>([^<]+)</acount_id>'
    ))[1]::INT AS acount_id,

    (regexp_match(
        s.xmlrecord,
        '<name>([^<]+)</name>'
    ))[1] AS name,

    (regexp_match(
        s.xmlrecord,
        '<balance>([^<]+)</balance>'
    ))[1]::DECIMAL AS balance,

    'oracle' AS source_name,

    a.op,
    a.latency_ms

FROM oracle_cdc_main_table s
LEFT JOIN latest_audit a
    ON s.recid = a.recid
   AND a.rn = 1;