#Requires -Version 7.0
<#
.SYNOPSIS
Automatically fill blank markdown files using multiple LLM providers with scheduled execution

.NOTES
1. Requires PowerShell 7+ (install from https://aka.ms/install-powershell)
2. Configure API keys in .env file
3. Run in directory with target markdown files
4. Scheduling parameters controlled through $SCHEDULE_CONFIG
#>

# Load .env file if it exists
function Import-DotEnv {
    param(
        [string]$EnvFile = ".env"
    )
    
    if (Test-Path $EnvFile) {
        Write-Host "Loading configuration from $EnvFile"
        Get-Content $EnvFile | ForEach-Object {
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
    }
}

# Load environment variables
Import-DotEnv

# Configuration Constants
$DEBUG_CONFIG = @{
    LogRequests     = [System.Convert]::ToBoolean($env:DEBUG_LOG_REQUESTS ?? "true")
    SaveJsonDumps   = [System.Convert]::ToBoolean($env:DEBUG_SAVE_JSON_DUMPS ?? "true")
    ShowFullErrors  = [System.Convert]::ToBoolean($env:DEBUG_SHOW_FULL_ERRORS ?? "true")
}

$SCHEDULE_CONFIG = @{
    StartDelayHours = [double]($env:SCHEDULE_START_DELAY_HOURS ?? 0.000001)
    TimeoutHours    = [double]($env:SCHEDULE_TIMEOUT_HOURS ?? 10000)
    CheckInterval   = [int]($env:CHECK_INTERVAL ?? 30)
}

# Token Configuration
$TOKEN_CONFIG = @{
    MaxTokens          = [int]($env:MAX_TOKENS ?? 16384)
    MaxChunkSize       = [int]($env:MAX_CHUNK_SIZE ?? 48000)
    MinTokenThreshold  = [int]($env:MIN_TOKEN_THRESHOLD ?? 5000)
    MaxTokenThreshold  = [int]($env:MAX_TOKEN_THRESHOLD ?? 20000)
}

# LLM Provider Configuration
$LLM_PROVIDER = $env:LLM_PROVIDER ?? "lmstudio"

# Multi-provider LLM Configuration
$LLM_CONFIG = @{
    # LM Studio Configuration
    lmstudio = @{
        BaseURL         = $env:LMSTUDIO_ENDPOINT ?? "http://localhost:1234/v1/chat/completions"
        Model           = $env:LMSTUDIO_MODEL ?? "local-model"
        SystemMessage   = "You are a scientific reasoning expert. Analyze from multiple perspectives: physical mechanisms, mathematical models, experimental validation, and practical applications. Maintain rigorous academic standards. Please be extremely strict to mermaid format."
        Temperature     = [double]($env:TEMPERATURE ?? 0.7)
        MaxTokens       = [int]($env:MAX_TOKENS ?? 16384)
        ApiKey          = $env:LMSTUDIO_API_KEY ?? "EMPTY"
    }
    
    # DeepSeek Configuration
    deepseek = @{
        BaseURL         = $env:DEEPSEEK_ENDPOINT ?? "https://api.deepseek.com/v1/chat/completions"
        Model           = $env:DEEPSEEK_MODEL ?? "deepseek-reasoner"
        SystemMessage   = "You are a scientific reasoning expert. Analyze from multiple perspectives: physical mechanisms, mathematical models, experimental validation, and practical applications. Maintain rigorous academic standards. Please be extremely strict to mermaid format."
        Temperature     = [double]($env:TEMPERATURE ?? 0.7)
        MaxTokens       = [int]($env:MAX_TOKENS ?? 16384)
        ApiKey          = $env:DEEPSEEK_API_KEY
    }
    
    # OpenAI Configuration
    openai = @{
        BaseURL         = $env:OPENAI_ENDPOINT ?? "https://api.openai.com/v1/chat/completions"
        Model           = $env:OPENAI_MODEL ?? "gpt-4o"
        SystemMessage   = "You are a scientific reasoning expert. Analyze from multiple perspectives: physical mechanisms, mathematical models, experimental validation, and practical applications. Maintain rigorous academic standards. Please be extremely strict to mermaid format."
        Temperature     = [double]($env:TEMPERATURE ?? 0.7)
        MaxTokens       = [int]($env:MAX_TOKENS ?? 16384)
        ApiKey          = $env:OPENAI_API_KEY
    }
    
    # OpenRouter Configuration
    openrouter = @{
        BaseURL         = $env:OPENROUTER_ENDPOINT ?? "https://openrouter.ai/api/v1/chat/completions"
        Model           = $env:OPENROUTER_MODEL ?? "deepseek/deepseek-chat-v3-0324:free"
        FallbackModel   = $env:OPENROUTER_FALLBACK_MODEL ?? "mistralai/mistral-small-3.1-24b-instruct:free"
        SystemMessage   = "You are a scientific reasoning expert. Analyze from multiple perspectives: physical mechanisms, mathematical models, experimental validation, and practical applications. Maintain rigorous academic standards. Please be extremely strict to mermaid format."
        MaxTokens       = 16384
        Temperature     = 0.7
        TopP            = 0.9
        FrequencyPenalty = 0.0
        PresencePenalty = 0.0
    }

    # Anthropic Configuration
    anthropic = @{
        BaseURL         = "https://api.anthropic.com/v1/messages"
        Model           = $env:ANTHROPIC_MODEL ?? "claude-3-5-sonnet-20241022"
        SystemMessage   = "You are a scientific reasoning expert. Analyze from multiple perspectives: physical mechanisms, mathematical models, experimental validation, and practical applications. Maintain rigorous academic standards. Please be extremely strict to mermaid format."
        Temperature     = [double]($env:TEMPERATURE ?? 0.7)
        MaxTokens       = [int]($env:MAX_TOKENS ?? 16384)
        ApiKey          = $env:ANTHROPIC_API_KEY
    }
    
    # Google Configuration
    google = @{
        BaseURL         = "https://generativelanguage.googleapis.com/v1beta/models"
        Model           = $env:GOOGLE_MODEL ?? "gemini-2.0-flash-exp"
        SystemMessage   = "You are a scientific reasoning expert. Analyze from multiple perspectives: physical mechanisms, mathematical models, experimental validation, and practical applications. Maintain rigorous academic standards. Please be extremely strict to mermaid format."
        Temperature     = [double]($env:TEMPERATURE ?? 0.7)
        MaxTokens       = [int]($env:MAX_TOKENS ?? 16384)
        ApiKey          = $env:GOOGLE_API_KEY
    }
    
    # Mistral Configuration
    mistral = @{
        BaseURL         = $env:MISTRAL_ENDPOINT ?? "https://api.mistral.ai/v1/chat/completions"
        Model           = $env:MISTRAL_MODEL ?? "mistral-large-latest"
        SystemMessage   = "You are a scientific reasoning expert. Analyze from multiple perspectives: physical mechanisms, mathematical models, experimental validation, and practical applications. Maintain rigorous academic standards. Please be extremely strict to mermaid format."
        Temperature     = [double]($env:TEMPERATURE ?? 0.7)
        MaxTokens       = [int]($env:MAX_TOKENS ?? 16384)
        ApiKey          = $env:MISTRAL_API_KEY
    }
    
    # Azure OpenAI Configuration
    azure_openai = @{
        BaseURL         = $env:AZURE_OPENAI_ENDPOINT
        Model           = $env:AZURE_OPENAI_MODEL ?? "gpt-4o"
        SystemMessage   = "You are a scientific reasoning expert. Analyze from multiple perspectives: physical mechanisms, mathematical models, experimental validation, and practical applications. Maintain rigorous academic standards. Please be extremely strict to mermaid format."
        Temperature     = [double]($env:TEMPERATURE ?? 0.7)
        MaxTokens       = [int]($env:MAX_TOKENS ?? 16384)
        ApiKey          = $env:AZURE_OPENAI_API_KEY
        ApiVersion      = $env:AZURE_OPENAI_API_VERSION ?? "2025-01-01-preview"
    }
    
    # Ollama Configuration
    ollama = @{
        BaseURL         = $env:OLLAMA_ENDPOINT ?? "http://localhost:11434/api/chat"
        Model           = $env:OLLAMA_MODEL ?? "llama3"
        SystemMessage   = "You are a scientific reasoning expert. Analyze from multiple perspectives: physical mechanisms, mathematical models, experimental validation, and practical applications. Maintain rigorous academic standards. Please be extremely strict to mermaid format."
        Temperature     = [double]($env:TEMPERATURE ?? 0.7)
        MaxTokens       = [int]($env:MAX_TOKENS ?? 16384)
    }
}

# Set the active LLM configuration
$ACTIVE_LLM = $LLM_CONFIG[$LLM_PROVIDER.ToLower()]
if (-not $ACTIVE_LLM) {
    Write-Warning "Invalid LLM provider: $LLM_PROVIDER. Defaulting to LM Studio."
    $LLM_PROVIDER = "lmstudio"
    $ACTIVE_LLM = $LLM_CONFIG["lmstudio"]
}


# API configuration (for backward compatibility)
$LMSTUDIO_CONFIG = @{
    BaseURL         = $ACTIVE_LLM.BaseURL
    Model           = $ACTIVE_LLM.Model
    SystemMessage   = $ACTIVE_LLM.SystemMessage
    Temperature     = $ACTIVE_LLM.Temperature
    MaxTokens       = $ACTIVE_LLM.MaxTokens
    JsonDepth       = 10
    LineWrap        = 80
    FileCheckRetries= 3
    HeaderPattern   = '^#{1,6}\s+'
    AllowFrontMatter= $true
    MaxEmptyLines   = 3
    MaxRetries      = 5
    RetryDelay      = 5
}

# Update SEARCH_CONFIG to set maximum page search to 5
$SEARCH_CONFIG = @{
    BaseURL         = "https://html.duckduckgo.com/html"
    UserAgent       = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    ResultCount     = [int]($env:SEARCH_MAX_RESULTS ?? 10)
    MaxPageSearch   = [int]($env:SEARCH_MAX_PAGES ?? 5)
    Timeout         = 30
    SearchTimeout   = [int]($env:SEARCH_TIMEOUT ?? 120)
    RetryCount      = 3
    RetryDelay      = 2
    EnableSearch    = [System.Convert]::ToBoolean($env:SEARCH_ENABLED ?? "true")
    ShowProgress    = [System.Convert]::ToBoolean($env:SEARCH_SHOW_PROGRESS ?? "true")
}

# Environment configuration
if ($ACTIVE_LLM.ApiKey) {
    $env:LMSTUDIO_API_KEY = $ACTIVE_LLM.ApiKey
} else {
    $env:LMSTUDIO_API_KEY = 'EMPTY'
}

# After (Local HTTP - remove TLS requirements)
# Enhanced TLS configuration for web requests
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor 
                                                    [System.Net.SecurityProtocolType]::Tls11 -bor 
                                                    [System.Net.SecurityProtocolType]::Tls -bor 
                                                    [System.Net.SecurityProtocolType]::SystemDefault

# Bypass SSL certificate validation (use with caution)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

function Invoke-LLMRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserPrompt,
        [Parameter(Mandatory)]
        [string]$BaseName,
        [string]$SystemMessage = "",
        [double]$Temperature = -1,
        [int]$MaxTokens = -1
    )

    $retryCount = 0
    $provider = $LLM_PROVIDER.ToLower()
    $config = $ACTIVE_LLM
    
    $systemMsg = if ([string]::IsNullOrWhiteSpace($SystemMessage)) { $config.SystemMessage } else { $SystemMessage }
    $temp = if ($Temperature -lt 0) { $config.Temperature } else { $Temperature }
    $tokens = if ($MaxTokens -lt 0) { $config.MaxTokens } else { $MaxTokens }
    
    # Set up headers based on provider
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    # Add authorization header based on provider
    switch ($provider) {
        "lmstudio" {
            $headers["Authorization"] = "Bearer $($env:LMSTUDIO_API_KEY)"
        }
        "deepseek" {
            $headers["Authorization"] = "Bearer $($env:DEEPSEEK_API_KEY)"
        }
        "openai" {
            $headers["Authorization"] = "Bearer $($env:OPENAI_API_KEY)"
        }
        "anthropic" {
            $headers["x-api-key"] = "$($env:ANTHROPIC_API_KEY)"
            $headers["anthropic-version"] = "2023-06-01"
        }
        "google" {
            # Google uses API key in URL
        }
        "mistral" {
            $headers["Authorization"] = "Bearer $($env:MISTRAL_API_KEY)"
        }
        "azure_openai" {
            $headers["api-key"] = "$($env:AZURE_OPENAI_API_KEY)"
        }
        "ollama" {
            # Ollama doesn't require authentication
        }
        "openrouter" {
            $headers["Authorization"] = "Bearer $($env:OPENROUTER_API_KEY)"
            $headers["HTTP-Referer"] = "https://localhost"
            $headers["X-Title"] = "LLMs Markdown Generator"  # Added X-Title header
        }
    }

    do {
        try {
            if ($BaseName -match '{|}' -or $BaseName -eq '') {
                throw "Invalid BaseName contains format specifiers or is empty"
            }
            $structuredPrompt = @" 
**Documentation Structure Requirements** 
1. First line MUST be: ## {0} Analysis 
2. Use Markdown formatting without code wrappers

**Example Structure**
## {0} Analysis
### Fundamental Principles

\$\$
   I(z) = I_0 e^{{-\alpha z}}
\$\$
   Where :  
- \$I(z)\$ = intensity at depth \$z\$
- \$I_0\$ = incident intensity
- \$\alpha\$ = absorption coefficient
(The relevant parameters should also be in markdown format \$\$ rather than enclosed in parentheses such as \(\). The “\” in “\$” is an escape symbol and should be omitted in the actual output.)

### Performance Metrics

| Metric | Typical Value | Unit |
|--------|---------------|------|
| Thermal Diffusivity | 0.8 | mm²/s |

(Please pay strict attention to the mermaid format,must beginning with "``````mermaid" and ending with "``````" after the last "];".)
``````mermaid
graph TD;
    A[Cumulative Probability Distribution] --> B[Probability Density Function];
    A --> C[Risk Management];
    A --> D[Engineering Reliability];
    A --> E[Quality Control];
    B --> F[Parameter Estimation];
    F --> G[Maximum Likelihood Estimation];
``````

**References**

- Smith et al. (2020). Journal of Thermal Analysis. DOI:10.xxxx
"@ -f $BaseName
            
            # Create request body based on provider
            $body = $null
            $uri = $config.BaseURL
            
            switch ($provider) {
                "lmstudio" {
                    $body = @{
                        model       = $config.Model
                        messages    = @(
                            @{ role = "system"; content = $systemMsg }
                            @{ role = "user"; content = $structuredPrompt + "`n" + $UserPrompt }
                        )
                        temperature = $temp
                        max_tokens  = $tokens
                    }
                }
                "deepseek" {
                    $body = @{
                        model       = $config.Model
                        messages    = @(
                            @{ role = "system"; content = $systemMsg }
                            @{ role = "user"; content = $structuredPrompt + "`n" + $UserPrompt }
                        )
                        temperature = $temp
                        max_tokens  = $tokens
                    }
                }
                "openai" {
                    $body = @{
                        model       = $config.Model
                        messages    = @(
                            @{ role = "system"; content = $systemMsg }
                            @{ role = "user"; content = $structuredPrompt + "`n" + $UserPrompt }
                        )
                        temperature = $temp
                        max_tokens  = $tokens
                    }
                }
                "anthropic" {
                    $body = @{
                        model       = $config.Model
                        system      = $systemMsg
                        messages    = @(
                            @{ role = "user"; content = $structuredPrompt + "`n" + $UserPrompt }
                        )
                        temperature = $temp
                        max_tokens  = $tokens
                    }
                }
                "google" {
                    $uri = "$($config.BaseURL)/$($config.Model):generateContent?key=$($config.ApiKey)"
                    $body = @{
                        contents    = @(
                            @{
                                role = "user"
                                parts = @(
                                    @{ text = $structuredPrompt + "`n" + $UserPrompt }
                                )
                            }
                        )
                        systemInstruction = @{
                            text = $systemMsg
                        }
                        generationConfig = @{
                            temperature = $temp
                            maxOutputTokens = $tokens
                        }
                    }
                }
                "mistral" {
                    $body = @{
                        model       = $config.Model
                        messages    = @(
                            @{ role = "system"; content = $systemMsg }
                            @{ role = "user"; content = $structuredPrompt + "`n" + $UserPrompt }
                        )
                        temperature = $temp
                        max_tokens  = $tokens
                    }
                }
                "azure_openai" {
                    $uri = "$($config.BaseURL)/openai/deployments/$($config.Model)/chat/completions?api-version=$($config.ApiVersion)"
                    $body = @{
                        messages    = @(
                            @{ role = "system"; content = $systemMsg }
                            @{ role = "user"; content = $structuredPrompt + "`n" + $UserPrompt }
                        )
                        temperature = $temp
                        max_tokens  = $tokens
                    }
                }
                "ollama" {
                    $body = @{
                        model       = $config.Model
                        messages    = @(
                            @{ role = "system"; content = $systemMsg }
                            @{ role = "user"; content = $structuredPrompt + "`n" + $UserPrompt }
                        )
                        options     = @{
                            temperature = $temp
                            num_predict = $tokens
                        }
                        stream      = $false
                    }
                }
                "openrouter" {
                    $body = @{
                        model       = $config.Model
                        messages    = @(
                            @{ role = "system"; content = $systemMsg }
                            @{ role = "user"; content = $structuredPrompt + "`n" + $UserPrompt }
                        )
                        temperature = $temp
                        max_tokens  = $tokens
                        fallbacks   = @($config.FallbackModel)
                    }
                }
            }

            if ($DEBUG_CONFIG.LogRequests) {
                Write-Host "[DEBUG] Request Headers:`n$($headers | ConvertTo-Json)"
                $jsonBody = $body | ConvertTo-Json -Depth 10
                Write-Host "[DEBUG] Request Body:`n$jsonBody"
            }

            # Increased timeout to 30 minutes (1800 seconds)
            $response = Invoke-RestMethod -Uri $uri `
                -Method Post `
                -Headers $headers `
                -Body ($body | ConvertTo-Json -Depth 10) `
                -TimeoutSec 1800 `
                -ErrorAction Stop

            # Extract content based on provider
            $content = $null
            
            switch ($provider) {
                "lmstudio" {
                    if (-not $response.choices) {
                        $responseJson = $response | ConvertTo-Json -Depth 10
                        throw "Invalid API response structure. Full response:`n$responseJson"
                    }
                    $content = $response.choices[0].message.content
                }
                "deepseek" {
                    if (-not $response.choices) {
                        $responseJson = $response | ConvertTo-Json -Depth 10
                        throw "Invalid API response structure. Full response:`n$responseJson"
                    }
                    $content = $response.choices[0].message.content
                }
                "openai" {
                    if (-not $response.choices) {
                        $responseJson = $response | ConvertTo-Json -Depth 10
                        throw "Invalid API response structure. Full response:`n$responseJson"
                    }
                    $content = $response.choices[0].message.content
                }
                "anthropic" {
                    if (-not $response.content) {
                        $responseJson = $response | ConvertTo-Json -Depth 10
                        throw "Invalid API response structure. Full response:`n$responseJson"
                    }
                    $content = $response.content[0].text
                }
                "google" {
                    if (-not $response.candidates) {
                        $responseJson = $response | ConvertTo-Json -Depth 10
                        throw "Invalid API response structure. Full response:`n$responseJson"
                    }
                    $content = $response.candidates[0].content.parts[0].text
                }
                "mistral" {
                    if (-not $response.choices) {
                        $responseJson = $response | ConvertTo-Json -Depth 10
                        throw "Invalid API response structure. Full response:`n$responseJson"
                    }
                    $content = $response.choices[0].message.content
                }
                "azure_openai" {
                    if (-not $response.choices) {
                        $responseJson = $response | ConvertTo-Json -Depth 10
                        throw "Invalid API response structure. Full response:`n$responseJson"
                    }
                    $content = $response.choices[0].message.content
                }
                "ollama" {
                    if (-not $response.message) {
                        $responseJson = $response | ConvertTo-Json -Depth 10
                        throw "Invalid API response structure. Full response:`n$responseJson"
                    }
                    $content = $response.message.content
                }
                "openrouter" {
                    if (-not $response.choices) {
                        $responseJson = $response | ConvertTo-Json -Depth 10
                        throw "Invalid API response structure. Full response:`n$responseJson"
                    }
                    $content = $response.choices[0].message.content
                }
            }

            if ([string]::IsNullOrEmpty($content)) {
                throw "Empty content in API response"
            }

            return $content
        }
        catch {
            # Error handling remains the same as in the original function
            $errorMsg = $_.Exception.Message
            $webException = $_.Exception -as [System.Net.WebException]

            # Handle timeout special case
            if ($webException -and $webException.Status -eq [System.Net.WebExceptionStatus]::Timeout) {
                if ($DEBUG_CONFIG.ShowFullErrors) {
                    Write-Host "[TIMEOUT] Request timed out after 30 minutes. Retrying in 60 seconds..."
                }
                
                # Log timeout details
                $timeoutLog = @{
                    Timestamp     = Get-Date -Format 'o'
                    FileName      = $BaseName
                    ErrorType     = 'Timeout'
                    RetryCount    = $retryCount
                    NextRetry     = (Get-Date).AddSeconds(60).ToString('o')
                    SystemStatus  = @{
                        Memory = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
                        CPU    = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
                    }
                }
                $timeoutLog | ConvertTo-Json | Out-File "Timeout_$BaseName.log" -Append

                # Wait exactly 1 minute (60 seconds)
                Start-Sleep -Seconds 60
                continue  # Bypass normal retry counter
            }
            # Handle other errors
            else {
                $retryCount++
                if ($retryCount -ge $LMSTUDIO_CONFIG.MaxRetries) {
                    $errorDetails = @{
                        FinalAttempt = $true
                        Error        = $errorMsg
                        Retries      = $retryCount
                        Timestamp    = Get-Date -Format 'o'
                    }
                    $errorDetails | ConvertTo-Json | Out-File "Error_$BaseName.json" -Append
                    throw "API Request Failed after $retryCount attempts: $errorMsg"
                }

                if ($DEBUG_CONFIG.ShowFullErrors) {
                    Write-Host "[RETRYING] Attempt $retryCount failed: $errorMsg"
                }

                # Calculate exponential backoff with jitter
                $baseDelay = [Math]::Pow(2, $retryCount) * $LMSTUDIO_CONFIG.RetryDelay
                $jitter = Get-Random -Minimum -0.5 -Maximum 0.5
                $delay = [Math]::Round($baseDelay * (1 + $jitter))
                
                # Log retry details
                $retryLog = @{
                    Timestamp     = Get-Date -Format 'o'
                    FileName      = $BaseName
                    Error         = $errorMsg
                    RetryCount    = $retryCount
                    NextRetry     = (Get-Date).AddSeconds($delay).ToString('o')
                    DelaySeconds  = $delay
                }
                $retryLog | ConvertTo-Json | Out-File "Retry_$BaseName.log" -Append

                Start-Sleep -Seconds $delay
            }
        }
    } while ($true)
}

# Add cookie handling function
function Initialize-CookieContainer {
    [CmdletBinding()]
    param()
    
    try {
        # Create a global cookie container to handle cookie consent popups
        $Global:CookieContainer = New-Object System.Net.CookieContainer
        
        # Add common cookie consent values
        $cookieConsent = New-Object System.Net.Cookie
        $cookieConsent.Name = "cookieconsent_status"
        $cookieConsent.Value = "dismiss"
        $cookieConsent.Domain = ".example.org"
        $Global:CookieContainer.Add($cookieConsent)
        
        # Add GDPR consent cookie
        $gdprConsent = New-Object System.Net.Cookie
        $gdprConsent.Name = "euconsent"
        $gdprConsent.Value = "accepted"
        $gdprConsent.Domain = ".example.org"
        $Global:CookieContainer.Add($gdprConsent)
        
        Write-Host "[INFO] Cookie container initialized for handling consent popups"
        return $true
    }
    catch {
        Write-Warning "Failed to initialize cookie container: $($_.Exception.Message)"
        return $false
    }
}

# Initialize cookie container at script start
Initialize-CookieContainer

function Get-ValidMarkdownFiles {
    [CmdletBinding()]
    param()

    try {
        $allFiles = Get-ChildItem -Path . -Filter *.md -File -ErrorAction Stop
        $validFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

        foreach ($file in $allFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Encoding UTF8 -ErrorAction Stop
                
                if ($content -match "# Generated by LMStudio Reasoner") {
                    Write-Warning "Skipping processed file: $($file.Name)"
                    # Move the processed file to the destination directory
                    Move-ProcessedFile -File $file
                    continue
                }

                $headerOffset = 0
                if ($LMSTUDIO_CONFIG.AllowFrontMatter -and 
                    $content.Count -ge 3 -and 
                    $content[0] -eq '---' -and 
                    $content[-1] -eq '---') {
                    $headerOffset = 2
                }

                $headerLine = $content | 
                    Select-Object -Skip $headerOffset |
                    Where-Object { $_.Trim() -ne '' } | 
                    Select-Object -First 1

                if (-not $headerLine -or $headerLine -notmatch $LMSTUDIO_CONFIG.HeaderPattern) {
                    Write-Warning "Skipping $($file.Name) - no valid header found"
                    continue
                }

                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $headerText = $headerLine -replace $LMSTUDIO_CONFIG.HeaderPattern, '' |
                    ForEach-Object { $_.Trim() }

                # Enhanced normalization with case folding
                $processedName = (($baseName -replace '[-_]', ' ') -replace '[^\p{L}\p{N}\s]', '') `
                    -replace '\s{2,}', ' ' -replace '_', ' ' `
                    | ForEach-Object { $_.Trim() } `
                    | ForEach-Object { $_.ToLower() }

                $processedHeader = (($headerText -replace '[-_]', ' ') -replace '[^\p{L}\p{N}\s]', '') `
                    -replace '\s{2,}', ' ' -replace '_', ' ' `
                    | ForEach-Object { $_.Trim() } `
                    | ForEach-Object { $_.ToLower() }

                # Calculate similarity instead of exact match
                $similarity = Get-StringSimilarity -String1 $processedName -String2 $processedHeader
                
                if ($similarity -lt 0.8) {
                    Write-Warning "Skipping $($file.Name) - filename/header similarity too low ($similarity)`nFile: '$baseName' → '$processedName'`nHeader: '$headerText' → '$processedHeader'"
                    continue
                }

                # Strict empty content check
                $nonEmptyLines = $content | 
                    Select-Object -Skip ($headerOffset + 1) |
                    Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^---$' }
                
                if ($nonEmptyLines.Count -gt 0) {
                    Write-Warning "Skipping $($file.Name) - contains $($nonEmptyLines.Count) non-empty lines"
                    continue
                }

                $validFiles.Add($file)
            }
            catch [System.IO.IOException] {
                Write-Warning "File access error: $($file.Name)"
            }
        }
        return $validFiles
    }
    catch {
        Write-Error "Directory scan failed: $_"
        exit 1
    }
}

function Get-StringSimilarity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$String1,
        
        [Parameter(Mandatory)]
        [string]$String2
    )
    
    try {
        # If either string is empty, return 0
        if ([string]::IsNullOrEmpty($String1) -or [string]::IsNullOrEmpty($String2)) {
            return 0
        }
        
        # If strings are identical, return 1
        if ($String1 -eq $String2) {
            return 1
        }
        
        # Calculate character frequency in both strings
        $chars1 = @{}
        $chars2 = @{}
        
        # Count characters in first string
        foreach ($char in $String1.ToCharArray()) {
            if ($chars1.ContainsKey($char)) {
                $chars1[$char]++
            } else {
                $chars1[$char] = 1
            }
        }
        
        # Count characters in second string
        foreach ($char in $String2.ToCharArray()) {
            if ($chars2.ContainsKey($char)) {
                $chars2[$char]++
            } else {
                $chars2[$char] = 1
            }
        }
        
        # Calculate intersection (characters in both strings)
        $intersection = 0
        foreach ($char in $chars1.Keys) {
            if ($chars2.ContainsKey($char)) {
                $intersection += [Math]::Min($chars1[$char], $chars2[$char])
            }
        }
        
        # Calculate union (total characters)
        $union = $String1.Length + $String2.Length - $intersection
        
        # Calculate Jaccard similarity coefficient
        $similarity = $intersection / $union
        
        return $similarity
    }
    catch {
        Write-Error "Error calculating string similarity: $_"
        return 0
    }
}

function Move-ProcessedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,
        [string]$DestinationPath = "E:\Knowledge\Study\dp_know"
    )

    try {
        # Ensure destination directory exists
        if (-not (Test-Path -Path $DestinationPath -PathType Container)) {
            Write-Host "[MOVE] Creating destination directory: $DestinationPath"
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        }

        # Construct destination file path
        $destinationFile = Join-Path -Path $DestinationPath -ChildPath $File.Name

        # Check if file already exists at destination
        if (Test-Path -Path $destinationFile) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $newFileName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name) + 
                           "_$timestamp" + 
                           [System.IO.Path]::GetExtension($File.Name)
            $destinationFile = Join-Path -Path $DestinationPath -ChildPath $newFileName
            Write-Host "[MOVE] File already exists at destination. Renaming to: $newFileName"
        }

        # Move the file
        Move-Item -Path $File.FullName -Destination $destinationFile -Force
        Write-Host "[MOVE] Successfully moved $($File.Name) to $DestinationPath"
        return $true
    }
    catch {
        Write-Warning "Failed to move file $($File.Name): $($_.Exception.Message)"
        return $false
    }
}


# Update the Test-LLMConnection function to support OpenRouter
function Test-LLMConnection {
    [CmdletBinding()]
    param()
    try {
        Write-Host "Running API connectivity tests..."
        $provider = $LLM_PROVIDER.ToLower()
        $config = $ACTIVE_LLM
        
        # Set up headers based on provider
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        # Add authorization header based on provider
        switch ($provider) {
            "lmstudio" {
                # Verify local port first for LM Studio
                try {
                    $uri = $config.BaseURL
                    $testResponse = Invoke-WebRequest -Uri $uri -Method Head -TimeoutSec 10 -ErrorAction Stop
                    Write-Host "[Network Diagnostic] LM Studio endpoint is accessible"
                }
                catch {
                    Write-Host "[Network Diagnostic] Unable to connect to LM Studio at $uri"
                    Write-Host "Local Service Checks:"
                    Write-Error "API connection failed. Check:
1. LM Studio is running
2. Correct port configuration (default: 1234)
3. Base URL: $($config.BaseURL)"
                    return $false
                }
                $headers["Authorization"] = "Bearer $($env:LMSTUDIO_API_KEY)"
            }
            "deepseek" {
                $headers["Authorization"] = "Bearer $($env:DEEPSEEK_API_KEY)"
            }
            "openai" {
                $headers["Authorization"] = "Bearer $($env:OPENAI_API_KEY)"
            }
            "openrouter" {
                $headers["Authorization"] = "Bearer $($env:OPENROUTER_API_KEY)"
                $headers["HTTP-Referer"] = "https://localhost"  
                $headers["X-Title"] = "LLMs Markdown Content Generator"
            }
            "anthropic" {
                $headers["x-api-key"] = "$($env:ANTHROPIC_API_KEY)"
                $headers["anthropic-version"] = "2023-06-01"
            }
            "google" {
                # Google uses API key in URL
            }
            "mistral" {
                $headers["Authorization"] = "Bearer $($env:MISTRAL_API_KEY)"
            }
            "azure_openai" {
                $headers["api-key"] = "$($env:AZURE_OPENAI_API_KEY)"
            }
            "ollama" {
                # Ollama doesn't require authentication
                # Check if Ollama is running on the default port
                try {
                    $portTest = Test-NetConnection -ComputerName localhost -Port 11434 -ErrorAction Stop
                    if (-not $portTest.TcpTestSucceeded) {
                        throw "Ollama API port 11434 not accessible"
                    }
                }
                catch {
                    Write-Host "[Network Diagnostic] Unable to connect to Ollama at localhost:11434"
                    Write-Host "Local Service Checks:"
                    Write-Error "API connection failed. Check:
1. Ollama is running
2. Correct port configuration (default: 11434)
3. Base URL: $($config.BaseURL)"
                    return $false
                }
            }
        }

        # Create request body based on provider
        $body = $null
        $uri = $config.BaseURL
        
        switch ($provider) {
            "lmstudio" {
                $body = @{
                    model       = $config.Model
                    messages    = @(
                        @{ role = "user"; content = "Connection test" }
                    )
                    max_tokens  = 1
                    stream      = $false
                }
            }
            "deepseek" {
                $body = @{
                    model       = $config.Model
                    messages    = @(
                        @{ role = "user"; content = "Connection test" }
                    )
                    max_tokens  = 1
                }
            }
            "openai" {
                $body = @{
                    model       = $config.Model
                    messages    = @(
                        @{ role = "user"; content = "Connection test" }
                    )
                    max_tokens  = 1
                }
            }
            "openrouter" {
                $body = @{
                    model       = $config.Model
                    messages    = @(
                        @{ role = "user"; content = "Connection test" }
                    )
                    max_tokens  = 1
                }
            }
            "anthropic" {
                $body = @{
                    model       = $config.Model
                    messages    = @(
                        @{ role = "user"; content = "Connection test" }
                    )
                    max_tokens  = 1
                }
            }
            "google" {
                $uri = "$($config.BaseURL)/$($config.Model):generateContent?key=$($config.ApiKey)"
                $body = @{
                    contents    = @(
                        @{
                            role = "user"
                            parts = @(
                                @{ text = "Connection test" }
                            )
                        }
                    )
                    generationConfig = @{
                        maxOutputTokens = 1
                    }
                }
            }
            "mistral" {
                $body = @{
                    model       = $config.Model
                    messages    = @(
                        @{ role = "user"; content = "Connection test" }
                    )
                    max_tokens  = 1
                }
            }
            "azure_openai" {
                $uri = "$($config.BaseURL)/openai/deployments/$($config.Model)/chat/completions?api-version=$($config.ApiVersion)"
                $body = @{
                    messages    = @(
                        @{ role = "user"; content = "Connection test" }
                    )
                    max_tokens  = 1
                }
            }
            "ollama" {
                $body = @{
                    model       = $config.Model
                    messages    = @(
                        @{ role = "user"; content = "Connection test" }
                    )
                    options     = @{
                        num_predict = 1
                    }
                    stream      = $false
                }
            }
        }

        # Check if API key is empty or missing for providers that require it
        if ($provider -ne "lmstudio" -and $provider -ne "ollama") {
            $apiKey = switch ($provider) {
                "openai" { $env:OPENAI_API_KEY }
                "deepseek" { $env:DEEPSEEK_API_KEY }
                "anthropic" { $env:ANTHROPIC_API_KEY }
                "google" { $env:GOOGLE_API_KEY }
                "mistral" { $env:MISTRAL_API_KEY }
                "azure_openai" { $env:AZURE_OPENAI_API_KEY }
                "openrouter" { $env:OPENROUTER_API_KEY }
            }
            
            if ([string]::IsNullOrWhiteSpace($apiKey)) {
                Write-Host "[Network Diagnostic] API key for $provider is missing or empty"
                Write-Host "Local Service Checks:"
                Write-Error "API connection failed. Check:
1. API key validity
2. Network connectivity
3. Base URL: $uri"
                return $false
            }
        }

        # Make the API request
        Write-Host "Testing connection to $uri"
        $response = Invoke-RestMethod -Uri $uri `
            -Method Post `
            -Headers $headers `
            -Body ($body | ConvertTo-Json -Depth 10) `
            -TimeoutSec 30 `
            -ErrorAction Stop
        
        Write-Host "API connection successful!"
        return $true
    }
    catch {
        Write-Host "[Network Diagnostic]"
        Write-Host "Error: $($_.Exception.Message)"
        
        # More detailed error information
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $statusDescription = $_.Exception.Response.StatusDescription
            Write-Host "Status Code: $statusCode - $statusDescription"
            
            if ($statusCode -eq 401) {
                Write-Host "Authentication error: Please check your API key for $provider"
            }
        }
        
        # Check for provider-specific processes
        Write-Host "Local Service Checks:"
        switch ($provider) {
            "lmstudio" {
                try {
                    $processCheck = Get-Process lmstudio -ErrorAction Stop
                    Write-Host "LM Studio Process: $($processCheck.Id) - $($processCheck.StartTime)"
                }
                catch {
                    Write-Host "LM Studio Process: Not Running"
                }
            }
            "ollama" {
                try {
                    $processCheck = Get-Process ollama -ErrorAction Stop
                    Write-Host "Ollama Process: $($processCheck.Id) - $($processCheck.StartTime)"
                }
                catch {
                    Write-Host "Ollama Process: Not Running"
                }
            }
        }
        
        Write-Error "API connection failed. Check:
1. API key validity
2. Network connectivity
3. Base URL: $uri"
        return $false
    }
}


function Start-CountdownTimer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 2147483647)]
        [int]$Seconds,
        
        [string]$Message = "Countdown"
    )

    $endTime = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $endTime) {
        $remaining = $endTime - (Get-Date)
        $percentComplete = ($Seconds - $remaining.TotalSeconds) / $Seconds * 100
        Write-Progress -Activity $Message `
            -Status "Remaining: $($remaining.ToString('hh\:mm\:ss'))" `
            -PercentComplete $percentComplete `
            -SecondsRemaining $remaining.TotalSeconds
        Start-Sleep -Seconds 1
    }
    Write-Progress -Activity $Message -Completed
}

function Invoke-WebRequestWithTimeout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [hashtable]$Headers,
        [int]$MaximumRedirection = 10,
        [switch]$UseBasicParsing,
        [int]$TimeoutSeconds = 30
    )
    
    $scriptBlock = {
        param($Uri, $Headers, $MaximumRedirection, $UseBasicParsing)
        
        # Create a new WebRequestSession inside this runspace
        $webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        
        # Build parameters for Invoke-WebRequest
        $params = @{
            Uri = $Uri
            Headers = $Headers
            MaximumRedirection = $MaximumRedirection
            WebSession = $webSession
        }
        
        if ($UseBasicParsing) {
            $params.Add('UseBasicParsing', $true)
        }
        
        # Execute the web request
        Invoke-WebRequest @params
    }
    
    # Call our modified timeout function
    Invoke-ProcessWithTimeout -ScriptBlock $scriptBlock -TimeoutSeconds $TimeoutSeconds -ArgumentList @($Uri, $Headers, $MaximumRedirection, $UseBasicParsing)
}

function Invoke-ProcessWithTimeout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483647)]
        [int]$TimeoutSeconds,
        
        [Parameter()]
        [object[]]$ArgumentList
    )

    # Create a runspace for the script to run in
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    
    # Create PowerShell instance to run in the runspace
    $powershell = [powershell]::Create()
    $powershell.Runspace = $runspace
    
    # Add the script and arguments
    $powershell.AddScript($ScriptBlock)
    foreach ($arg in $ArgumentList) {
        $powershell.AddArgument($arg)
    }
    
    # Start the async operation
    $asyncResult = $powershell.BeginInvoke()
    
    # Wait for completion or timeout
    if ($asyncResult.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000)) {
        # Operation completed within timeout
        try {
            return $powershell.EndInvoke($asyncResult)
        }
        catch {
            throw $_
        }
    }
    else {
        # Operation timed out
        $powershell.Stop()
        throw "Process timeout after $TimeoutSeconds seconds"
    }
    finally {
        $powershell.Dispose()
        $runspace.Close()
        $runspace.Dispose()
    }
}


function Write-MarkdownContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,
        [Parameter(Mandatory)]
        [string]$Content
    )

    try {
        # Basic header validation only
        if ($Content -notmatch '(?im)^#{1,6}\s') {
            $sampleLine = ($Content -split "\r?\n" | Select-Object -First 1)
            Write-Warning "Header format issue in $($File.Name). First line: '$sampleLine'"
        }

        # Minimal cleaning preserving original content
        $cleanedContent = $Content -replace '(?m)^```(markdown)?\r?\n','' `
                                   -replace '(?m)^```\r?\n','' `
                                   -replace '\s+$',''

        $formattedContent = @(
            "",
            "---",
            "",
            $cleanedContent.Trim(),
            "",
            "# Generated by $($LLM_PROVIDER) LLM",
            "**Model**: $($ACTIVE_LLM.Model)",
            "**Timestamp**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            ""
        ) -join "`n"

        $formattedContent | Add-Content -Path $File.FullName -Encoding UTF8
        return $true
    }
    catch {
        # Generate error report without blocking content
        Write-Warning "Non-critical error processing $($File.Name): $($_.Exception.Message)"
        $Content | Out-File "$($File.FullName).raw" -Encoding UTF8
        return $false
    }
}



# Add required assembly for URL encoding/decoding
Add-Type -AssemblyName System.Web

function Invoke-DuckDuckGoSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        [int]$MaxResults = $SEARCH_CONFIG.ResultCount
    )
    
    try {
        if (-not $SEARCH_CONFIG.EnableSearch) {
            Write-Host "Web search is disabled in configuration."
            return "Web search is disabled."
        }
        
        # Add "wikipedia" to the search query to prioritize Wikipedia results
        $enhancedQuery = "$Query wikipedia"
        
        $searchUrl = $SEARCH_CONFIG.BaseURL
        $headers = @{
            "User-Agent" = $SEARCH_CONFIG.UserAgent
            "Content-Type" = "application/x-www-form-urlencoded"
        }
        
        $formData = @{
            q = $enhancedQuery
            b = ""
            kl = ""
        }
        
        # Convert form data to URL-encoded string
        $body = ($formData.GetEnumerator() | ForEach-Object { 
            "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))" 
        }) -join '&'
        
        if ($DEBUG_CONFIG.LogRequests) {
            Write-Host "[DEBUG] DuckDuckGo Search URL: $searchUrl"
            Write-Host "[DEBUG] Query: $enhancedQuery"
        }
        
        Write-Host "[SEARCH] Starting DuckDuckGo search with $($SEARCH_CONFIG.SearchTimeout) second timeout..."
        $searchStartTime = Get-Date
        
        # Instead of using Task.Run, use a direct approach with timeout
        $retryCount = 0
        $success = $false
        $results = $null
        
        # Create a timer for the overall search operation
        $searchTimer = [System.Diagnostics.Stopwatch]::StartNew()
        
        while (-not $success -and $retryCount -lt $SEARCH_CONFIG.RetryCount) {
            # Check if we've exceeded the search timeout
            if ($searchTimer.Elapsed.TotalSeconds -gt $SEARCH_CONFIG.SearchTimeout) {
                Write-Warning "[SEARCH] DuckDuckGo search timed out after $($SEARCH_CONFIG.SearchTimeout) seconds"
                return "DuckDuckGo search timed out after $($SEARCH_CONFIG.SearchTimeout) seconds. Proceeding with partial or no results."
            }
            
            try {
                # Use Invoke-WebRequest with its own timeout
                $response = Invoke-WebRequest -Uri $searchUrl -Method Post -Headers $headers -Body $body -TimeoutSec $SEARCH_CONFIG.Timeout
                $success = $true
                
                # Parse HTML response
                $html = $response.Content
                $results = Parse-SearchResults -Html $html -MaxResults $MaxResults
            }
            catch {
                $retryCount++
                if ($retryCount -ge $SEARCH_CONFIG.RetryCount) {
                    throw "DuckDuckGo Search failed after $retryCount attempts: $($_.Exception.Message)"
                }
                
                Write-Warning "DuckDuckGo Search attempt $retryCount failed: $($_.Exception.Message). Retrying in $($SEARCH_CONFIG.RetryDelay) seconds..."
                Start-Sleep -Seconds $SEARCH_CONFIG.RetryDelay
            }
        }
        
        $searchTimer.Stop()
        $searchDuration = (Get-Date) - $searchStartTime
        Write-Host "[SEARCH] DuckDuckGo search completed in $($searchDuration.TotalSeconds.ToString('0.00')) seconds"
        return Format-SearchResultsForLLM -Results $results
    }
    catch {
        Write-Error "DuckDuckGo Search Error: $($_.Exception.Message)"
        return "Error performing DuckDuckGo search: $($_.Exception.Message)"
    }
}

function Parse-SearchResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Html,
        [int]$MaxResults = 10
    )
    
    try {
        # Load HTML content
        $htmlDoc = New-Object -ComObject "HTMLFile"
        
        # Method depends on PowerShell version
        try {
            # For PowerShell 7
            $htmlDoc.write([System.Text.Encoding]::Unicode.GetBytes($Html))
        }
        catch {
            # For older PowerShell versions
            $htmlDoc.IHTMLDocument2_write($Html)
        }
        
        $results = @()
        $resultElements = $htmlDoc.getElementsByClassName("result")
        $wikipediaResults = @()
        $otherResults = @()
        
        foreach ($result in $resultElements) {
            $titleElement = $null
            $linkElement = $null
            $snippetElement = $null
            
            # Find title element
            $titleElements = $result.getElementsByClassName("result__title")
            if ($titleElements.length -gt 0) {
                $titleElement = $titleElements.item(0)
                $linkElements = $titleElement.getElementsByTagName("a")
                
                if ($linkElements.length -gt 0) {
                    $linkElement = $linkElements.item(0)
                }
            }
            
            # Find snippet element
            $snippetElements = $result.getElementsByClassName("result__snippet")
            if ($snippetElements.length -gt 0) {
                $snippetElement = $snippetElements.item(0)
            }
            
            if ($titleElement -and $linkElement) {
                $title = $titleElement.innerText.Trim()
                $link = $linkElement.getAttribute("href")
                $snippet = if ($snippetElement) { $snippetElement.innerText.Trim() } else { "" }
                
                # Skip ad results
                if ($link -match "y\.js") {
                    continue
                }
                
                # Clean up DuckDuckGo redirect URLs
                if ($link -match "//duckduckgo\.com/l/\?uddg=") {
                    $encodedUrl = $link -replace ".*uddg=([^&]*).*", '$1'
                    $link = [System.Web.HttpUtility]::UrlDecode($encodedUrl)
                }
                
                $resultObject = [PSCustomObject]@{
                    Title = $title
                    Link = $link
                    Snippet = $snippet
                    Position = 0  # Will be set later
                }
                
                # Separate Wikipedia results from other results
                if ($link -match "wikipedia\.org") {
                    $wikipediaResults += $resultObject
                } else {
                    $otherResults += $resultObject
                }
            }
        }
        
        # Combine results with Wikipedia results first
        $combinedResults = $wikipediaResults + $otherResults
        
        # Set positions and limit to MaxResults
        for ($i = 0; $i -lt [Math]::Min($combinedResults.Count, $MaxResults); $i++) {
            $combinedResults[$i].Position = $i + 1
        }
        
        return $combinedResults | Select-Object -First $MaxResults
    }
    catch {
        Write-Error "Error parsing search results: $($_.Exception.Message)"
        return @()
    }
}


function Format-SearchResultsForLLM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )
    
    if (-not $Results -or $Results.Count -eq 0) {
        return "No results were found for your search query. This could be due to DuckDuckGo's bot detection or the query returned no matches. Please try rephrasing your search or try again in a few minutes."
    }
    
    $output = @()
    $output += "Found $($Results.Count) search results:`n"
    
    foreach ($result in $Results) {
        $output += "$($result.Position). $($result.Title)"
        $output += "   URL: $($result.Link)"
        $output += "   Summary: $($result.Snippet)"
        $output += ""  # Empty line between results
    }
    
    return $output -join "`n"
}

function Invoke-WebContentFetch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        [int]$PageNumber = 0,
        [int]$TotalPages = 1,
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )
    
    try {
        # Check if cancellation was requested
        if ($CancellationToken.IsCancellationRequested) {
            Write-Host "[CANCELLED] Content fetch cancelled for: $Url"
            return "Content fetch cancelled due to search timeout"
        }    
        
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
            "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
            "Accept-Language" = "en-US,en;q=0.5"
            "Accept-Encoding" = "gzip, deflate, br"
            "Connection" = "keep-alive"
            "Upgrade-Insecure-Requests" = "1"
            "Cache-Control" = "max-age=0"
            # Add cookie consent header
            "Cookie" = "cookieconsent_status=dismiss; euconsent=accepted"
        }
                
        # Create a WebSession with our cookie container
        $webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $webSession.Cookies = $Global:CookieContainer
        if ($DEBUG_CONFIG.LogRequests) {
            Write-Host "[DEBUG] Fetching content from: $Url"
        }
        
        # Show progress if enabled
        if ($SEARCH_CONFIG.ShowProgress) {
            $progressParams = @{
                Activity = "Fetching web content"
                Status = "Page $($PageNumber+1) of $TotalPages - $Url"
                PercentComplete = [math]::Min(100, [math]::Max(0, ($PageNumber / $TotalPages) * 100))
            }
            Write-Progress @progressParams
        }
        
        # Skip PDF files and other non-HTML content
        if ($Url -match '\.(pdf|doc|docx|ppt|pptx|xls|xlsx)$') {
            $fileType = $Matches[1].ToUpper()
            Write-Host "[INFO] Skipping $fileType file: $Url"
            return "Content skipped: File type not supported for extraction ($Url)"
        }
        
        # Use try-catch for the web request to handle various errors
        try {
            # Add a delay to avoid rate limiting
            Start-Sleep -Milliseconds (Get-Random -Minimum 500 -Maximum 2000)
            
            # Special handling for Wikipedia and other sites with SSL issues
            if ($Url -match "wikipedia\.org") {
                Write-Host "[INFO] Using alternative method for Wikipedia content"
                
                # Force TLS 1.2 and disable certificate validation for Wikipedia
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                
                # Create a callback to bypass SSL certificate validation
                $certCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
                
                try {
                    # Use Invoke-ProcessWithTimeout to enforce a 30-second timeout for this specific request
                    $scriptBlock = {
                        param($Url, $Headers, $WebSession)
                        Invoke-WebRequest -Uri $Url -Headers $Headers -UseBasicParsing -WebSession $WebSession
                    }
                    
                    $wikiResponse = Invoke-WebRequestWithTimeout -Uri $Url -Headers $headers -UseBasicParsing -TimeoutSeconds 30
                    if ($wikiResponse.StatusCode -eq 200) {
                        # Extract text from HTML content
                        $html = $wikiResponse.Content
                        $text = Extract-TextFromHtml -Html $html
                        
                        # Clean the content before truncating
                        $text = Clean-WebContent -Content $text -Url $Url
                        
                        # Truncate if too long
                        if ($text.Length -gt 24000) {
                            $text = $text.Substring(0, 24000) + "... [content truncated]"
                        }
                        
                        Write-Host "[INFO] Successfully retrieved Wikipedia content using relaxed SSL validation"
                        return $text
                    }
                }
                catch [System.Management.Automation.RuntimeException] {
                    if ($_.Exception.Message -match "timeout") {
                        Write-Host "[WARNING] Wikipedia request timed out after 30 seconds: $Url"
                        return "Content skipped: Request timed out after 30 seconds"
                    }
                    Write-Host "[WARNING] Wikipedia access with relaxed SSL failed: $($_.Exception.Message)"
                }
                finally {
                    # Restore the original certificate validation callback
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $certCallback
                }
                
                # If we get here, all methods failed
                return "Content skipped: All Wikipedia access methods failed - Unable to bypass SSL validation"
            }
            
            # Normal handling for other sites
            $response = $null
            $accessBlocked = $false
            
            try {
                # Use Invoke-ProcessWithTimeout to enforce a 30-second timeout for this specific request
                $scriptBlock = {
                    param($Url, $Headers, $WebSession)
                    Invoke-WebRequest -Uri $Url -Headers $Headers -MaximumRedirection 10 -WebSession $WebSession
                }
                
                $response = Invoke-WebRequestWithTimeout -Uri $Url -Headers $headers -MaximumRedirection 10 -TimeoutSeconds 30
            }
            catch [System.Management.Automation.RuntimeException] {
                if ($_.Exception.Message -match "timeout") {
                    Write-Host "[WARNING] Request timed out after 30 seconds: $Url"
                    return "Content skipped: Request timed out after 30 seconds"
                }
                
                $errorMessage = $_.Exception.Message
                
                # Check if access is blocked (403 Forbidden)
                if ($errorMessage -match "403" -or $errorMessage -match "forbidden" -or 
                    $errorMessage -match "400" -or $errorMessage -match "Bad Request") {
                    $accessBlocked = $true
                    Write-Host "[INFO] Direct access blocked for: $Url - Trying archive services"
                }
                else {
                    # Re-throw other errors to be handled by the outer catch block
                    throw
                }
            }
            
            # If direct access is successful
            if ($response -and $response.StatusCode -eq 200) {
                # Only process HTML content
                if ($response.Headers["Content-Type"] -match "text/html") {
                # Extract text content from HTML
                $html = $response.Content
                $text = Extract-TextFromHtml -Html $html
                
                # Clean the content before truncating
                $text = Clean-WebContent -Content $text -Url $Url
                
                # Truncate if too long
                if ($text.Length -gt 24000) {
                    $text = $text.Substring(0, 24000) + "... [content truncated]"
                }
                    
                    return $text
                } else {
                    $contentType = $response.Headers["Content-Type"]
                    Write-Host "[INFO] Skipping non-HTML content ($contentType): $Url"
                    return "Content skipped: Not HTML content - $contentType ($Url)"
                }
            }
            
            # If direct access is blocked or failed, try archive services
            if ($accessBlocked -or -not $response) {
                # Try Wayback Machine (Internet Archive)
                Write-Host "[INFO] Trying Internet Archive for: $Url"
                $waybackUrl = "https://web.archive.org/web/2/" + $Url
                
                try {
                    # Use Invoke-ProcessWithTimeout to enforce a 30-second timeout for archive requests
                    $scriptBlock = {
                        param($Url, $Headers, $WebSession)
                        Invoke-WebRequest -Uri $Url -Headers $Headers -MaximumRedirection 10 -WebSession $WebSession
                    }
                    
                    $archiveResponse = Invoke-WebRequestWithTimeout -Uri $waybackUrl -Headers $headers -MaximumRedirection 10 -TimeoutSeconds 30
                    
                    if ($archiveResponse.StatusCode -eq 200) {
                        # Extract text content from HTML
                        $html = $archiveResponse.Content
                        $text = Extract-TextFromHtml -Html $html
                        
                        # Clean the content before truncating
                        $text = Clean-WebContent -Content $text -Url $Url
                        
                        # Truncate if too long
                        if ($text.Length -gt 24000) {
                            $text = $text.Substring(0, 24000) + "... [content truncated]"
                        }
                        
                        Write-Host "[INFO] Successfully retrieved content from Internet Archive"
                        return "ARCHIVED CONTENT from Internet Archive:`n$text"
                    }
                }
                catch [System.Management.Automation.RuntimeException] {
                    if ($_.Exception.Message -match "timeout") {
                        Write-Host "[WARNING] Internet Archive request timed out after 30 seconds: $Url"
                    } else {
                        Write-Host "[INFO] Internet Archive access failed: $($_.Exception.Message)"
                    }
                }
                
                # Try archive.today as a fallback
                Write-Host "[INFO] Trying archive.today for: $Url"
                $archiveTodayUrl = "https://archive.ph/newest/" + $Url
                
                try {
                    # Use Invoke-ProcessWithTimeout to enforce a 30-second timeout for archive requests
                    $scriptBlock = {
                        param($Url, $Headers, $WebSession)
                        Invoke-WebRequest -Uri $Url -Headers $Headers -MaximumRedirection 10 -WebSession $WebSession
                    }
                    
                    $archiveTodayResponse = Invoke-WebRequestWithTimeout -Uri $archiveTodayUrl -Headers $headers -MaximumRedirection 10 -TimeoutSeconds 30
                    
                    if ($archiveTodayResponse.StatusCode -eq 200) {
                        # Extract text content from HTML
                        $html = $archiveTodayResponse.Content
                        $text = Extract-TextFromHtml -Html $html
                        
                        # Clean the content before truncating
                        $text = Clean-WebContent -Content $text -Url $Url
                        
                        # Truncate if too long
                        if ($text.Length -gt 24000) {
                            $text = $text.Substring(0, 24000) + "... [content truncated]"
                        }
                        
                        Write-Host "[INFO] Successfully retrieved content from archive.today"
                        return "ARCHIVED CONTENT from archive.today:`n$text"
                    }
                }
                catch [System.Management.Automation.RuntimeException] {
                    if ($_.Exception.Message -match "timeout") {
                        Write-Host "[WARNING] archive.today request timed out after 30 seconds: $Url"
                    } else {
                        Write-Host "[INFO] archive.today access failed: $($_.Exception.Message)"
                    }
                }
                
                # Try Google Cache as a last resort
                Write-Host "[INFO] Trying Google Cache for: $Url"
                $googleCacheUrl = "https://webcache.googleusercontent.com/search?q=cache:" + $Url
                
                try {
                    # Use Invoke-ProcessWithTimeout to enforce a 30-second timeout for archive requests
                    $scriptBlock = {
                        param($Url, $Headers, $WebSession)
                        Invoke-WebRequest -Uri $Url -Headers $Headers -MaximumRedirection 10 -WebSession $WebSession
                    }
                    
                    $googleCacheResponse = Invoke-WebRequestWithTimeout -Uri $googleCacheUrl -Headers $headers -MaximumRedirection 10 -TimeoutSeconds 30
                    
                    if ($googleCacheResponse.StatusCode -eq 200) {
                        # Extract text content from HTML
                        $html = $googleCacheResponse.Content
                        $text = Extract-TextFromHtml -Html $html
                        
                        # Clean the content before truncating
                        $text = Clean-WebContent -Content $text -Url $Url
                        
                        # Truncate if too long
                        if ($text.Length -gt 24000) {
                            $text = $text.Substring(0, 24000) + "... [content truncated]"
                        }
                        
                        Write-Host "[INFO] Successfully retrieved content from Google Cache"
                        return "ARCHIVED CONTENT from Google Cache:`n$text"
                    }
                }
                catch [System.Management.Automation.RuntimeException] {
                    if ($_.Exception.Message -match "timeout") {
                        Write-Host "[WARNING] Google Cache request timed out after 30 seconds: $Url"
                    } else {
                        Write-Host "[INFO] Google Cache access failed: $($_.Exception.Message)"
                    }
                }
                
                # If all archive services fail, try to extract metadata from the URL
                if ($Url -match "researchgate\.net/publication/(\d+)_(.+)") {
                    $pubId = $Matches[1]
                    $title = $Matches[2] -replace '_', ' '
                    
                    Write-Host "[INFO] Extracting metadata from ResearchGate URL"
                    return "METADATA EXTRACTION:`nTitle: $title`nPublication ID: $pubId`nSource: ResearchGate"
                }
                elseif ($Url -match "sciencedirect\.com/science/article/(?:pii|abs/pii)/([A-Z0-9]+)") {
                    $pii = $Matches[1]
                    
                    Write-Host "[INFO] Extracting metadata from ScienceDirect URL"
                    return "METADATA EXTRACTION:`nPII: $pii`nSource: ScienceDirect"
                }
                elseif ($Url -match "ieeexplore\.ieee\.org/(?:document|abstract/document)/(\d+)") {
                    $docId = $Matches[1]
                    
                    Write-Host "[INFO] Extracting metadata from IEEE URL"
                    return "METADATA EXTRACTION:`nDocument ID: $docId`nSource: IEEE Xplore"
                }
                
                # If all methods fail
                return "Content skipped: Access blocked and all archive services failed - $Url"
            }
        } catch {
            $errorMessage = $_.Exception.Message
            
            # Provide more specific error messages for common issues
            if ($errorMessage -match "403") {
                Write-Host "[WARNING] Access forbidden (403) for: $Url"
                return "Content skipped: Access forbidden (403) - The website is blocking automated access"
            } elseif ($errorMessage -match "404") {
                Write-Host "[WARNING] Page not found (404) for: $Url"
                return "Content skipped: Page not found (404)"
            } elseif ($errorMessage -match "timeout") {
                Write-Host "[WARNING] Request timed out for: $Url"
                return "Content skipped: Request timed out"
            } elseif ($errorMessage -match "SSL") {
                Write-Host "[WARNING] SSL/TLS error for: $Url"
                return "Content skipped: SSL/TLS connection error"
            } else {
                Write-Host "[WARNING] Error accessing: $Url - $errorMessage"
                return "Content skipped: Error accessing content - $errorMessage"
            }
        }
    }
    catch {
        Write-Error "Content Fetch Error: $($_.Exception.Message)"
        return "Error fetching content: $($_.Exception.Message)"
    }
    finally {
        if ($SEARCH_CONFIG.ShowProgress) {
            Write-Progress -Activity "Fetching web content" -Completed
        }
    }
}

function Extract-TextFromHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Html
    )
    
    try {
        # Load HTML content
        $htmlDoc = New-Object -ComObject "HTMLFile"
        
        # Method depends on PowerShell version
        try {
            # For PowerShell 7
            $htmlDoc.write([System.Text.Encoding]::Unicode.GetBytes($Html))
        }
        catch {
            # For older PowerShell versions
            $htmlDoc.IHTMLDocument2_write($Html)
        }
        
        # Extract text from body
        $body = $htmlDoc.body
        if ($body) {
            # Get all text nodes
            $text = $body.innerText
            
            # Clean up the text
            $text = $text -replace '\r\n', "`n"
            $text = $text -replace '\n{3,}', "`n`n"
            
            return $text
        }
        
        return "No content could be extracted from HTML"
    }
    catch {
        Write-Error "Error extracting text from HTML: $($_.Exception.Message)"
        return "Error extracting text from HTML: $($_.Exception.Message)"
    }
}

function Invoke-SummarizationRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        [Parameter(Mandatory)]
        [string]$BaseName,
        [bool]$IsIntermediate = $false
    )
    
    try {
        # Calculate approximate token count (rough estimate: 4 chars = 1 token)
        $estimatedTokens = [Math]::Ceiling($Prompt.Length / 4)
        # Use configurable token limits
        $maxOutputTokens = $TOKEN_CONFIG.MaxTokens
        
        # Add validation to ensure token count is appropriate
        if ($estimatedTokens -lt $TOKEN_CONFIG.MinTokenThreshold -and $IsIntermediate) {
            Write-Warning "Input tokens during summary can be greater than $($TOKEN_CONFIG.MinTokenThreshold) but need to be less than $($TOKEN_CONFIG.MaxTokenThreshold). Current estimated input tokens: $estimatedTokens is too small."
        }
        
        Write-Host "[INFO] Estimated input tokens: $estimatedTokens, Max output tokens: $maxOutputTokens"
        
        # System message for summarization
        $systemMessage = "You are a scientific research assistant tasked with summarizing technical content. Prioritize mathematical accuracy, preserve all formulas in LaTeX format, maintain scientific rigor, and ensure all technical principles are explained with their mathematical foundations. Never simplify or omit mathematical details."
        
        # Use the configured LLM provider instead of hardcoding LM Studio
        $result = Invoke-LLMRequest -UserPrompt $Prompt -BaseName $BaseName -SystemMessage $systemMessage -Temperature 0.2 -MaxTokens $maxOutputTokens
        
        if ($IsIntermediate) {
            Write-Host "[INFO] Intermediate summary generated successfully."
        } else {
            Write-Host "[SUMMARY] Search summary generated successfully."
        }
        
        return $result
    }
    catch {
        Write-Error "Error in summarization: $($_.Exception.Message)"
        return "Error generating summary: $($_.Exception.Message)"
    }
}

function Get-SearchSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseName,
        [string]$SearchResults,
        [string[]]$ContentDetails
    )
    
    try {
        Write-Host "[SUMMARY] Generating search summary for $BaseName using $($env:LLM_PROVIDER)..."
        
        # Check if we have any useful content
        $validContentCount = ($ContentDetails | Where-Object { $_ -notmatch "Content skipped:" }).Count
        
        if ($validContentCount -eq 0) {
            Write-Host "[WARNING] No valid content was retrieved from any of the search results"
            $summaryPrompt = @"
Please create a comprehensive scientific summary about "$BaseName" based on the following search results:

$SearchResults

Note: We were unable to retrieve detailed content from the search results due to access restrictions.
Please use your knowledge to provide the most accurate scientific information about $BaseName.

Create a comprehensive summary that includes:
1. Key concepts and precise mathematical definitions
2. Important technical specifications with exact values and units
3. Fundamental equations and mathematical models that describe the topic
4. Theoretical principles and their mathematical representations
5. Current research directions with quantitative methodologies

Maintain scientific rigor by:
- Preserving all mathematical formulas in proper notation
- Including statistical measures and confidence intervals where applicable
- Providing exact parameter definitions and their relationships
- Using precise technical terminology without simplification
- Citing specific methodologies with their mathematical foundations

Keep the summary concise but scientifically accurate, focusing on the most relevant technical information.
"@
            # Call the configured LLM provider with just the search results
            return Invoke-SummarizationRequest -Prompt $summaryPrompt -BaseName $BaseName
        } else {
            Write-Host "[INFO] Retrieved valid content from $validContentCount sources"
            
            
            # Process content in chunks to avoid exceeding API limits
            # Use configurable chunk size from TOKEN_CONFIG
            $maxChunkSize = $TOKEN_CONFIG.MaxChunkSize
            $chunks = @()
            $currentChunk = ""
            $chunkCounter = 1
            
            # First add search results as initial context
            $currentChunk = "SEARCH RESULTS:`n$SearchResults`n`n"
            
            # Process each content item
            foreach ($content in $ContentDetails) {
                # Skip empty content
                if ([string]::IsNullOrWhiteSpace($content)) { continue }
                
                # If content is too large on its own, truncate it
                if ($content.Length -gt $maxChunkSize) {
                    $truncatedContent = $content.Substring(0, $maxChunkSize) + "... [content truncated]"
                    
                    # If current chunk would exceed limit, save it and start a new one
                    if (($currentChunk.Length + $truncatedContent.Length) -gt $maxChunkSize) {
                        $chunks += $currentChunk
                        $currentChunk = "CONTENT CHUNK $chunkCounter (continued):`n$truncatedContent`n`n"
                        $chunkCounter++
                    } else {
                        $currentChunk += "CONTENT ITEM:`n$truncatedContent`n`n"
                    }
                } else {
                    # If adding this content would exceed chunk size, save current chunk and start new one
                    if (($currentChunk.Length + $content.Length) -gt $maxChunkSize) {
                        $chunks += $currentChunk
                        $currentChunk = "CONTENT CHUNK $chunkCounter (continued):`n$content`n`n"
                        $chunkCounter++
                    } else {
                        $currentChunk += "CONTENT ITEM:`n$content`n`n"
                    }
                }
            }
            
            # Add the last chunk if not empty
            if ($currentChunk.Length -gt 0) {
                $chunks += $currentChunk
            }
            
            Write-Host "[INFO] Content split into $($chunks.Count) chunks for processing"
            
            # Process each chunk and collect intermediate summaries
            $intermediateSummaries = @()
            for ($i = 0; $i -lt $chunks.Count; $i++) {
                Write-Host "[SUMMARY] Processing content chunk $($i+1) of $($chunks.Count)..."
                
                $chunkPrompt = @"
Please analyze and summarize the following content about "$BaseName":

$($chunks[$i])

Create a focused summary of just this content chunk that includes:
1. Key facts and concepts
2. Technical specifications with values and units
3. Any mathematical formulas or models mentioned
4. Important methodologies or principles

Keep the summary concise but retain all technical details and mathematical precision.
"@
                
                $chunkSummary = Invoke-SummarizationRequest -Prompt $chunkPrompt -BaseName "$($BaseName)_chunk$($i+1)" -IsIntermediate $true
                if ($chunkSummary -match "Error|Unable to generate") {
                    Write-Warning "Failed to summarize chunk $($i+1). Using truncated version instead."
                    # If summarization fails, use a truncated version of the chunk
                    $chunkSummary = "CHUNK $($i+1) CONTENT (truncated):`n" + $chunks[$i].Substring(0, [Math]::Min(3000, $chunks[$i].Length))
                }
                
                $intermediateSummaries += $chunkSummary
            }
            
            # Final summarization of all intermediate summaries
            $finalPrompt = @"
Please create a comprehensive scientific summary about "$BaseName" based on the following information:

SEARCH RESULTS:
$SearchResults

CONTENT SUMMARIES:
$($intermediateSummaries -join "`n`n")

Create a comprehensive scientific summary that includes:
1. Key concepts and precise mathematical definitions
2. Important technical specifications with exact values and units
3. Fundamental equations and mathematical models that describe the topic
4. Theoretical principles and their mathematical representations
5. Current research directions with quantitative methodologies

Maintain scientific rigor by:
- Preserving all mathematical formulas in proper notation (using LaTeX format)
- Including statistical measures and confidence intervals where applicable
- Providing exact parameter definitions and their relationships
- Using precise technical terminology without simplification
- Citing specific methodologies with their mathematical foundations

Keep the summary concise but scientifically accurate, focusing on the most relevant technical information.
"@
            
            Write-Host "[SUMMARY] Generating final summary from $($intermediateSummaries.Count) intermediate summaries..."
            return Invoke-SummarizationRequest -Prompt $finalPrompt -BaseName $BaseName
        }
    }
    catch {
        Write-Error "Error generating search summary: $($_.Exception.Message)"
        return "Error generating summary: $($_.Exception.Message)"
    }
}

function Clean-WebContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content,
        [string]$Url
    )
    
    try {
        # Skip if content is empty or already a "Content skipped" message
        if ([string]::IsNullOrWhiteSpace($Content) -or $Content -match "^Content skipped:") {
            return $Content
        }
        
        # Common markers that indicate the end of main content across websites
        $endMarkers = @(
            "Cite this page",
            "Contact us",
            "Page information",
            "Login",
            "Log in",
            "Create account",
            "Sign in",
            "Sign up"
        )
        
        # Process content line by line
        $lines = $Content -split "`n"
        $cleanedLines = New-Object System.Collections.ArrayList
        $foundEndMarker = $false
        $startIndex = -1
        
        # First check if "Retrieved from" exists and remove everything after it
        $retrievedFromIndex = $lines.IndexOf(($lines | Where-Object { $_ -match "Retrieved from" } | Select-Object -First 1))
        if ($retrievedFromIndex -ge 0) {
            $lines = $lines[0..($retrievedFromIndex-1)]
        }
        
        # Find the first occurrence of any end marker
        foreach ($marker in $endMarkers) {
            # Try exact match first
            $markerIndex = $lines.IndexOf(($lines | Where-Object { $_.Trim() -eq $marker } | Select-Object -First 1))
            
            if ($markerIndex -ge 0) {
                $foundEndMarker = $true
                $startIndex = $markerIndex + 1  # Start after the marker
                break
            }
            
            # If no exact match, try case-insensitive match
            $markerIndex = $lines.IndexOf(($lines | Where-Object { $_.Trim() -ieq $marker } | Select-Object -First 1))
            
            if ($markerIndex -ge 0) {
                $foundEndMarker = $true
                $startIndex = $markerIndex + 1  # Start after the marker
                break
            }
        }
        
        # If no marker found with exact match, try regex match
        if (-not $foundEndMarker) {
            foreach ($marker in $endMarkers) {
                $markerIndex = $lines.IndexOf(($lines | Where-Object { $_.Trim() -match "^$([regex]::Escape($marker))\s*$" } | Select-Object -First 1))
                
                if ($markerIndex -ge 0) {
                    $foundEndMarker = $true
                    $startIndex = $markerIndex + 1  # Start after the marker
                    break
                }
            }
        }
        
        # If we found a marker, keep only content after it
        if ($foundEndMarker -and $startIndex -gt 0 -and $startIndex -lt $lines.Count) {
            $cleanedContent = $lines[$startIndex..($lines.Count-1)] -join "`n"
        } else {
            # If no marker found, return the original content
            $cleanedContent = $lines -join "`n"
        }
        
        # Remove excessive whitespace
        $cleanedContent = $cleanedContent -replace '\r\n\s*\r\n', "`n`n" -replace '\s{3,}', "`n" -replace '^\s+|\s+$', ''
        
        return $cleanedContent
    }
    catch {
        Write-Error "Error cleaning web content: $($_.Exception.Message)"
        return $Content  # Return original content if cleaning fails
    }
}

function Invoke-LMStudioSummarization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        [Parameter(Mandatory)]
        [string]$BaseName,
        [bool]$IsIntermediate = $false
    )
    
    try {
        # Calculate approximate token count (rough estimate: 4 chars = 1 token)
        $estimatedTokens = [Math]::Ceiling($Prompt.Length / 4)
        # Use configurable token limits
        $maxOutputTokens = $TOKEN_CONFIG.MaxTokens
        
        # Add validation to ensure token count is appropriate
        if ($estimatedTokens -lt $TOKEN_CONFIG.MinTokenThreshold -and $IsIntermediate) {
            Write-Warning "Input tokens during summary can be greater than $($TOKEN_CONFIG.MinTokenThreshold) but need to be less than $($TOKEN_CONFIG.MaxTokenThreshold). current Estimated input tokens: $estimatedTokens is too small."
        }
        
        Write-Host "[INFO] Estimated input tokens: $estimatedTokens, Max output tokens: $maxOutputTokens"
        
        # Call LM Studio to generate the summary
        $headers = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $($env:LMSTUDIO_API_KEY)"
        }

        $body = @{
            model       = $LMSTUDIO_CONFIG.Model
            messages    = @(
                @{ 
                    role = "system"
                    content = "You are a scientific research assistant tasked with summarizing technical content. Prioritize mathematical accuracy, preserve all formulas in LaTeX format, maintain scientific rigor, and ensure all technical principles are explained with their mathematical foundations. Never simplify or omit mathematical details."
                }
                @{ role = "user"; content = $Prompt }
            )
            temperature = 0.2  # Lower temperature for more precise, factual responses
            max_tokens  = $maxOutputTokens
        }

        try {
            # Add retry logic for API calls
            $maxRetries = 3
            $retryCount = 0
            $success = $false
            $response = $null
            
            while (-not $success -and $retryCount -lt $maxRetries) {
                try {
                    $response = Invoke-RestMethod -Uri $LMSTUDIO_CONFIG.BaseURL `
                        -Method Post `
                        -Headers $headers `
                        -Body ($body | ConvertTo-Json -Depth 10) `
                        -TimeoutSec 300  # 5 minutes timeout
                    
                    $success = $true
                }
                catch {
                    $retryCount++
                    $errorMsg = $_.Exception.Message
                    
                    if ($retryCount -ge $maxRetries) {
                        throw "API call failed after $maxRetries attempts: $errorMsg"
                    }
                    
                    # Calculate backoff time (exponential with jitter)
                    $backoffSeconds = [Math]::Pow(2, $retryCount) + (Get-Random -Minimum 1 -Maximum 5)
                    Write-Warning "API call attempt $retryCount failed: $errorMsg. Retrying in $backoffSeconds seconds..."
                    Start-Sleep -Seconds $backoffSeconds
                }
            }

            if (-not $response.choices -or -not $response.choices[0].message.content) {
                throw "Invalid or empty response from LM Studio"
            }

            if ($IsIntermediate) {
                Write-Host "[INFO] Intermediate summary generated successfully."
            } else {
                Write-Host "[SUMMARY] Search summary generated successfully."
            }
            
            return $response.choices[0].message.content
        } catch {
            Write-Warning "API call failed: $($_.Exception.Message)"
            return "Unable to generate summary due to API error: $($_.Exception.Message)"
        }
    }
    catch {
        Write-Error "Error in LM Studio summarization: $($_.Exception.Message)"
        return "Error generating summary: $($_.Exception.Message)"
    }
}

function Fix-MermaidFormatting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    try {
        # Skip if file doesn't exist
        if (-not (Test-Path $FilePath)) {
            Write-Warning "File not found: $FilePath"
            return $false
        }
        
        # Read file content
        $content = Get-Content -Path $FilePath -Encoding UTF8
        
        # Check if this is a blank MD file (just a header matching filename)
        $nonEmptyLines = $content | Where-Object { $_ -match '\S' }
        if ($nonEmptyLines.Count -eq 1) {
            $headerLine = $nonEmptyLines[0]
            if ($headerLine -match '^#\s+(.+)$') {
                $headerText = $Matches[1].Trim()
                $fileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
                
                # Normalize both strings for comparison (similar to Python's process_string)
                $normalizedHeader = ($headerText -replace '-', ' ' -replace '[^a-zA-Z\s]', '' -replace '\s+', ' ').Trim()
                $normalizedFileName = ($fileName -replace '-', ' ' -replace '[^a-zA-Z\s]', '' -replace '\s+', ' ').Trim()
                
                if ($normalizedHeader -eq $normalizedFileName) {
                    Write-Host "Skipping blank MD file: $FilePath"
                    return $true
                }
            }
        }
        
        # Process Mermaid blocks
        $insertions = @()
        $inMermaid = $false
        $lastArrowLine = -1
        
        for ($idx = 0; $idx -lt $content.Count; $idx++) {
            $line = $content[$idx]
            $stripped = $line.Trim()
            
            if ($stripped -eq '```mermaid') {
                $inMermaid = $true
                $lastArrowLine = -1
            }
            elseif ($inMermaid) {
                if ($line -match '-->') {
                    $lastArrowLine = $idx
                }
                
                if ($stripped -eq '```') {
                    # Process closure for properly closed blocks
                    if ($lastArrowLine -ne -1) {
                        $nextLineIdx = $lastArrowLine + 1
                        if ($nextLineIdx -ge $content.Count -or $content[$nextLineIdx].Trim() -ne '```') {
                            $insertions += @{Position = $lastArrowLine + 1; Line = "``````" }
                        }
                    }
                    $inMermaid = $false
                    $lastArrowLine = -1
                }
            }
        }
        
        # Handle unclosed Mermaid blocks after full file scan
        if ($inMermaid -and $lastArrowLine -ne -1) {
            $nextLineIdx = $lastArrowLine + 1
            if ($nextLineIdx -ge $content.Count -or $content[$nextLineIdx].Trim() -ne '```') {
                $insertions += @{Position = $lastArrowLine + 1; Line = "``````" }
            }
        }
        
        # If we have insertions, apply them and save the file
        if ($insertions.Count -gt 0) {
            Write-Host "Fixing $($insertions.Count) Mermaid formatting issues in: $FilePath"
            
            # Apply insertions in reverse order to maintain correct indices
            $insertions = $insertions | Sort-Object -Property Position -Descending
            
            foreach ($insertion in $insertions) {
                $content = $content[0..($insertion.Position-1)] + 
                           $insertion.Line + 
                           $content[$insertion.Position..($content.Count-1)]
            }
            
            # Save the file
            $content | Out-File -FilePath $FilePath -Encoding UTF8
            return $true
        }
        
        return $true
    }
    catch {
        Write-Error "Error fixing Mermaid formatting in $FilePath`: $($_.Exception.Message)"
        return $false
    }
}

function Process-MermaidInMarkdownFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Directory = "."
    )
    
    try {
        if (-not (Test-Path -Path $Directory -PathType Container)) {
            Write-Error "Directory does not exist: $Directory"
            return
        }
        
        $mdFiles = Get-ChildItem -Path $Directory -Filter "*.md" -File
        
        if ($mdFiles.Count -eq 0) {
            Write-Host "No markdown files found in directory: $Directory"
            return
        }
        
        Write-Host "Processing $($mdFiles.Count) markdown files for Mermaid formatting..."
        
        foreach ($file in $mdFiles) {
            Fix-MermaidFormatting -FilePath $file.FullName
        }
        
        Write-Host "Mermaid formatting check complete."
    }
    catch {
        Write-Error "Error processing Mermaid in markdown files: $($_.Exception.Message)"
    }
}


function Move-ProcessedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,
        [string]$DestinationPath = $env:OUTPUT_DESTINATION_PATH
    )

    # If destination path is empty, don't move the file
    if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
        Write-Host "[MOVE] No destination path specified. File will remain in current directory."
        return $true
    }

    try {
        # Ensure destination directory exists
        if (-not (Test-Path -Path $DestinationPath -PathType Container)) {
            Write-Host "[MOVE] Creating destination directory: $DestinationPath"
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        }

        # Construct destination file path
        $destinationFile = Join-Path -Path $DestinationPath -ChildPath $File.Name

        # Check if file already exists at destination
        if (Test-Path -Path $destinationFile) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $newFileName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name) + 
                           "_$timestamp" + 
                           [System.IO.Path]::GetExtension($File.Name)
            $destinationFile = Join-Path -Path $DestinationPath -ChildPath $newFileName
            Write-Host "[MOVE] File already exists at destination. Renaming to: $newFileName"
        }

        # Move the file only if OUTPUT_MOVE_PROCESSED is true
        if ([System.Convert]::ToBoolean($env:OUTPUT_MOVE_PROCESSED ?? "true")) {
            Move-Item -Path $File.FullName -Destination $destinationFile -Force
            Write-Host "[MOVE] Successfully moved $($File.Name) to $DestinationPath"
        } else {
            Copy-Item -Path $File.FullName -Destination $destinationFile -Force
            Write-Host "[COPY] Successfully copied $($File.Name) to $DestinationPath"
        }
        return $true
    }
    catch {
        Write-Warning "Failed to move file $($File.Name): $($_.Exception.Message)"
        return $false
    }
}

# Main script execution
try {
    # Load configuration from .env file
    Write-Host "Loading configuration from .env"
    Import-DotEnv
    
    # Initialize cookie container for web requests
    $Global:CookieContainer = New-Object System.Net.CookieContainer
    Write-Host "[INFO] Cookie container initialized for handling consent popups"
    
    # Verify API connectivity
    Write-Host "Running API connectivity tests..."
    $apiConnected = Test-LLMConnection
    
    if (-not $apiConnected) {
        Write-Error "API connection failed. Check:`n1. API key validity`n2. Network connectivity`n3. Base URL: $($ACTIVE_LLM.BaseURL)"
        exit 1
    }
    
    # Calculate delay in seconds
    $delaySeconds = [math]::Round($SCHEDULE_CONFIG.StartDelayHours * 3600)
    if ($delaySeconds -gt 0) {
        Write-Host "Delaying start for $($SCHEDULE_CONFIG.StartDelayHours) hours..."
        Start-CountdownTimer -Seconds $delaySeconds -Message "Scheduled Delay"
    }
    
    $isFirstCycle = $true
    $cycleCount = 0
    $maxCycles = 1000 # Safety limit
    
    while ($cycleCount -lt $maxCycles) {
        $cycleCount++
        $files = Get-ValidMarkdownFiles
        if (-not $files) {
            Write-Host "All files processed successfully."
            break
        }
        
        $currentTimeout = if ($isFirstCycle) { $SCHEDULE_CONFIG.TimeoutHours } else { 8 }
        $isFirstCycle = $false
        
        $cycleStart = Get-Date
        $timeoutDeadline = $cycleStart.AddHours($currentTimeout)
        Write-Host @"
`n[PROCESSING CYCLE $cycleCount]
Start Time:    $($cycleStart.ToString('yyyy-MM-dd HH:mm:ss'))
Timeout After: $currentTimeout hours
Deadline:      $($timeoutDeadline.ToString('yyyy-MM-dd HH:mm:ss'))
Remaining Files: $($files.Count)
"@
        
        foreach ($file in $files) {
            $currentTime = Get-Date
            if ($currentTime -ge $timeoutDeadline) {
                Write-Host "[TIMEOUT] Cycle timeout reached at $($currentTime.ToString('HH:mm:ss'))"
                Write-Host "Suspending operations for 24 hours..."
                Start-CountdownTimer -Seconds (24*3600) -Message "Suspension Period"
                break
            }
            
            $timeRemaining = $timeoutDeadline - $currentTime
            Write-Host "`n[FILE PROCESSING] $($file.Name)"
            Write-Host "Remaining Window: $($timeRemaining.ToString('hh\:mm\:ss'))"
            
            try {
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $safeBaseName = $baseName -replace '[{}£$%^]', ''
                
                # Step 1: Search based on $safeBaseName using DuckDuckGo
                $searchResults = ""
                $contentDetails = @()
                $searchSummary = ""
                
                if ($SEARCH_CONFIG.EnableSearch) {
                    Write-Host "[SEARCH] Performing DuckDuckGo search for: $safeBaseName"
                    $searchQuery = "$safeBaseName technical documentation research papers"
                    $searchResults = Invoke-DuckDuckGoSearch -Query $searchQuery
                    
                    if ($DEBUG_CONFIG.SaveJsonDumps) {
                        $searchResults | Out-File "Search_$safeBaseName.txt"
                    }
                    
                    # Create a cancellation token source for content fetching
                    $cts = New-Object System.Threading.CancellationTokenSource
                    $cts.CancelAfter([TimeSpan]::FromSeconds($SEARCH_CONFIG.SearchTimeout))
                    
                    # Extract top URLs and fetch content with progress display
                    if ($searchResults -match "URL: (https?://[^\s]+)") {
                        $topUrls = [regex]::Matches($searchResults, "URL: (https?://[^\s]+)") | 
                            Select-Object -First $SEARCH_CONFIG.MaxPageSearch | 
                            ForEach-Object { $_.Groups[1].Value }
                        
                        $totalUrls = $topUrls.Count
                        Write-Host "[FETCH] Retrieving content from $totalUrls pages..."
                        
                        for ($i = 0; $i -lt $topUrls.Count; $i++) {
                            # Check if cancellation was requested
                            if ($cts.Token.IsCancellationRequested) {
                                Write-Warning "[TIMEOUT] Search operation timed out after $($SEARCH_CONFIG.SearchTimeout) seconds"
                                break
                            }
                            
                            $url = $topUrls[$i]
                            Write-Host "[FETCH] Page $($i+1)/$($totalUrls): $url"
                            $content = Invoke-WebContentFetch -Url $url -PageNumber $i -TotalPages $totalUrls -CancellationToken $cts.Token
                            
                            if ($content -and $content -notmatch "^Error:" -and $content -notmatch "^Content fetch cancelled") {
                                $contentDetails += "Content from ${url}:`n$content"
                                
                                if ($DEBUG_CONFIG.SaveJsonDumps) {
                                    $content | Out-File "Content_$(([uri]$url).Host)_$safeBaseName.txt"
                                }
                            }
                        }
                    }
                    
                    # Dispose of the cancellation token source
                    $cts.Dispose()
                    
                    # Step 2: Generate a summary of the search results
                    if ($searchResults -and ($contentDetails.Count -gt 0 -or $searchResults -match "timed out")) {
                        $searchSummary = Get-SearchSummary -BaseName $safeBaseName -SearchResults $searchResults -ContentDetails $contentDetails
                        
                        if ($DEBUG_CONFIG.SaveJsonDumps) {
                            $searchSummary | Out-File "Summary_$safeBaseName.txt"
                        }
                    }
                }
                
                # Step 3: Create the final prompt with the search summary
                $prompt = if ($searchSummary) {
                    @"
Create comprehensive technical documentation about $safeBaseName based on the following research summary:

$searchSummary

Include:
1. Detailed explanation of core concepts with their mathematical foundations
2. Key technical specifications with precise values and units
3. Common use cases with quantitative performance metrics
4. Implementation considerations with algorithmic complexity analysis
5. Performance characteristics with statistical measures
6. Related technologies with comparative mathematical models

Follow these requirements:
1. Start with ## Level 2 Header
2. Use tables for specifications and comparisons with exact numerical values
3. Include mathematical equations in LaTeX format and detailed explanations of all parameters and variables. Example:"\$\$
   P(f) = \int_{-\infty}^{\infty} p(t) e^{-i2\pi ft} dt
\$\$"
4. Add mermaid.js diagram code blocks for complex relationships and system architectures
5. Use bullet points for lists longer than 3 items
6. Include references to academic papers with DOI where applicable
7. Preserve all mathematical formulas and scientific principles without simplification
8. Define all variables and parameters used in equations
9. Include statistical measures and confidence intervals where relevant

Format directly for Obsidian without markdown code blocks.
"@
                } else {
                    # Original prompt without search results but with scientific focus
                    @"
Create comprehensive technical documentation about $safeBaseName with a focus on scientific and mathematical rigor. Include:
1. Detailed explanation of core concepts with their mathematical foundations
2. Key technical specifications with precise values and units
3. Common use cases with quantitative performance metrics
4. Implementation considerations with algorithmic complexity analysis
5. Performance characteristics with statistical measures
6. Related technologies with comparative mathematical models

Follow these requirements:
1. Start with ## Level 2 Header
2. Use tables for specifications and comparisons with exact numerical values
3. Include mathematical equations in LaTeX format and detailed explanations of all parameters and variables. Example:"\$\$
   P(f) = \int_{-\infty}^{\infty} p(t) e^{-i2\pi ft} dt
\$\$"
4. Add mermaid.js diagram code blocks for complex relationships and system architectures
5. Use bullet points for lists longer than 3 items
6. Include references to academic papers with DOI where applicable
7. Preserve all mathematical formulas and scientific principles without simplification
8. Define all variables and parameters used in equations
9. Include statistical measures and confidence intervals where relevant

Format directly for Obsidian without markdown code blocks.
"@
                }
                
                Write-Host "[GENERATE] Calling $LLM_PROVIDER to generate final documentation..."
                $responseContent = Invoke-LLMRequest -UserPrompt $prompt -BaseName $safeBaseName
                
                if ($responseContent) {
                    $validationResult = $responseContent | Select-String -Pattern `
                        '^##\s', `
                        '(\bDOI\b|https?://)', `
                        '\bTable\b'
                    
                    if (-not $validationResult) {
                        throw "Generated content failed quality checks"
                    }
                    
                    if (Write-MarkdownContent -File $file -Content $responseContent) {
                        Write-Host "[SUCCESS] Processed $($file.Name)"
                        # Check and fix Mermaid formatting in the file
                        Write-Host "[MERMAID CHECK] Validating Mermaid charts in $($file.Name)..."
                        Fix-MermaidFormatting -FilePath $file.FullName
                        
                        # Move the processed file to the destination directory
                        Move-ProcessedFile -File $file
                        
                        # Clean up temporary files after successful processing
                        if ($DEBUG_CONFIG.SaveJsonDumps) {
                            Write-Host "[CLEANUP] Removing temporary files for $safeBaseName..."
                            
                            # Remove content files
                            Get-ChildItem -Path "Content_*_$safeBaseName.txt" -ErrorAction SilentlyContinue | ForEach-Object {
                                Remove-Item $_.FullName -Force
                                Write-Host "[CLEANUP] Removed $($_.Name)"
                            }
                            
                            # Remove search results file
                            if (Test-Path "Search_$safeBaseName.txt") {
                                Remove-Item "Search_$safeBaseName.txt" -Force
                                Write-Host "[CLEANUP] Removed Search_$safeBaseName.txt"
                            }
                            
                            # Remove summary file
                            if (Test-Path "Summary_$safeBaseName.txt") {
                                Remove-Item "Summary_$safeBaseName.txt" -Force
                                Write-Host "[CLEANUP] Removed Summary_$safeBaseName.txt"
                            }
                        }
                    }
                }
                
                Start-Sleep -Seconds 2
            }
            catch {
                $errorInfo = @{
                    File        = $file.Name
                    Error       = $_.Exception.Message
                    Timestamp   = Get-Date
                }
                
                $errorInfo | ConvertTo-Json -Depth 10 | Out-File "Error_$baseName.json"
                Write-Error "Processing failed for $baseName. Error details logged."
            }
            
            # Post-processing timeout check
            if ((Get-Date) -ge $timeoutDeadline) {
                Write-Host "[TIMEOUT] Post-processing timeout reached"
                Write-Host "Suspending operations for 24 hours..."
                Start-CountdownTimer -Seconds (24*3600) -Message "Suspension Period"
                break
            }
        }
        
        # Check if we exited due to timeout
        if ((Get-Date) -lt $timeoutDeadline) {
            Write-Host "`n[CYCLE COMPLETE] Finished processing all available files within time window"
            break
        }
    }
    
    if ($cycleCount -ge $maxCycles) {
        Write-Warning "Maximum cycle count ($maxCycles) reached. Stopping execution."
    }
    
    Write-Host "`n[FINAL STATUS]"
    Get-ChildItem *.md | Where-Object {
        $_ | Select-String -Pattern "# Generated by $($LLM_PROVIDER) LLM"
    } | ForEach-Object {
        Write-Host "Processed: $($_.Name)"
    }
}
catch {
    Write-Error "Critical error: $($_.Exception.Message)"
    exit 1
}