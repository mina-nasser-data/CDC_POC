Write-Host "Starting kafka..." -ForegroundColor Cyan
docker compose --env-file .env -f .\docker\compose\docker-compose.yml up -d oracle kafka kafdrop

Write-Host "force recreate connect" -ForegroundColor Cyan

docker compose --env-file .env -f .\docker\compose\docker-compose.yml up -d --no-deps --force-recreate connect

Write-Host "Waiting for kafka container status..." -ForegroundColor Cyan
docker ps --filter "name=oracle" --filter "name=kafka" --filter "name=kafdrop"