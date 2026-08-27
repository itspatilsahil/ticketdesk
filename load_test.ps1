$url = "http://tkt-sp-alb-230255099.ap-south-1.elb.amazonaws.com/actuator/health"
$requests = 100

Write-Host "Simple Load Test - 100 requests"
Write-Host "URL: $url"
Write-Host ""

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$successCount = 0
$failCount = 0
$latencies = @()

for ($i = 1; $i -le $requests; $i++) {
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        $sw.Stop()

        $latencies += $sw.ElapsedMilliseconds
        $successCount++

        if ($i % 10 -eq 0) {
            Write-Host "Completed $i/$requests requests..."
        }
    } catch {
        $failCount++
    }
}

$stopwatch.Stop()

$avgLatency = if ($latencies.Count -gt 0) { [math]::Round(($latencies | Measure-Object -Average).Average, 2) } else { 0 }
$maxLatency = if ($latencies.Count -gt 0) { ($latencies | Measure-Object -Maximum).Maximum } else { 0 }
$minLatency = if ($latencies.Count -gt 0) { ($latencies | Measure-Object -Minimum).Minimum } else { 0 }
$rps = if ($stopwatch.ElapsedSeconds -gt 0) { [math]::Round($requests / $stopwatch.ElapsedSeconds, 2) } else { 0 }

Write-Host ""
Write-Host "========== RESULTS ==========" -ForegroundColor Green
Write-Host "Total Time: $([math]::Round($stopwatch.ElapsedSeconds, 2)) seconds"
Write-Host "Requests/sec: $rps"
Write-Host "Successful: $successCount / $requests"
Write-Host "Failed: $failCount"
Write-Host "Average Latency: $avgLatency ms"
Write-Host "Min Latency: $minLatency ms"
Write-Host "Max Latency: $maxLatency ms"
Write-Host "===========================" -ForegroundColor Green
