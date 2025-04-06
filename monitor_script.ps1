# Script to monitor and automatically restart mcp_md_done.ps1 if it exits
$scriptPath = "your path to\LMStudio-Markdown-Content-Generator\mcp_md_done.ps1"
$maxRetries = 100000 # Maximum number of restart attempts
$retryCount = 0
$waitTime = 5  # Seconds to wait between restart attempts
$logFile = "your path to\LMStudio-Markdown-Content-Generator\monitor_log.txt"

# Create or append to log file
function Write-Log {
    param (
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
    Write-Host "$timestamp - $Message"
}

Write-Log "Starting monitoring for $scriptPath"
Write-Log "Press Ctrl+C to stop monitoring"

# Check if .env file exists and load it
$envFile = "your path to\LMStudio-Markdown-Content-Generator\.env"
if (Test-Path $envFile) {
    Write-Log "Found .env configuration file"
    
    # Load environment variables from .env
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Remove quotes if present
            if ($value -match '^["''](.*)["'']$') {
                $value = $matches[1]
            }
            [Environment]::SetEnvironmentVariable($key, $value)
        }
    }
    
    # Verify LM Studio endpoint format
    $lmStudioEndpoint = $env:LMSTUDIO_ENDPOINT
    if ($lmStudioEndpoint -and -not $lmStudioEndpoint.EndsWith("/v1/chat/completions")) {
        Write-Log "Warning: LMSTUDIO_ENDPOINT doesn't end with '/v1/chat/completions'. This may cause API errors."
        Write-Log "Current endpoint: $lmStudioEndpoint"
        Write-Log "Recommended format: http://host:port/v1/chat/completions"
        
        # Auto-fix the endpoint if it doesn't have the correct path
        if ($lmStudioEndpoint -match '^(https?://[^/]+)/?$') {
            $fixedEndpoint = "$($matches[1])/v1/chat/completions"
            Write-Log "Auto-fixing endpoint to: $fixedEndpoint"
            [Environment]::SetEnvironmentVariable("LMSTUDIO_ENDPOINT", $fixedEndpoint)
            
            # Update the .env file
            $envContent = Get-Content -Path $envFile
            $updatedContent = $envContent -replace "LMSTUDIO_ENDPOINT=.*", "LMSTUDIO_ENDPOINT=$fixedEndpoint"
            $updatedContent | Set-Content -Path $envFile
            Write-Log "Updated .env file with corrected endpoint"
        }
    }
} else {
    Write-Log "Warning: .env file not found at $envFile. Using default configuration."
}

while ($retryCount -lt $maxRetries) {
    try {
        Write-Log "Attempt $($retryCount + 1) of $($maxRetries): Starting script..."
        
        # Start PowerShell 7 with elevated privileges to run the script
        # When using -Verb RunAs, we can't use -NoNewWindow
        $process = Start-Process pwsh -ArgumentList "-File `"$scriptPath`"" -PassThru -Verb RunAs
        
        # Wait for the process to exit
        $process.WaitForExit()
        
        $exitCode = $process.ExitCode
        Write-Log "Script exited with code: $exitCode"
        
        # Check for specific error codes
        if ($exitCode -eq 1) {
            Write-Log "Error detected. Checking error logs..."
            $errorFiles = Get-ChildItem -Path (Split-Path $scriptPath) -Filter "Error_*.json" | 
                          Sort-Object LastWriteTime -Descending | 
                          Select-Object -First 1
            
            if ($errorFiles) {
                $errorContent = Get-Content -Path $errorFiles.FullName -Raw
                Write-Log "Latest error: $errorContent"
                
                # Check for API endpoint errors
                if ($errorContent -match "Unexpected endpoint" -or $errorContent -match "404 Not Found") {
                    Write-Log "API endpoint error detected. Please check LMSTUDIO_ENDPOINT in .env file."
                }
            }
        }
        
        # Increment retry counter
        $retryCount++
        
        # Wait before restarting
        Write-Log "Waiting $waitTime seconds before restarting..."
        Start-Sleep -Seconds $waitTime
    }
    catch {
        Write-Log "Error monitoring script: $_"
        $retryCount++
        Start-Sleep -Seconds $waitTime
    }
}

Write-Log "Maximum retry attempts ($maxRetries) reached. Monitoring stopped."
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")