#!/bin/bash
set -e

echo "SELECT 1 FROM DUAL;" | sqlplus -s system/${ORACLE_PASSWORD}@//localhost:1521/${ORACLE_DATABASE:-XEPDB1} | grep -q "1"