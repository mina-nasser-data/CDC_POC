WHENEVER SQLERROR EXIT SQL.SQLCODE;

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = APPUSER;



CREATE TABLE STMT_ENTRY (
    ENTRY_ID        VARCHAR2(20) PRIMARY KEY,
    ACCOUNT_NUMBER  VARCHAR2(15) NOT NULL,
    BOOKING_DATE    DATE NOT NULL,
    TXN_CODE        VARCHAR2(4),
    AMOUNT          NUMBER(15,2),
    CURRENCY        VARCHAR2(3),
    TXN_METADATA    SYS.XMLTYPE,          -- For Phase B5 / B6 testing
    AUDIT_TRAIL     CLOB,                 -- For Phase B4 testing
    DIGITAL_RECEIPT BLOB,                  -- For Phase B4 testing
    txn_metadata_binary   BLOB --Binary of txn_metadata
);

