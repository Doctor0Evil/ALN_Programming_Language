<#
.SYNOPSIS
  Unified Swarmnet helper script for Windows of Death dev.

.DESCRIPTION
  Provides functions to start the Swarmnet host, agents, and attach sessions.
  Also generates a VS Code tasks.json for one-click integration.
#>

# Path to swarmnet binary (adjust if needed)
$SwarmnetExe = ".\swarmnet.exe"

# --- FUNCTIONS ---

function Start-Host {
    param(
        [string]$AuditDir = ".\logs\host"
    )
    Write-Host ">>> Starting Swarmnet Host..."
    & $SwarmnetExe host `
        --config .\configs\merchantSystem.ing `
        --config .\configs\directorAI.ing `
        --config .\configs\virtualDesktop.ing `
        --config .\configs\operators.ing `
        --seedStrategy run-scoped `
        --audit $AuditDir
}

function Start-Agent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$User,
        [string]$WorkspacePrefix = "wd13-",
        [string]$HostUrl = "http://localhost:7777",
        [string]$AuditDir = ".\logs\agents"
    )
    $Workspace = "$WorkspacePrefix$User"
    $UserAudit = Join-Path $AuditDir $User
    Write-Host ">>> Starting Swarmnet Agent for $User in workspace $Workspace..."
    & $SwarmnetExe agent `
        --user $User `
        --workspace $Workspace `
        --connect $HostUrl `
        --audit $UserAudit
}

function Attach-Host {
    param(
        [string]$HostUrl = "http://localhost:7777"
    )
    Write-Host ">>> Attaching to Swarmnet Host at $HostUrl..."
    & $SwarmnetExe attach --connect $HostUrl
}

function Generate-VSCodeTasks {
    param(
        [string]$OutputDir = ".vscode"
    )
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    $tasks = @{
        version = "2.0.0"
        tasks = @(
            @{
                label = "Swarmnet: Start Host"
                type = "shell"
                command = "pwsh"
                args = @("-File", "swarmnet.ps1", ";", "Start-Host")
                group = "build"
            }
        )
    }

    # Add agent tasks for user01–user08
    for ($i=1; $i -le 8; $i++) {
        $user = "user{0:D2}" -f $i
        $tasks.tasks += @{
            label = "Swarmnet: Start Agent $user"
            type = "shell"
            command = "pwsh"
            args = @("-File", "swarmnet.ps1", ";", "Start-Agent -User $user")
            group = "build"
        }
    }

    $tasks.tasks += @{
        label = "Swarmnet: Attach Host"
        type = "shell"
        command = "pwsh"
        args = @("-File", "swarmnet.ps1", ";", "Attach-Host")
        group = "build"
    }

    $json = $tasks | ConvertTo-Json -Depth 5
    $json | Out-File (Join-Path $OutputDir "tasks.json") -Encoding utf8
    Write-Host ">>> VS Code tasks.json generated in $OutputDir"
}

# --- ENTRYPOINT LOGIC ---
param(
    [string]$Action,
    [string]$User
)

switch ($Action) {
    "host"   { Start-Host }
    "agent"  { if ($User) { Start-Agent -User $User } else { Write-Host "Please specify -User" } }
    "attach" { Attach-Host }
    "tasks"  { Generate-VSCodeTasks }
    default  {
        Write-Host "Usage:"
        Write-Host "  pwsh -File swarmnet.ps1 host"
        Write-Host "  pwsh -File swarmnet.ps1 agent -User user03"
        Write-Host "  pwsh -File swarmnet.ps1 attach"
        Write-Host "  pwsh -File swarmnet.ps1 tasks"
    }
}