#!/usr/bin/env bash
set -e

echo "Starting RisingWave bootstrap script..."

mkdir -p /risingwave/config

cat > /risingwave/config/risingwave.toml <<'EOF'
[server]
heartbeat_interval_ms = 1000

[meta]
min_sst_retention_time_sec = 0
full_gc_interval_sec = 3600
EOF

echo "Launching RisingWave standalone with embedded local storage..."

exec /risingwave/bin/risingwave standalone \
  --config-path /risingwave/config/risingwave.toml \
  --frontend-opts="--listen-addr 0.0.0.0:4566 --health-check-listener-addr 0.0.0.0:6786" \
  --meta-opts="--listen-addr 0.0.0.0:5690" \
  --compute-opts="--listen-addr 0.0.0.0:5688" \
  --compactor-opts="--listen-addr 0.0.0.0:6660"