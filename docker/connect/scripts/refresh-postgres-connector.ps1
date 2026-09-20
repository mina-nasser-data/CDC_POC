$body = Get-Content -Raw .\docker\connect\connectors\postgres-source-config.json

Invoke-RestMethod `
  -Method Put `
  -Uri http://localhost:8083/connectors/postgres-cdc-connector/config `
  -ContentType "application/json" `
  -Body $body