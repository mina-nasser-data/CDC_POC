--##############################################################################################################################
--CREATING Table STMT_ENTRY
--##############################################################################################################################

CREATE TABLE stmt_entry (
    entry_id        VARCHAR(20) PRIMARY KEY,
    account_number  VARCHAR(15) NOT NULL,
    booking_date    DATE NOT NULL,
    txn_code        VARCHAR(4),
    amount          NUMERIC(15,2),
    currency        VARCHAR(3),
    txn_metadata    SYS.XMLTYPE,       
    audit_trail     CLOB,       
    digital_receipt BLOB ,      
	txn_metadata_binary   BLOB --Binary of txn_metadata
	src_ts_us NUMBER(18)
    );



SELECT count(*) FROM stmt_entry
WHERE ENTRY_ID LIKE 'TXN_2026%'

DELETE FROM stmt_entry
WHERE ENTRY_ID LIKE 'TXN_2027%'

INSERT INTO stmt_entry 
values('TXN_2026-1',200000000000000, TRUNC(SYSDATE),'LOL',500,'EGP','<account><test>1</test></account>','small text',UTL_RAW.CAST_TO_RAW('small text'),UTL_RAW.CAST_TO_RAW('<account><test>1</test></account>'),1515151515)
--##############################################################################################################################
--Inserting 500K row 
--##############################################################################################################################
DROP SEQUENCE bench_entry_seq

CREATE SEQUENCE bench_entry_seq START WITH 1 INCREMENT BY 1 CACHE 50;

DECLARE
  c_total CONSTANT PLS_INTEGER := 2000;
  v_seq    PLS_INTEGER;
  v_xml    VARCHAR2(4000);
  v_ts     TIMESTAMP;
  v_d      INTERVAL DAY(9) TO SECOND(6);
  v_pre    NUMBER;
  v_post   NUMBER;
  v_n      PLS_INTEGER := 0;
  v_sum_us NUMBER := 0;
  v_max_us NUMBER := 0;
  v_t0     TIMESTAMP WITH TIME ZONE := SYSTIMESTAMP;
  v_secs   NUMBER;
BEGIN
  LOOP
    v_seq := bench_entry_seq.NEXTVAL;
    EXIT WHEN v_seq > c_total;

    v_xml := '<transaction>' ||
               '<vendor>VENDOR_' || MOD(v_seq, 100) || '</vendor>' ||
               '<channel>CHANNEL_' || MOD(v_seq, 5) || '</channel>' ||
               '<terminal_id>TXN_' || MOD(v_seq, 20) || '</terminal_id>' ||
             '</transaction>';

    -- Oracle wall clock as UTC epoch microseconds, taken just before the INSERT
    v_ts  := SYS_EXTRACT_UTC(SYSTIMESTAMP);
    v_d   := v_ts - TIMESTAMP '1970-01-01 00:00:00';
    v_pre := ROUND((EXTRACT(DAY FROM v_d) * 86400 + EXTRACT(HOUR FROM v_d) * 3600
                  + EXTRACT(MINUTE FROM v_d) * 60 + EXTRACT(SECOND FROM v_d)) * 1000000);

    INSERT INTO stmt_entry (
      entry_id, account_number, booking_date, txn_code, amount, currency,
      txn_metadata, audit_trail, digital_receipt, txn_metadata_binary, src_ts_us
    ) VALUES (
      'TXN-2027-' || LPAD(v_seq, 6, '0'),
      LPAD(TO_CHAR(200000000000000 + v_seq), 15, '0'),
      DATE '2025-01-01' + MOD(v_seq, 365),
      CASE MOD(v_seq, 4) WHEN 0 THEN 'PAY' WHEN 1 THEN 'TRF' WHEN 2 THEN 'WD' ELSE 'DEP' END,
      150000000,
      CASE MOD(v_seq, 3) WHEN 0 THEN 'EGP' WHEN 1 THEN 'USD' ELSE 'EUR' END,
      XMLTYPE(v_xml),
      'LOB AUDIT RECORD ' || v_seq,
      UTL_RAW.CAST_TO_RAW('DIGITAL_RECEIPT_' || LPAD(v_seq, 6, '0')),
      UTL_RAW.CAST_TO_RAW(v_xml),
      v_pre
    );

    COMMIT WRITE IMMEDIATE WAIT;

    -- time after the commit returned: post - pre = how far src_ts_us is before the true commit
    v_ts   := SYS_EXTRACT_UTC(SYSTIMESTAMP);
    v_d    := v_ts - TIMESTAMP '1970-01-01 00:00:00';
    v_post := ROUND((EXTRACT(DAY FROM v_d) * 86400 + EXTRACT(HOUR FROM v_d) * 3600
                   + EXTRACT(MINUTE FROM v_d) * 60 + EXTRACT(SECOND FROM v_d)) * 1000000);

    v_n      := v_n + 1;
    v_sum_us := v_sum_us + (v_post - v_pre);
    IF v_post - v_pre > v_max_us THEN v_max_us := v_post - v_pre; END IF;

    IF MOD(v_n, 1000) = 0 THEN
      DBMS_APPLICATION_INFO.SET_CLIENT_INFO('rows=' || v_n || ' seq=' || v_seq);
    END IF;
  END LOOP;

  v_d    := SYSTIMESTAMP - v_t0;
  v_secs := EXTRACT(DAY FROM v_d) * 86400 + EXTRACT(HOUR FROM v_d) * 3600
          + EXTRACT(MINUTE FROM v_d) * 60 + EXTRACT(SECOND FROM v_d);
  DBMS_OUTPUT.PUT_LINE('session rows=' || v_n || ' seconds=' || ROUND(v_secs, 1)
    || ' rows_per_sec=' || ROUND(v_n / NULLIF(v_secs, 0), 1)
    || ' insert_commit_ms avg=' || ROUND(v_sum_us / NULLIF(v_n, 0) / 1000, 2)
    || ' max=' || ROUND(v_max_us / 1000, 2));
END;



