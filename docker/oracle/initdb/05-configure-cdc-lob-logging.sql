WHENEVER SQLERROR EXIT SQL.SQLCODE;

PROMPT === [Oracle Init] Configure table supplemental logging ===

ALTER SESSION SET CONTAINER = XEPDB1;

ALTER TABLE APPUSER.cdc_main_table ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

PROMPT === [Oracle Init] Table supplemental logging configured ===

