Write-Host "Starting minio and Risingwave container..." -ForegroundColor Cyan
docker compose --env-file .\.env -f .\docker\compose\docker-compose.yml up -d minio risingwave

Write-Host "Waiting for RisingWave container status..." -ForegroundColor Cyan
docker ps --filter "name=risingwave"