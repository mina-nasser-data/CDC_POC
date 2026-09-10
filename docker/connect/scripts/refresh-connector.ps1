$body = Get-Content -Raw .\docker\connect\connectors\oracle-source-config-only.json

Invoke-RestMethod `
  -Method Put `
  -Uri http://localhost:8083/connectors/oracle-cdc-connector/config `
  -ContentType "application/json" `
  -Body $body