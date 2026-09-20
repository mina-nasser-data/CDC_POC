# Creates the Kafka topic that the RisingWave latency echo sinks into.
#
# Why this is needed even though KAFKA_AUTO_CREATE_TOPICS_ENABLE is "true"
# (docker-compose.yml): auto-creation fires when a producer actually writes or a
# consumer subscribes. RisingWave's CREATE TABLE only performs a metadata fetch,
# which does not trigger it. Before any row has flowed, the sink has produced
# nothing, so the topic does not exist and this fails:
#
#   CREATE TABLE cdc_rw_echo ... -> "failed to fetch metadata from kafka
#                                    (kafka:9092): topic cdc_rw_echo not found"
#
# Run this once before applying docker/risingwave/sql/create-latency-pipeline.sql.

Write-Host "Creating cdc_rw_echo topic..." -ForegroundColor Cyan
docker exec kafka kafka-topics --bootstrap-server kafka:9092 `
    --create --if-not-exists --topic cdc_rw_echo `
    --partitions 1 --replication-factor 1

Write-Host ""
Write-Host "Current topics:" -ForegroundColor Cyan
docker exec kafka kafka-topics --bootstrap-server kafka:9092 --list
