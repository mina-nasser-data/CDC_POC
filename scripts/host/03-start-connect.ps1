Write-Host "Starting connect container..." -ForegroundColor Cyan
docker compose --env-file .env -f .\docker\compose\docker-compose.yml up -d oracle kafka connect kafdrop

Write-Host "check connect status..." -ForegroundColor Cyan
docker ps --filter "name=connect"