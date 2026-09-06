# Quick INSERT test for CDC

$oracleUser = "appuser"
$oraclePassword = "AppUserPass123"
$oracleDb = "xepdb1"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Quick CDC INSERT Test" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Create temp SQL file
$sqlFile = "$env:TEMP\insert-test.sql"

$sqlContent = @"
INSERT INTO CDC_MAIN_TABLE (recid,xmlrecord)
VALUES (
    8,
    XMLTYPE('<root><id>8</id><acount_id>8</acount_id><name>user name 8</name><balance>7856.666</balance></root>')
);
COMMIT;
SELECT * FROM CDC_MAIN_TABLE WHERE recid = 8;
EXIT;
"@

try {
    Write-Host "[1/3] Creating SQL file..." -ForegroundColor Cyan
    $sqlContent | Out-File -FilePath $sqlFile -Encoding ASCII -Force
    
    Write-Host "[2/3] Executing INSERT..." -ForegroundColor Cyan
    Get-Content $sqlFile | docker exec -i oracle sqlplus -S "$oracleUser/$oraclePassword@$oracleDb" 2>&1
    
    Write-Host ""
    Write-Host "SUCCESS: INSERT completed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Waiting 3 seconds before reading CDC payload..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    Write-Host ""
    Write-Host "[3/3] Reading CDC payload (INSERT with after)..." -ForegroundColor Cyan
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
