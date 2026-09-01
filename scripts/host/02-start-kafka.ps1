Write-Host "Starting kafka..." -ForegroundColor Cyan
docker compose --env-file .env -f .\docker\compose\docker-compose.yml up -d oracle kafka kafdrop

Write-Host "Waiting for kafka container status..." -ForegroundColor Cyan
docker ps --filter "name=oracle" --filter "name=kafka" --filter "name=kafdrop"