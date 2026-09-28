# Starts Minikube and port-forwards every CDC_SCB Service to localhost.
#
# Does not apply/create any Kubernetes resources and does not touch pods directly -
# it only starts the cluster, waits for existing pods to be Ready, and forwards
# ports for host/DBeaver access. Any pipeline fixes belong in the k8s manifests
# themselves (e.g. k8s/oracle/statefulset.yaml), not here.
#
# Uses detached kubectl.exe processes (Start-Process), not PowerShell jobs -
# jobs die the moment the terminal that started them closes.

$Namespace = "cdc-scb"

Write-Host "Starting Minikube..." -ForegroundColor Cyan
minikube start --driver=docker --cpus=4

Write-Host "Stopping any previous port-forwards..." -ForegroundColor Cyan
Get-Process kubectl -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "Waiting for pods to be Ready before port-forwarding..." -ForegroundColor Cyan
kubectl -n $Namespace wait --for=condition=Ready pod --all --field-selector=status.phase!=Succeeded --timeout=300s

# Right after Minikube resumes, pods can still be mid-restart even once kubectl wait
# says Ready - a port-forward started at that exact moment connects, then the pod
# cycles again and it dies silently (hidden window, no visible error). So after
# starting each one, we check the port actually answers and retry once if not.
$Forwards = @(
    @{ Name = "oracle";     Port = 1521; Args = @("svc/oracle", "1521:1521") },
    @{ Name = "kafka";      Port = 9092; Args = @("svc/kafka", "9092:9092") },
    @{ Name = "connect";    Port = 8083; Args = @("svc/connect", "8083:8083") },
    @{ Name = "risingwave"; Port = 4566; Args = @("svc/risingwave", "4566:4566", "5691:5691") },
    @{ Name = "kafdrop";    Port = 9000; Args = @("svc/kafdrop", "9000:9000") },
    @{ Name = "superset";   Port = 8088; Args = @("svc/superset", "8088:8088") }
)

Write-Host "Starting port-forwards..." -ForegroundColor Cyan
foreach ($f in $Forwards) {
    Start-Process kubectl -ArgumentList (@("-n", $Namespace, "port-forward") + $f.Args) -WindowStyle Hidden
}

Write-Host "Verifying port-forwards came up (retrying any that died)..." -ForegroundColor Cyan
Start-Sleep -Seconds 4
foreach ($f in $Forwards) {
    $up = (Test-NetConnection -ComputerName localhost -Port $f.Port -WarningAction SilentlyContinue).TcpTestSucceeded
    if (-not $up) {
        Write-Host "  $($f.Name) port-forward died - retrying..." -ForegroundColor Yellow
        Start-Process kubectl -ArgumentList (@("-n", $Namespace, "port-forward") + $f.Args) -WindowStyle Hidden
        Start-Sleep -Seconds 4
        $up = (Test-NetConnection -ComputerName localhost -Port $f.Port -WarningAction SilentlyContinue).TcpTestSucceeded
        if ($up) { Write-Host "  $($f.Name) is up now." -ForegroundColor Green }
        else { Write-Host "  $($f.Name) still not reachable - check 'kubectl get pods -n $Namespace'." -ForegroundColor Red }
    }
}

Write-Host ""
Write-Host "=== Localhost access ===" -ForegroundColor Green
Write-Host "  Oracle       -> localhost:1521"
Write-Host "  Kafka        -> localhost:9092"
Write-Host "  Connect REST -> localhost:8083"
Write-Host "  RisingWave   -> localhost:4566 (SQL), localhost:5691 (dashboard)"
Write-Host "  Kafdrop      -> localhost:9000"
Write-Host "  Superset     -> localhost:8088"
Write-Host ""
Write-Host "Stop all forwards with: Get-Process kubectl | Stop-Process -Force" -ForegroundColor DarkGray
