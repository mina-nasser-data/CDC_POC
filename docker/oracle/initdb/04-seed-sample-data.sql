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

CREATE TABLE STMT_ENTRY (
    ENTRY_ID        VARCHAR2(20) PRIMARY KEY,
    ACCOUNT_NUMBER  VARCHAR2(15) NOT NULL,
    BOOKING_DATE    DATE NOT NULL,
    TXN_CODE        VARCHAR2(4),
    AMOUNT          NUMBER(15,2),
    CURRENCY        VARCHAR2(3),
    TXN_METADATA    SYS.XMLTYPE,          -- For Phase B5 / B6 testing
    AUDIT_TRAIL     CLOB,                 -- For Phase B4 testing
    DIGITAL_RECEIPT BLOB                  -- For Phase B4 testing
);

-- Row 1: Retail Debit Card POS Purchase (Fawry / Grocery)
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-001', '1000293847', TO_DATE('2026-09-01', 'YYYY-MM-DD'), 'POS', -450.50, 'EGP',
    XMLTYPE('<t24_meta><vendor>FAWRY_SUPERMARKET</vendor><channel>POS</channel><terminal_id>FWRY0912</terminal_id></t24_meta>'),
    'LOG: 2026-09-01T10:15:30Z - Authorization approved via Meeza Network. Terminal ID: FWRY0912. Settled via local processing node.',
    UTL_RAW.CAST_TO_RAW('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==')
);

-- Row 2: Inbound Salary Credit via ACH Corporate Payroll
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-002', '1000293847', TO_DATE('2026-09-01', 'YYYY-MM-DD'), 'SAL', 45000.00, 'EGP',
    XMLTYPE('<t24_meta><source>VODAFONE_EGYPT</source><taxable>true</taxable><eta_company_id>EG-123456</eta_company_id></t24_meta>'),
    'LOG: 2026-09-01T08:00:00Z - Inbound ACH transfer from Central Bank of Egypt clearing house. Originating routing: CBE010002. Verification hash matched.',
    UTL_RAW.CAST_TO_RAW('255044462d312e340a25e2e3cfd30a312030206f626a0a3c3c2f4c656e6774682035203020522f46696c7465722f466c6174654465636f64653e3e')
);

-- Row 3: Outbound Transfer via InstaPay (IPN Instant Network)
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-003', '1000293847', TO_DATE('2026-09-02', 'YYYY-MM-DD'), 'IPN', -1200.00, 'EGP',
    XMLTYPE('<t24_meta><receiver_ipa>ahmed@instapay</receiver_ipa><network>IPN_CBE</network><purpose>PeerToPeer</purpose></t24_meta>'),
    'LOG: 2026-09-02T18:22:11Z - Outbound instant payment initiated via mobile app API. RRN: 609211982711. Direct settlement cycle success.',
    UTL_RAW.CAST_TO_RAW('494e5354415041595f54584e5f535543434553535f52454345495054')
);

-- Row 4: ATM Cash Withdrawal (Banque Misr ATM)
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-004', '1000293847', TO_DATE('2026-09-03', 'YYYY-MM-DD'), 'ATM', -2000.00, 'EGP',
    XMLTYPE('<t24_meta><atm_location>CAIRO_FESTIVAL_CITY</atm_location><bank_owner>BMISR</bank_owner><fee>5.00</fee></t24_meta>'),
    'LOG: 2026-09-03T14:05:00Z - Off-us ATM withdrawal request accepted. 123-Switch network routing. ATM_ID: CFC-MSR-04. Cash dispensed successfully.',
    NULL
);

-- Row 5: Utility Bill Payment via Mobile Banking (Telecom Egypt / WE)
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-005', '1000293847', TO_DATE('2026-09-04', 'YYYY-MM-DD'), 'BILL', -650.00, 'EGP',
    XMLTYPE('<t24_meta><biller>TELECOM_EGYPT</biller><consumer_no>0225114321</consumer_no><type>INTERNET</type></t24_meta>'),
    'LOG: 2026-09-04T21:40:15Z - Bill payment transaction routed via Madfouat Egypt utility portal. Reference: TE-99812A. Approved by core ledger.',
    UTL_RAW.CAST_TO_RAW('255044462d57455f494e5445524e45545f42494c4c5f53455054454d424552')
);

-- Row 6: Online E-Commerce Purchase (Amazon Egypt)
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-006', '1000293847', TO_DATE('2026-09-05', 'YYYY-MM-DD'), 'ECOM', -1580.00, 'EGP',
    XMLTYPE('<t24_meta><merchant>AMAZON_EG</merchant><gateway>PAYME</gateway><secure_3d>Y</secure_3d></t24_meta>'),
    'LOG: 2026-09-05T11:12:04Z - 3D Secure OTP authentication verified by customer mobile +2010******. Transaction processed via PayTabs/Amazon billing node.',
    UTL_RAW.CAST_TO_RAW('414d415a4f4e5f45475f4f524445525f3430335f393831323734')
);

-- Row 7: Monthly Credit Card Auto-Debit Settlement
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-007', '1000293847', TO_DATE('2026-09-05', 'YYYY-MM-DD'), 'CCST', -5000.00, 'EGP',
    XMLTYPE('<t24_meta><target_card>4000123456789012</target_card><type>INTERNAL_SWEEP</type></t24_meta>'),
    'LOG: 2026-09-05T23:59:59Z - Automated standing order executed. Internal sweep from current account to visa credit card settlement account.',
    NULL
);

-- Row 8: Inbound InstaPay Wallet Top-up (From Vodafone Cash)
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-008', '1000293847', TO_DATE('2026-09-06', 'YYYY-MM-DD'), 'WLET', 3000.00, 'EGP',
    XMLTYPE('<t24_meta><wallet_provider>VODAFONE_CASH</wallet_provider><sender_mobile>201011112233</sender_mobile></t24_meta>'),
    'LOG: 2026-09-06T13:10:22Z - Inbound wallet switch message received via Meeza Digital rails. Transferred into primary core savings line.',
    UTL_RAW.CAST_TO_RAW('57414c4c45545f544f5055505f524543454950545f4d45455a41')
);

-- Row 9: Quarter Banking Service Fees & Maintenance Charges
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-009', '1000293847', TO_DATE('2026-09-07', 'YYYY-MM-DD'), 'CHRG', -75.00, 'EGP',
    XMLTYPE('<t24_meta><fee_code>MNT01</fee_code><description>Quarterly Account Fee</description></t24_meta>'),
    'LOG: 2026-09-07T01:00:00Z - System-generated batch charge execution. Account ledger maintenance tariff applied according to CBE retail banking book.',
    NULL
);

-- Row 10: Inbound Foreign Remittance Converted to Local Account (USD to EGP)
INSERT INTO STMT_ENTRY (ENTRY_ID, ACCOUNT_NUMBER, BOOKING_DATE, TXN_CODE, AMOUNT, CURRENCY, TXN_METADATA, AUDIT_TRAIL, DIGITAL_RECEIPT)
VALUES (
    'TXN-2026-010', '1000293847', TO_DATE('2026-09-08', 'YYYY-MM-DD'), 'REMT', 24250.00, 'EGP',
    XMLTYPE('<t24_meta><orig_currency>USD</orig_currency><orig_amount>500.00</orig_amount><fx_rate>48.50</fx_rate></t24_meta>'),
    'LOG: 2026-09-08T09:30:45Z - Inbound SWIFT wire transfer cleared. Sender: RemitCorp Intl. FX booking executed at central treasury desk spot rate 48.50.',
    UTL_RAW.CAST_TO_RAW('255044462d53574946545f4d543130335f52454d495454414e4345')
);


COMMIT;