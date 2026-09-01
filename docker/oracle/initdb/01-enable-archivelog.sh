#!/bin/bash
set -e

echo "=== [Oracle Init] Enabling ARCHIVELOG mode ==="

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