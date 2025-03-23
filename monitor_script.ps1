# Script to monitor and automatically restart mcp_md_done.ps1 if it exits
$scriptPath = "your path to\LMStudio-Markdown-Content-Generator\mcp_md_done.ps1"
$maxRetries = 100000 # Maximum number of restart attempts
$retryCount = 0
$waitTime = 5  # Seconds to wait between restart attempts

Write-Host "Starting monitoring for $scriptPath" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow

while ($retryCount -lt $maxRetries) {
    try {
        Write-Host "Attempt $($retryCount + 1) of $($maxRetries): Starting script..." -ForegroundColor Cyan
        # 使用 pwsh 命令来启动 PowerShell 7
        $process = Start-Process pwsh -ArgumentList "-File `"$scriptPath`"" -PassThru -NoNewWindow
        
        # Wait for the process to exit
        $process.WaitForExit()
        
        $exitCode = $process.ExitCode
        Write-Host "Script exited with code: $exitCode" -ForegroundColor Yellow
        
        # Increment retry counter
        $retryCount++
        
        # Wait before restarting
        Write-Host "Waiting $waitTime seconds before restarting..." -ForegroundColor Gray
        Start-Sleep -Seconds $waitTime
    }
    catch {
        Write-Host "Error monitoring script: $_" -ForegroundColor Red
        $retryCount++
        Start-Sleep -Seconds $waitTime
    }
}

Write-Host "Maximum retry attempts ($maxRetries) reached. Monitoring stopped." -ForegroundColor Red
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")