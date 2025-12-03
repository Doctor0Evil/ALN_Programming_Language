<# ===================================================================
  PowerGit | NSA-Class Nanoswarm Enforcement Runner
  File: PowerGit.NSA-SecureAgent.ps1
  Dest: PowerGit/Runner

  Purpose:
    Compliance-anchored nanoswarm watchdog for ALN and j.s.f. signature
    codebases. Enforces isolation, policy integrity, quarantine-based
    remediation, and immutable audit trails.

  ALN Principles:
    - Immutable auditability (append-only, hash-chained logs)
    - Rollback-enabled remediation (quarantine, not delete)
    - Live policy with signature verification (.SAI / .ALN)
    - Rights-anchored governance (director override hooks)

  j.s.f. Signature Fragment:
    j.s.f.sig: ALN/Doctor0Evil/PowerGit::NSA-Runner:v1.0
    j.s.f.hash: sha256-chain: { boot -> policy -> guard -> loop }

  Author: Doctor0Evil (Jacob Scott Farmer)
  License: ALN-Commons Compliance License
=================================================================== #>

param(
    [Parameter(Mandatory = $false)]
    [string]$RunnerRoot = $env:GITHUB_RUNNER_ROOT,

    [Parameter(Mandatory = $false)]
    [string]$PolicyConfig = $env:ALN_CLASS5_POLICY,

    [Parameter(Mandatory = $false)]
    [string]$ManifestPath = "$env:ALN_HASH_MANIFEST",

    [Parameter(Mandatory = $false)]
    [int]$CycleSeconds = 10
)

# --- Constants & Paths ---
$Timestamp      = { (Get-Date).ToString("o") }        # ISO-8601
$AgentName      = "PowerGit.NSA-SecureAgent"
$Root           = if ([string]::IsNullOrWhiteSpace($RunnerRoot)) { "$env:RUNNER_TEMP" } else { $RunnerRoot }
$DiagPath       = Join-Path $Root "_diag"
$WorkPath       = Join-Path $Root "_work"
$QuarantinePath = Join-Path $Root "_quarantine"
$LedgerPath     = Join-Path $Root "_ledger"
$LedgerFile     = Join-Path $LedgerPath "powergit.alnlog"
$ChainFile      = Join-Path $LedgerPath "powergit.chain"
$SafeExtensions = @(".aln",".sai",".dll",".exe",".ps1",".psm1")

# --- Bootstrap: Create required directories ---
foreach ($p in @($DiagPath,$WorkPath,$QuarantinePath,$LedgerPath)) {
    if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}

# --- Immutable ledger primitives (append-only with hash-chain) ---
Function Write-Chain {
    param([string]$Entry)
    $prev = if (Test-Path $ChainFile) { Get-Content $ChainFile -ErrorAction SilentlyContinue | Select-Object -Last 1 } else { "" }
    $prevHash = if ($prev) { (Get-FileHash -Algorithm SHA256 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($prev)))).Hash } else { "GENESIS" }
    $now = &$Timestamp
    $record = [string]::Format("{0}|{1}|{2}", $now, $prevHash, $Entry)
    Add-Content -Path $ChainFile -Value $record
    Add-Content -Path $LedgerFile -Value $record
}

Function Log-Event {
    param(
        [ValidateSet("INFO","WARN","ERROR","AUDIT","GUARD","POLICY","QUAR","INTEGRITY","ANOMALY")]
        [string]$Type,
        [string]$Message,
        [hashtable]$Meta = @{}
    )
    $metaStr = if ($Meta -and $Meta.Count -gt 0) {
        ($Meta.GetEnumerator() | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ";"
    } else { "" }
    Write-Chain "$AgentName|$Type|$Message|$metaStr"
}

# --- Safeguard: Signed policy verification (.SAI/.ALN/.ps1) ---
Function Invoke-SignedPolicy {
    param([string]$PolicyPath)
    if ([string]::IsNullOrWhiteSpace($PolicyPath) -or !(Test-Path $PolicyPath)) {
        Log-Event -Type "WARN" -Message "Policy path missing or not found." -Meta @{ Policy = $PolicyPath }
        return
    }
    $sig = Get-AuthenticodeSignature -FilePath $PolicyPath
    if ($sig.Status -eq 'Valid') {
        Log-Event -Type "POLICY" -Message "Valid policy signature." -Meta @{ Subject = $sig.SignerCertificate.Subject; Thumbprint = $sig.SignerCertificate.Thumbprint }
        . $PolicyPath
    } else {
        Log-Event -Type "ERROR" -Message "Invalid policy signature." -Meta @{ Status = $sig.Status; Policy = $PolicyPath }
        Disconnect-Runner "Invalid policy signature"  # softer-than-shutdown
    }
}

# --- Runner disconnect / isolation (softer than Stop-Computer) ---
Function Disconnect-Runner {
    param([string]$Reason)
    Log-Event -Type "ANOMALY" -Message "Runner isolation engaged." -Meta @{ Reason = $Reason }
    # Signal mechanism: create isolation marker; upstream controllers should halt jobs.
    $isolationFlag = Join-Path $DiagPath "isolation.flag"
    Set-Content -Path $isolationFlag -Value "PowerGit isolated: $Reason | $(&$Timestamp)"
    # Optional: stop runner worker processes
    Get-Process | Where-Object { $_.ProcessName -like "Runner.Worker*" } | ForEach-Object {
        try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
}

# --- System guard: whitelist-aware process control (safer) ---
Function Invoke-SystemGuard {
    $safeNames = @("Runner.Worker","powershell","pwsh","wscript","conhost","dotnet","SAIMAI","ALN.Agent","ALN.Service")
    $procs = Get-Process | Where-Object { $_.Id -ne $PID }
    foreach ($proc in $procs) {
        try {
            if (($safeNames -notcontains $proc.ProcessName) -and ($proc.ProcessName -notlike "ALN*")) {
                Log-Event -Type "GUARD" -Message "Stopping non-whitelisted process." -Meta @{ Proc = $proc.ProcessName; Id = $proc.Id }
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Log-Event -Type "WARN" -Message "Failed to stop process." -Meta @{ Proc = $proc.ProcessName; Id = $proc.Id; Err = $_.Exception.Message }
        }
    }
}

# --- Quarantine instead of delete ---
Function Move-ToQuarantine {
    param([string]$Path)
    try {
        $dest = Join-Path $QuarantinePath ([System.IO.Path]::GetFileName($Path))
        Move-Item -Path $Path -Destination $dest -Force
        Log-Event -Type "QUAR" -Message "Quarantined file." -Meta @{ File = $Path; Dest = $dest }
    } catch {
        Log-Event -Type "ERROR" -Message "Quarantine failed." -Meta @{ File = $Path; Err = $_.Exception.Message }
    }
}

# --- Integrity: baseline manifest verification (optional) ---
Function Verify-Manifest {
    param([string]$Manifest)
    if ([string]::IsNullOrWhiteSpace($Manifest) -or !(Test-Path $Manifest)) {
        Log-Event -Type "WARN" -Message "No manifest found; skipping strict integrity."
        return $true
    }
    $expected = Import-Csv -Path $Manifest
    $actual = Get-ChildItem $WorkPath -Recurse -File | ForEach-Object {
        $h = Get-FileHash -Algorithm SHA256 -Path $_.FullName
        [pscustomobject]@{ Path = $_.FullName; Hash = $h.Hash }
    }

    $mismatches = @()
    foreach ($e in $expected) {
        $match = $actual | Where-Object { $_.Path -eq $e.Path }
        if (!$match -or $match.Hash -ne $e.Hash) { $mismatches += $e }
    }

    if ($mismatches.Count -gt 0) {
        foreach ($m in $mismatches) {
            Log-Event -Type "INTEGRITY" -Message "Manifest mismatch." -Meta @{ Path = $m.Path; Expected = $m.Hash }
        }
        Disconnect-Runner "Manifest mismatches detected"
        return $false
    } else {
        Log-Event -Type "INTEGRITY" -Message "Manifest verified OK." -Meta @{ Count = $expected.Count }
        return $true
    }
}

# --- Diagnostic input sanitization (tag-aware) ---
Function Sanitize-Inputs {
    try {
        $logs = Get-ChildItem -Path $DiagPath -Filter "*.log" -ErrorAction SilentlyContinue
        foreach ($l in $logs) {
            $content = Get-Content -Path $l.FullName -ErrorAction SilentlyContinue
            if ($content -notcontains "ALN-SAFE") {
                Move-ToQuarantine -Path $l.FullName
            } else {
                Log-Event -Type "AUDIT" -Message "Log marked ALN-SAFE." -Meta @{ File = $l.FullName }
            }
        }
    } catch {
        Log-Event -Type "WARN" -Message "Sanitize-Inputs failed." -Meta @{ Err = $_.Exception.Message }
    }
}

# --- Binary audit: allow-list extensions, quarantine unknown ---
Function Audit-Binaries {
    try {
        $files = Get-ChildItem -Path $WorkPath -Recurse -File -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            if ($SafeExtensions -notcontains $f.Extension) {
                Move-ToQuarantine -Path $f.FullName
            }
        }
    } catch {
        Log-Event -Type "WARN" -Message "Audit-Binaries failed." -Meta @{ Err = $_.Exception.Message }
    }
}

# --- Entropy/duplicate hash detection (shadow clone guard) ---
Function Detect-DuplicateHashes {
    try {
        $hashSet = Get-ChildItem -Path $WorkPath -Recurse -File -ErrorAction SilentlyContinue | Get-FileHash -Algorithm SHA256
        $dup = $hashSet | Group-Object -Property Hash | Where-Object { $_.Count -gt 1 }
        if ($dup) {
            foreach ($group in $dup) {
                Log-Event -Type "ANOMALY" -Message "Duplicate hash detected." -Meta @{ Hash = $group.Name; Count = $group.Count }
            }
            Disconnect-Runner "Duplicate binary or memory shadow"
            return $false
        }
        Log-Event -Type "INTEGRITY" -Message "No duplicate hashes detected." -Meta @{ Count = $hashSet.Count }
        return $true
    } catch {
        Log-Event -Type "WARN" -Message "Duplicate hash detection failed." -Meta @{ Err = $_.Exception.Message }
        return $true
    }
}

# --- Anomaly flags watcher ---
Function Check-AnomalyFlags {
    $flags = Get-ChildItem -Path $DiagPath -Filter "anomaly.*" -ErrorAction SilentlyContinue
    if ($flags -and $flags.Count -gt 0) {
        foreach ($f in $flags) {
            Log-Event -Type "ANOMALY" -Message "Anomaly flag detected." -Meta @{ Flag = $f.FullName }
        }
        Disconnect-Runner "Anomaly trace present"
        return $false
    }
    return $true
}

# --- Director-level override (hookable) ---
Function Apply-DirectorOverride {
    # This hook is intentionally minimal; real deployments can wire DID/Web5 authority checks here.
    $overrideFlag = Join-Path $DiagPath "director.override"
    if (Test-Path $overrideFlag) {
        $reason = Get-Content -Path $overrideFlag -ErrorAction SilentlyContinue | Select-Object -First 1
        Log-Event -Type "AUDIT" -Message "Director override engaged." -Meta @{ Reason = $reason }
        # In override, we maintain monitoring but avoid enforcement actions.
        return $true
    }
    return $false
}

# --- Main agent loop ---
Function Start-NSA-SecureAgent {
    Log-Event -Type "INFO" -Message "Initializing $AgentName" -Meta @{ Root = $Root }

    while ($true) {
        $override = Apply-DirectorOverride

        if (-not $override) {
            Sanitize-Inputs
            Audit-Binaries

            $okDuplicates = Detect-DuplicateHashes
            $okManifest   = Verify-Manifest -Manifest $ManifestPath
            $okAnomalies  = Check-AnomalyFlags

            Invoke-SystemGuard
            Invoke-SignedPolicy -PolicyPath $PolicyConfig

            if (-not ($okDuplicates -and $okManifest -and $okAnomalies)) {
                Log-Event -Type "ERROR" -Message "Enforcement cycle anomalies; runner isolated."
            } else {
                Log-Event -Type "INFO" -Message "Enforcement cycle OK."
            }
        } else {
            Log-Event -Type "INFO" -Message "Override active; monitoring only."
        }

        Start-Sleep -Seconds $CycleSeconds
    }
}

# --- Entry point ---
Start-NSA-SecureAgent
