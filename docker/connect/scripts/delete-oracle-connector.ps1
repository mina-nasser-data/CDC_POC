$connectorName = "oracle-cdc-connector"

try {
    Invoke-RestMethod `
      -Method Delete `
      -Uri "http://localhost:8083/connectors/$connectorName" `
      -ContentType "application/json"
    
    Write-Host "connector deleted: $connectorName" -ForegroundColor Green
    Start-Sleep -Seconds 2
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "connector not found: $connectorName" -ForegroundColor Yellow
    } else {
        Write-Host "error deleting connector: $_" -ForegroundColor Red
    }
}
