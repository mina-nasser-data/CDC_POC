$body = Get-Content -Raw .\docker\connect\connectors\postgres-source.json

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:8083/connectors `
  -ContentType "application/json" `
  -Body $body