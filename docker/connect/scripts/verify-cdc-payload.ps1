# Check CDC payload from Kafka topic - Windows/PowerShell version
# Robust error handling and message parsing

$TOPIC = "oracle21.APPUSER.CDC_TEST"
$KAFKA_CONTAINER = "kafka"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Checking CDC Payload from Kafka" -ForegroundColor Cyan
Write-Host "Topic: $TOPIC" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
try {
    $dockerStatus = docker ps -q 2>$null
    if (-not $dockerStatus) {
        Write-Host "ERROR: Docker is not running or no containers are active" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERROR: Docker command failed" -ForegroundColor Red
    exit 1
}

# Check if Kafka container exists and is running
$kafkaRunning = docker ps --filter "name=$KAFKA_CONTAINER" -q 2>$null
if (-not $kafkaRunning) {
    Write-Host "ERROR: Kafka container '$KAFKA_CONTAINER' is not running" -ForegroundColor Red
    exit 1
}

Write-Host "Reading messages from Kafka topic..." -ForegroundColor Yellow

try {
    # Execute kafka-console-consumer with proper flags
    $rawOutput = docker exec $KAFKA_CONTAINER bash -c `
        "kafka-console-consumer --bootstrap-server localhost:9092 --topic $TOPIC --from-beginning --max-messages 10 --timeout-ms 5000" `
        2>&1 | Out-String
    
    if ([string]::IsNullOrWhiteSpace($rawOutput)) {
        Write-Host ""
        Write-Host "WARNING: No messages found in topic" -ForegroundColor Yellow
        Write-Host "Possible reasons:" -ForegroundColor Yellow
        Write-Host "  1. CDC connector not started yet" -ForegroundColor Gray
        Write-Host "  2. No changes have been made to the table" -ForegroundColor Gray
        Write-Host "  3. Topic does not exist yet" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "Messages received:" -ForegroundColor Green
        Write-Host ""
        
        # Split messages by finding JSON boundaries
        $lines = $rawOutput -split "`n" | Where-Object { $_.Trim() -ne "" }
        $messages = @()
        $currentMsg = ""
        
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            
            if ($trimmedLine -match '^\{') {
                if ($currentMsg -ne "") {
                    $messages += $currentMsg
                }
                $currentMsg = $trimmedLine
            } elseif ($trimmedLine -match '^\}' -and $currentMsg -ne "") {
                $currentMsg += $trimmedLine
                $messages += $currentMsg
                $currentMsg = ""
            } else {
                if ($currentMsg -ne "") {
                    $currentMsg += "`n$trimmedLine"
                }
            }
        }
        
        # Add last message if any
        if ($currentMsg -ne "") {
            $messages += $currentMsg
        }
        
        # Display messages
        $messageCount = 0
        foreach ($msg in $messages) {
            if ([string]::IsNullOrWhiteSpace($msg)) { continue }
            
            $messageCount++
            Write-Host "--- Message $messageCount ---" -ForegroundColor Yellow
            
            try {
                $json = $msg | ConvertFrom-Json -ErrorAction Stop
                
                # Extract key fields if available
                if ($json.payload) {
                    Write-Host "Operation: $($json.payload.op)" -ForegroundColor Cyan
                    Write-Host "Table: $($json.payload.source.table)" -ForegroundColor Cyan
                    Write-Host "Schema: $($json.payload.source.schema)" -ForegroundColor Cyan
                    
                    if ($json.payload.before) {
                        Write-Host "BEFORE:" -ForegroundColor Yellow
                        $json.payload.before | ConvertTo-Json | Write-Host
                    }
                    
                    if ($json.payload.after) {
                        Write-Host "AFTER:" -ForegroundColor Green
                        $json.payload.after | ConvertTo-Json | Write-Host
                    }
                    
                    Write-Host "Source Timestamp: $($json.payload.source.ts_ms)" -ForegroundColor Cyan
                }
            } catch {
                # If JSON parsing fails, display as raw text
                Write-Host $msg -ForegroundColor Gray
            }
            
            Write-Host ""
        }
        
        if ($messageCount -eq 0) {
            Write-Host "No valid JSON messages found" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "ERROR: Failed to read from Kafka" -ForegroundColor Red
    Write-Host "Error details: $_" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Payload verification completed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
