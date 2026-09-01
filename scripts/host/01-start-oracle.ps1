Write-Host "Starting Oracle XE only..." -ForegroundColor Cyan
docker compose --env-file .env -f .\docker\compose\docker-compose.yml up -d oracle

Write-Host "Waiting for Oracle container status..." -ForegroundColor Cyan
docker ps --filter "name=oracle"