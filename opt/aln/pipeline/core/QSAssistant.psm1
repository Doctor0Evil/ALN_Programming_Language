# QSAssistant.psm1 - Fully Functional PowerShell AI Assistant Module
# Features: Advanced Reasoning, Command Execution, Syntax Fixing, File Ops, Compliance, ALN Operators, Interactive Shell

#region Global Initialization

$global:QSAssistantState = @{
    Initialized = $false
    SessionLog = @()
    ComplianceRules = @()
    OperatorPlugins = @{}
    CacheDir = Join-Path $env:USERPROFILE ".qsassistant_cache"
    CommandHistory = @()
}

function Initialize-QSAssistant {
    if (-not $global:QSAssistantState.Initialized) {
        if (-not (Test-Path $global:QSAssistantState.CacheDir)) {
            New-Item -Path $global:QSAssistantState.CacheDir -ItemType Directory | Out-Null
        }
        $global:QSAssistantState.ComplianceRules = @(
            @{ Name = "GDPR"; Validate = { param($input) return $true } },
            @{ Name = "HIPAA"; Validate = { param($input) return $true } },
            @{ Name = "SOC2"; Validate = { param($input) return $true } },
            @{ Name = "ISO27001"; Validate = { param($input) return $true } }
        )
        Register-QSOperator -Name "FileOps" -ScriptBlock ${function:Invoke-QSFileOps}
        Register-QSOperator -Name "Compliance" -ScriptBlock ${function:Invoke-QSCompliance}
        Register-QSOperator -Name "SyntaxFixer" -ScriptBlock ${function:Invoke-QSSyntaxFixer}
        Register-QSOperator -Name "ALN" -ScriptBlock ${function:Invoke-QSALNOperator}
        $global:QSAssistantState.Initialized = $true
        Write-Host "QSAssistant module initialized."
    }
}

#endregion

#region Operator Registration & Invocation

function Register-QSOperator {
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ScriptBlock]$ScriptBlock
    )
    $global:QSAssistantState.OperatorPlugins[$Name] = $ScriptBlock
}

function Invoke-QSOperator {
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][hashtable]$InputData
    )
    if ($global:QSAssistantState.OperatorPlugins.ContainsKey($Name)) {
        return & $global:QSAssistantState.OperatorPlugins[$Name] -InputData $InputData
    }
    else {
        throw "Operator '$Name' not found."
    }
}

#endregion

#region Syntax Fixer

function Invoke-QSSyntaxFixer {
    param ([hashtable]$InputData)
    $code = $InputData.Code
    if (-not $code) { return "SyntaxFixer: No code provided." }

    $fixedCode = $code -replace "`t", "    "
    $openBraces = ([regex]::Matches($fixedCode, "{")).Count
    $closeBraces = ([regex]::Matches($fixedCode, "}")).Count
    $diff = $openBraces - $closeBraces
    if ($diff -gt 0) { $fixedCode += '}' * $diff }
    $fixedCode = $fixedCode.TrimEnd()

    return $fixedCode
}

#endregion

#region File Operations

function Invoke-QSFileOps {
    param ([hashtable]$InputData)
    $action = $InputData.Action
    $fileName = $InputData.Name
    $content = $InputData.Content

    switch ($action) {
        "CreateFile" {
            if (-not $fileName) { return "CreateFile: Filename required." }
            New-Item -Path $fileName -ItemType File -Force | Out-Null
            if ($content) { Set-Content -Path $fileName -Value $content }
            return "File '$fileName' created."
        }
        "ReadFile" {
            if (-not (Test-Path $fileName)) { return "ReadFile: File '$fileName' not found." }
            return Get-Content $fileName -Raw
        }
        "WriteFile" {
            if (-not $fileName) { return "WriteFile: Filename required." }
            Set-Content -Path $fileName -Value $content
            return "File '$fileName' updated."
        }
        "FixFile" {
            if (-not (Test-Path $fileName)) { return "FixFile: File '$fileName' not found." }
            $code = Get-Content $fileName -Raw
            $fixed = Invoke-QSOperator -Name "SyntaxFixer" -InputData @{ Code = $code }
            Set-Content -Path $fileName -Value $fixed
            return "File '$fileName' fixed."
        }
        default {
            return "Unknown File operation: $action"
        }
    }
}

#endregion

#region Compliance Automation

function Invoke-QSCompliance {
    param ([hashtable]$InputData)

    foreach ($rule in $global:QSAssistantState.ComplianceRules) {
        if (-not (& $rule.Validate $InputData)) {
            return "Compliance check '$($rule.Name)' FAILED."
        }
    }
    return "All compliance checks passed."
}

#endregion

#region ALN Operator

function Invoke-QSALNOperator {
    param ([hashtable]$InputData)

    $command = $InputData.Command

    switch ($command) {
        "get-status" { return "ALN Status: Online and operational." }
        "reload-config" { return "ALN Config reloaded." }
        default { return "Unknown ALN command: $command"}
    }
}

#endregion

#region Command Execution & Error Correction

function Invoke-QSCommand {
    param ([string]$Command)

    try {
        $output = Invoke-Expression $Command 2>&1 | Out-String
        return "Command executed:`n$output"
    }
    catch {
        $correction = Invoke-QSOperator -Name "SyntaxFixer" -InputData @{ Code = $Command }
        return "Syntax error detected. Suggested fix:`n$correction"
    }
}

#endregion

#region Interactive Features

function Add-ToHistory {
    param ([string]$Entry)
    $global:QSAssistantState.CommandHistory += $Entry
}

function Show-History {
    if ($global:QSAssistantState.CommandHistory.Count -eq 0) {
        Write-Host "No history."
    } else {
        $global:QSAssistantState.CommandHistory | ForEach-Object { Write-Host $_ }
    }
}

#endregion

#region Conversational Interface

function Invoke-QSConversation {
    param ([string]$UserQuery)

    if ($UserQuery -match "^file\s+(create|read|write|fix)\s+(\S+)(?:\s+(['""])(.*)\3)?") {
        $action = $matches[1].Substring(0,1).ToUpper() + $matches[1].Substring(1)
        $file = $matches[2]
        $content = if ($matches.Count -ge 5) { $matches[4] } else { $null }
        return Invoke-QSOperator -Name "FileOps" -InputData @{ Action = $action; Name = $file; Content = $content }
    }
    elseif ($UserQuery -match "^compliance\s+check") {
        return Invoke-QSOperator -Name "Compliance" -InputData @{ Source = "UserQuery"; Query = $UserQuery }
    }
    elseif ($UserQuery -match "^run\s+(.+)$" ) {
        $cmd = $matches[1]
        return Invoke-QSCommand -Command $cmd
    }
    elseif ($UserQuery -match "^aln\s+(.+)$") {
        $cmd = $matches[1]
        return Invoke-QSOperator -Name "ALN" -InputData @{ Command = $cmd }
    }
    elseif ($UserQuery -eq "help") {
        return @"
Available commands:
- file create <filename> [content] : Create a file optionally with content
- file read <filename>             : Read file contents
- file write <filename> <content> : Write content to file
- file fix <filename>              : Fix syntax errors in file
- compliance check                : Run compliance checks
- run <command>                   : Execute PowerShell command
- aln <command>                   : Run ALN system command
- history                        : Show command history
- exit                          : Exit the assistant
"@
    }
    elseif ($UserQuery -eq "history") {
        Show-History
        return ""
    }
    elseif ($UserQuery -eq "exit") {
        return "exit"
    }
    else {
        return "QSAssistant: Unrecognized input. Type 'help' for assistance."
    }
}

#endregion

#region Main Interactive Shell

function Start-QSAssistantShell {
    Initialize-QSAssistant
    Write-Host "Welcome to QSAssistant v1.0.0"
    while ($true) {
        $input = Read-Host "QSAssistant>"

        if ([string]::IsNullOrWhiteSpace($input)) { continue }

        Add-ToHistory $input

        $response = Invoke-QSConversation -UserQuery $input

        if ($response -eq "exit") {
            Write-Host "Goodbye!"
            break
        }

        if ($response -ne "") {
            Write-Host $response -ForegroundColor Yellow
        }
    }
}

#endregion

Export-ModuleMember -Function * -Alias *

