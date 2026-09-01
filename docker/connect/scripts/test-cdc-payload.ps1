# Test CDC Payload from Debezium - INSERT and UPDATE operations

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Debezium CDC - INSERT and UPDATE" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Oracle connection details
$oracleUser = "appuser"
$oraclePassword = "AppUserPass123"
$oracleDb = "xepdb1"

# SQL script to execute
$sqlScript = @"
-- 1. INSERT new data
INSERT INTO CDC_TEST (id, name, email, created_at) 
VALUES (100, 'Test User 1', 'test1@example.com', SYSDATE);

COMMIT;

-- 2. UPDATE data (here before and after will be captured)
UPDATE CDC_TEST 
SET email = 'test1-updated@example.com', created_at = SYSDATE 
WHERE id = 100;

COMMIT;

-- 3. Display current data
SELECT * FROM CDC_TEST WHERE id = 100;
"@

Write-Host "Executing SQL operations on Oracle..." -ForegroundColor Yellow
Write-Host ""

$sqlFile = "$env:TEMP\test-cdc.sql"

try {
    Write-Host "[1/3] Preparing SQL script..." -ForegroundColor Cyan
    
    # Create SQL file with proper content
    $sqlFullScript = $sqlScript + "`nEXIT;`n"
    $sqlFullScript | Out-File -FilePath $sqlFile -Encoding UTF8 -Force
    
    if (-not (Test-Path $sqlFile)) {
        throw "Failed to create SQL file at $sqlFile"
    }
    
    Write-Host "[2/3] Executing INSERT and UPDATE operations..." -ForegroundColor Cyan
    
    # Check if Oracle container is running
    $oracleRunning = docker ps --filter "name=oracle" -q 2>$null
    if (-not $oracleRunning) {
        throw "Oracle container is not running"
    }
    
    # Execute via Docker using pipe
    $result = Get-Content $sqlFile | docker exec -i oracle sqlplus -S "$oracleUser/$oraclePassword@$oracleDb" 2>&1

    if ($result -like "*ORA-*" -or $result -like "*ERROR*") {
        Write-Host "WARNING: Oracle returned an error or warning:" -ForegroundColor Yellow
        Write-Host $result -ForegroundColor Yellow
    } else {
        Write-Host "Success: Operations completed" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Waiting 5 seconds for CDC to capture changes..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    Write-Host ""
    Write-Host "[3/3] Reading CDC payload from Kafka Topic..." -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor DarkGray
    Write-Host ""
    
    # Call the verification script
    & ".\docker\connect\scripts\verify-cdc-payload.ps1"
    
} catch {
    Write-Host "ERROR: $($_)" -ForegroundColor Red
    exit 1
} finally {
    if (Test-Path $sqlFile) {
        Remove-Item $sqlFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Expected fields in CDC Payload:" -ForegroundColor Cyan
Write-Host "  - before: Previous values (in UPDATE and DELETE)" -ForegroundColor Gray
Write-Host "  - after: New values (in INSERT and UPDATE)" -ForegroundColor Gray
Write-Host "  - source: Source info (SCN, timestamp, LSN)" -ForegroundColor Gray
Write-Host "  - ts_ms: Timestamp in milliseconds" -ForegroundColor Gray
Write-Host "  - op: Operation type (c=insert, u=update, d=delete)" -ForegroundColor Gray
