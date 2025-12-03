param(
  [string]$Action,
  [string]$User,
  [string]$HostUrl = "http://localhost:7777"
)

# -------------------------------------------------------------------
# CONFIG
# -------------------------------------------------------------------
$SwarmnetExe   = ".\swarmnet.exe"
$ConfigsDir    = ".\configs"
$LogsDir       = ".\logs"
$HostAuditDir  = Join-Path $LogsDir "host"
$AgentsAuditDir= Join-Path $LogsDir "agents"
$TasksDir      = ".vscode"
$WorkspacePrefix = "wd13-"
$SeedEnvName   = "SWARMNET_SEED"
$DefaultSeed   = (Get-Date).ToString("yyyyMMdd-HHmmss") + "-WOD"

# Ensure directories
foreach ($d in @($LogsDir,$HostAuditDir,$AgentsAuditDir,$TasksDir)) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

# Seed injection (deterministic per session unless overridden)
if (-not $env:$SeedEnvName) {
  $env:$SeedEnvName = $DefaultSeed
  Write-Host ">>> Injected $SeedEnvName=$($env:$SeedEnvName)"
} else {
  Write-Host ">>> Using existing $SeedEnvName=$($env:$SeedEnvName)"
}

# -------------------------------------------------------------------
# FUNCTIONS
# -------------------------------------------------------------------
function Start-Host {
  param([string]$AuditDir = $HostAuditDir)
  if (-not (Test-Path $SwarmnetExe)) {
    Write-Host "ERROR: $SwarmnetExe not found in repo root." -ForegroundColor Red
    return
  }
  $cfgs = @(
    Join-Path $ConfigsDir "merchantSystem.ing",
    Join-Path $ConfigsDir "directorAI.ing",
    Join-Path $ConfigsDir "virtualDesktop.ing",
    Join-Path $ConfigsDir "operators.ing"
  )
  foreach ($c in $cfgs) {
    if (-not (Test-Path $c)) {
      Write-Host "ERROR: Missing config: $c" -ForegroundColor Red
      return
    }
  }
  Write-Host ">>> Starting Swarmnet Host..."
  & $SwarmnetExe host `
    --config $cfgs[0] `
    --config $cfgs[1] `
    --config $cfgs[2] `
    --config $cfgs[3] `
    --seedStrategy run-scoped `
    --audit $AuditDir
}

function Start-Agent {
  param(
    [Parameter(Mandatory=$true)][string]$User,
    [string]$AuditRoot = $AgentsAuditDir,
    [string]$Url = $HostUrl
  )
  if (-not (Test-Path $SwarmnetExe)) {
    Write-Host "ERROR: $SwarmnetExe not found in repo root." -ForegroundColor Red
    return
  }
  $Workspace = "$WorkspacePrefix$User"
  $UserAudit = Join-Path $AuditRoot $User
  if (-not (Test-Path $UserAudit)) { New-Item -ItemType Directory -Path $UserAudit | Out-Null }
  Write-Host ">>> Starting Swarmnet Agent for $User in workspace $Workspace..."
  & $SwarmnetExe agent `
    --user $User `
    --workspace $Workspace `
    --connect $Url `
    --audit $UserAudit
}

function Attach-Host {
  param([string]$Url = $HostUrl)
  if (-not (Test-Path $SwarmnetExe)) {
    Write-Host "ERROR: $SwarmnetExe not found in repo root." -ForegroundColor Red
    return
  }
  Write-Host ">>> Attaching to Swarmnet Host at $Url..."
  & $SwarmnetExe attach --connect $Url
}

function Generate-VSCodeTasks {
  param([string]$OutputDir = $TasksDir)
  if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

  $runner = "powershell"
  $scriptName = "swarmnet.bitshell" # change to swarmnet.ps1 if you prefer

  $tasks = @{
    version = "2.0.0"
    tasks   = @(
      @{
        label   = "Swarmnet: Start Host"
        type    = "shell"
        command = $runner
        args    = @("-File", $scriptName, "host")
        group   = "build"
      }
    )
  }

  for ($i=1; $i -le 8; $i++) {
    $user = "user{0:D2}" -f $i
    $tasks.tasks += @{
      label   = "Swarmnet: Start Agent $user"
      type    = "shell"
      command = $runner
      args    = @("-File", $scriptName, "agent", "-User", $user)
      group   = "build"
    }
  }

  $tasks.tasks += @{
    label   = "Swarmnet: Attach Host"
    type    = "shell"
    command = $runner
    args    = @("-File", $scriptName, "attach")
    group   = "build"
  }

  $json = $tasks | ConvertTo-Json -Depth 5
  $outFile = Join-Path $OutputDir "tasks.json"
  $json | Out-File $outFile -Encoding utf8
  Write-Host ">>> VS Code tasks.json generated: $outFile"
}

# SAFER WATCHDOG via Scheduled Task (requires Administrator)
function Register-Watchdog {
  param(
    [string]$TaskName = "SwarmnetWatchdog",
    [int]$IntervalMinutes = 2,
    [string]$ScriptPath = (Join-Path (Get-Location) "swarmnet.bitshell"),
    [string]$LogFile = (Join-Path $LogsDir "watchdog.log")
  )

  if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Register-Watchdog must be run as Administrator." -ForegroundColor Red
    return
  }

  $ActionArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`" host"
  $Action     = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $ActionArgs
  $Trigger    = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration ([TimeSpan]::MaxValue)
  $Settings   = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
  $Principal  = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

  Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Force | Out-Null
  "[$(Get-Date -Format 's')] Watchdog task registered: $TaskName (every $IntervalMinutes min)" | Out-File $LogFile -Append -Encoding utf8
  Write-Host ">>> Watchdog registered as Scheduled Task '$TaskName' (SYSTEM, every $IntervalMinutes minutes)."
}

function Unregister-Watchdog {
  param([string]$TaskName = "SwarmnetWatchdog")
  if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Unregister-Watchdog must be run as Administrator." -ForegroundColor Red
    return
  }
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host ">>> Watchdog task '$TaskName' removed."
}

# -------------------------------------------------------------------
# DISPATCH
# -------------------------------------------------------------------
switch ($Action) {
  "host"        { Start-Host }
  "agent"       { if ($User) { Start-Agent -User $User } else { Write-Host "Please specify -User (e.g., user03)" } }
  "attach"      { Attach-Host }
  "tasks"       { Generate-VSCodeTasks }
  "watchdog:register"   { Register-Watchdog }
  "watchdog:unregister" { Unregister-Watchdog }
  default {
    Write-Host "Usage:"
    Write-Host "  powershell -File .\swarmnet.bitshell host"
    Write-Host "  powershell -File .\swarmnet.bitshell agent -User user03"
    Write-Host "  powershell -File .\swarmnet.bitshell attach"
    Write-Host "  powershell -File .\swarmnet.bitshell tasks"
    Write-Host "  powershell -File .\swarmnet.bitshell watchdog:register   # Admin required"
    Write-Host "  powershell -File .\swarmnet.bitshell watchdog:unregister # Admin required"
  }
}