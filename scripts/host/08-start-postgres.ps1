Write-Host "Starting postgres..." -ForegroundColor Cyan
docker compose --env-file .env -f .\docker\compose\docker-compose.yml up -d postgres

Write-Host "Waiting for postgres container status..." -ForegroundColor Cyan
docker ps --filter "name=postgres"