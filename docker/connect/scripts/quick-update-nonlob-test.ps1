# Quick UPDATE test for CDC

$oracleUser = "appuser"
$oraclePassword = "AppUserPass123"
$oracleDb = "xepdb1"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Quick CDC UPDATE Test" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Create temp SQL file
$sqlFile = "$env:TEMP\update-test.sql"

$sqlContent = @"
UPDATE STMT_ENTRY 
SET AMOUNT = -1250.00, 
    TXN_CODE = 'IPNX'
WHERE ENTRY_ID = 'TXN-2026-003';
COMMIT; 
EXIT;
"@

try {
    Write-Host "[1/3] Creating SQL file..." -ForegroundColor Cyan
    $sqlContent | Out-File -FilePath $sqlFile -Encoding ASCII -Force
    
    Write-Host "[2/3] Executing UPDATE..." -ForegroundColor Cyan
    Get-Content $sqlFile | docker exec -i oracle sqlplus -S "$oracleUser/$oraclePassword@$oracleDb" 2>&1
    
    Write-Host ""
    Write-Host "SUCCESS: UPDATE completed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Waiting 3 seconds before reading CDC payload..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    Write-Host ""
    Write-Host "[3/3] Reading CDC payload (with before/after)..." -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor DarkGray
    Write-Host ""
    
    & ".\docker\connect\scripts\verify-cdc-payload.ps1"
    
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
} finally {
    if (Test-Path $sqlFile) {
        Remove-Item $sqlFile -Force -ErrorAction SilentlyContinue
    }
}
