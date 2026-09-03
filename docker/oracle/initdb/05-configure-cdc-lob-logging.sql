WHENEVER SQLERROR EXIT SQL.SQLCODE;

PROMPT === [Oracle Init] Configure table supplemental logging ===

ALTER SESSION SET CONTAINER = XEPDB1;

ALTER TABLE APPUSER.CDC_TEST ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

PROMPT === [Oracle Init] Table supplemental logging configured ===

EXIT;