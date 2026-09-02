WHENEVER SQLERROR EXIT SQL.SQLCODE;

PROMPT === [Oracle Init] Configure LOB Supplemental Logging for CDC ===

-- Must run as SYSDBA or system
ALTER SESSION SET CONTAINER = XEPDB1;

-- Enable supplemental logging at column level for LOB columns
-- This is CRITICAL for Debezium to capture LOB data in redo logs

ALTER TABLE APPUSER.CDC_TEST ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Specifically log the LOB columns
ALTER TABLE APPUSER.CDC_TEST MODIFY (DESCRIPTION LOB (CACHE LOGGING));
ALTER TABLE APPUSER.CDC_TEST MODIFY (PAYLOAD_XML LOB (CACHE LOGGING));
ALTER TABLE APPUSER.CDC_TEST MODIFY (BINARY_DATA LOB (CACHE LOGGING));

-- Verify supplemental logging is enabled
DECLARE
    v_tab_name VARCHAR2(30) := 'CDC_TEST';
    v_owner    VARCHAR2(30) := 'APPUSER';
BEGIN
    FOR r IN (
        SELECT table_name, supplemental_log_grp_type 
        FROM all_log_groups 
        WHERE table_owner = v_owner 
        AND table_name = v_tab_name
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('Table: ' || r.table_name || ' - Log Group Type: ' || r.supplemental_log_grp_type);
    END LOOP;
END;
/

PROMPT === [Oracle Init] LOB supplemental logging configured ===

EXIT;
