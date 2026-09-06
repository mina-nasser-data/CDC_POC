WHENEVER SQLERROR EXIT SQL.SQLCODE;

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = APPUSER;

CREATE TABLE CDC_MAIN_TABLE (
    recid NUMBER(10) PRIMARY KEY,
    xmlrecord XMLTYPE
);

INSERT INTO CDC_MAIN_TABLE (recid, xmlrecord)
VALUES (
    1,
    XMLTYPE('<root><id>1</id><acount_id>1</acount_id><name>user name</name><balance>1000.00</balance></root>')
);

COMMIT;
