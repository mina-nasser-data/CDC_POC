#!/bin/bash
set -e

echo "=== [Oracle Init] Enabling ARCHIVELOG mode ==="

log_mode=$(sqlplus -s / as sysdba <<'EOF'
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT LOG_MODE FROM V$DATABASE;
EXIT;
EOF
)

if echo "$log_mode" | grep -q "ARCHIVELOG"; then
	echo "=== [Oracle Init] ARCHIVELOG mode already enabled ==="
	exit 0
fi

sqlplus -s / as sysdba <<'EOF'
WHENEVER SQLERROR EXIT SQL.SQLCODE

SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

ARCHIVE LOG LIST;

EXIT;
EOF

echo "=== [Oracle Init] ARCHIVELOG step complete ==="

# Why
# Debezium Oracle LogMiner requires redo/archive logging to mine changes. 
# Debezium's Oracle documentation includes preparing the database with archive logging and supplemental logging for LogMiner-based capture.