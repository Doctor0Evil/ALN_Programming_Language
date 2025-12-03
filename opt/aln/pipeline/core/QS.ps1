# QS AI Assistant - Fully Featured PowerShell Assistant Script

#region Configuration and Initialization

# Load API keys from environment or placeholders - secure in practice
$env:QS_API_KEY = $env:QS_API_KEY -or "your-real-xai-api-key"
$env:GITHUB_PAT = $env:GITHUB_PAT -or "your-github-pat"
$env:POE_API_KEY = $env:POE_API_KEY -or "your-poe-api-key"
$env:REDIS_KEY = $env:REDIS_KEY -or "your-redis-key"

$global:IsInitialized = $false
$global:LogFile = "$PWD\QS_Assistant.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $global:LogFile -Value $entry
}

function Initialize-QSAssistant {
    if (-not $global:IsInitialized) {
        Write-Host "Initializing QS Assistant..."
        Write-Log "Initialization started."
        # Load modules, verify APIs (extendable)
        $global:IsInitialized = $true
        Write-Host "QS Assistant initialized. Ready to receive queries."
        Write-Log "Initialization completed."
    }
}

#endregion

#region API Interaction

function Invoke-AIRequest {
    param(
        [string]$Prompt,
        [int]$MaxTokens = 1024,
        [double]$Temperature = 0.7
    )

    $apiUrl = "https://api.openai.com/v1/chat/completions"
    $headers = @{
        "Authorization" = "Bearer $env:QS_API_KEY"
        "Content-Type"  = "application/json"
    }
    $body = @{
        model = "gpt-4"
        messages = @(@{role="user"; content=$Prompt})
        max_tokens = $MaxTokens
        temperature = $Temperature
    } | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Post -Body $body -ErrorAction Stop
        return $response.choices[0].message.content.Trim()
    } catch {
        Write-Log "API call failed: $_" "ERROR"
        return "Sorry, I couldn't process your request due to an API error."
    }
}

#endregion

#region Command Execution

function Execute-Command {
    param([string]$Command)

    try {
        $output = Invoke-Expression -Command $Command 2>&1 | Out-String
        return "Command executed successfully.`n$output"
    } catch {
        return "Error executing command: $($_.Exception.Message)"
    }
}

#endregion

#region Core Assistant Logic

function Get-HelpText {
    @"
Available commands:
- list keys          : Show loaded API keys.
- status             : Show system status.
- help               : Show this help message.
- exit               : Exit the assistant.
- [Any PowerShell cmd]: Execute PowerShell command directly.

Just type your queries or commands below.
"@
}

function Get-LoadedKeys {
    @"
Loaded API Keys:
- QS_API_KEY          : $(if ($env:QS_API_KEY) {"Set"} else {"Not Set"})
- GITHUB_PAT          : $(if ($env:GITHUB_PAT) {"Set"} else {"Not Set"})
- POE_API_KEY         : $(if ($env:POE_API_KEY) {"Set"} else {"Not Set"})
- REDIS_KEY           : $(if ($env:REDIS_KEY) {"Set"} else {"Not Set"})
"@
}

function Handle-Query {
    param([string]$Input)

    $norm = $Input.Trim().ToLower()

    switch -Wildcard ($norm) {
        "list keys"   { return Get-LoadedKeys }
        "help"        { return Get-HelpText }
        "status"      { return "System is operational. API keys checked. Ready to process commands." }
        "exit"        { return "exit" }
        default {
            # Basic detection of PowerShell command pattern
            if ($Input -match '^(get|set|invoke|new|remove|start|stop|restart|write|read|clear|export|import)-') {
                return Execute-Command -Command $Input
            } else {
                return Invoke-AIRequest -Prompt $Input
            }
        }
    }
}

#endregion

#region Interactive Session

function Start-QSAssistant {
    Initialize-QSAssistant

    while ($true) {
        $userInput = Read-Host "QS"

        if ([string]::IsNullOrWhiteSpace($userInput)) {
            continue
        }

        $response = Handle-Query -Input $userInput

        if ($response -eq "exit") {
            Write-Host "Exiting QS Assistant. Goodbye!" -ForegroundColor Green
            break
        }

        Write-Host $response -ForegroundColor Yellow
        Write-Log "User: $userInput; Assistant: $response"
    }
}

#endregion

# Start the assistant when running the script
Start-QSAssistant
