<# ===================================================================
  PowerGit | Director Override Verifier (DID/Web5)
  File: PowerGit.DirectorOverride.Verify.ps1
  Dest: PowerGit/Runner

  Purpose:
    Verify sovereign director override via DID-anchored authority.
    Minimal viable verifier with on-disk claim → DID registry → policy.

  j.s.f. Signature Fragment:
    j.s.f.sig: ALN/Doctor0Evil/PowerGit::DirectorOverride:v1.0
    j.s.f.hash: sha256-chain: { claim -> did-resolve -> verify -> attest }

  Inputs:
    - $RunnerRoot: runner root (default env:GITHUB_RUNNER_ROOT)
    - $DIDMethod: did:web | did:key | aln (custom chain)
    - $AuthorityList: path to allow-list of directors (CSV: DID,Subject,Thumbprint)
    - $ClaimFile: director.override (flag+metadata)

  Outputs:
    - Append-only attestations to _ledger
    - Soft isolation or pass-through monitoring
=================================================================== #>

param(
  [string]$RunnerRoot    = $env:GITHUB_RUNNER_ROOT,
  [ValidateSet('did:web','did:key','aln')]
  [string]$DIDMethod     = 'did:web',
  [string]$AuthorityList = "$env:ALN_DIRECTORS",
  [string]$ClaimFile     = 'director.override'
)

# --- Paths & Ledger ---
$Root        = if ([string]::IsNullOrWhiteSpace($RunnerRoot)) { "$env:RUNNER_TEMP" } else { $RunnerRoot }
$DiagPath    = Join-Path $Root "_diag"
$LedgerPath  = Join-Path $Root "_ledger"
$LedgerFile  = Join-Path $LedgerPath "powergit.alnlog"
$ChainFile   = Join-Path $LedgerPath "powergit.chain"
$Override    = Join-Path $DiagPath $ClaimFile
$Timestamp   = { (Get-Date).ToString("o") }
$AgentName   = "PowerGit.DirectorOverride.Verify"

foreach ($p in @($DiagPath,$LedgerPath)) { if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }

Function Write-Chain {
  param([string]$Entry)
  $prev = if (Test-Path $ChainFile) { Get-Content $ChainFile -ErrorAction SilentlyContinue | Select-Object -Last 1 } else { "" }
  $prevHash = if ($prev) { (Get-FileHash -Algorithm SHA256 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($prev)))).Hash } else { "GENESIS" }
  $record = "{0}|{1}|{2}" -f (&$Timestamp), $prevHash, $Entry
  Add-Content -Path $ChainFile -Value $record
  Add-Content -Path $LedgerFile -Value $record
}

Function Log-Event {
  param(
    [ValidateSet("INFO","WARN","ERROR","AUDIT","ATTEST")]
    [string]$Type,
    [string]$Message,
    [hashtable]$Meta = @{}
  )
  $metaStr = if ($Meta.Count) { ($Meta.GetEnumerator() | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ";" } else { "" }
  Write-Chain "$AgentName|$Type|$Message|$metaStr"
}

Function Import-Authorities {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path $Path)) {
    Log-Event -Type "WARN" -Message "Authority allow-list not found." -Meta @{ Path = $Path }
    return @()
  }
  try { return Import-Csv -Path $Path } catch {
    Log-Event -Type "ERROR" -Message "Failed to import authorities." -Meta @{ Err = $_.Exception.Message }
    return @()
  }
}

Function Resolve-DID {
  param([string]$Did)
  # Minimal resolver stub for did:web, did:key, aln(custom)
  switch ($DIDMethod) {
    'did:web' { return @{ did = $Did; controller = $Did; verificationMethod = 'web-key'; status = 'Resolved' } }
    'did:key' { return @{ did = $Did; controller = $Did; verificationMethod = 'ed25519'; status = 'Resolved' } }
    'aln'     { return @{ did = $Did; controller = $Did; verificationMethod = 'aln-chain'; status = 'Resolved' } }
  }
}

Function Verify-Claim {
  param([string]$ClaimPath, [array]$Authorities)
  if (!(Test-Path $ClaimPath)) {
    Log-Event -Type "INFO" -Message "No override claim present."
    return $false
  }

  $lines = Get-Content -Path $ClaimPath -ErrorAction SilentlyContinue
  # Expected: first line DID; subsequent lines may include Reason=...; Thumbprint=...
  $didLine   = $lines | Select-Object -First 1
  $kvPairs   = $lines | Select-Object -Skip 1 | Where-Object { $_ -match "=" } | ForEach-Object {
                 $kv = $_.Split("=",2); [pscustomobject]@{ Key = $kv[0]; Value = $kv[1] }
               }

  $reason    = ($kvPairs | Where-Object Key -eq 'Reason').Value
  $thumb     = ($kvPairs | Where-Object Key -eq 'Thumbprint').Value

  $didDoc    = Resolve-DID -Did $didLine
  Log-Event -Type "AUDIT" -Message "DID resolved." -Meta @{ DID = $didDoc.did; Method = $DIDMethod; VM = $didDoc.verificationMethod }

  $authMatch = $Authorities | Where-Object { $_.DID -eq $didDoc.did -and ($thumb -eq $null -or $_.Thumbprint -eq $thumb) }
  if (!$authMatch) {
    Log-Event -Type "ERROR" -Message "Override DID not in allow-list." -Meta @{ DID = $didDoc.did; Thumb = $thumb }
    return $false
  }

  Log-Event -Type "ATTEST" -Message "Director override verified." -Meta @{ DID = $didDoc.did; Reason = $reason; Thumb = $thumb }
  return $true
}

Function Set-MonitoringOnly {
  $flag = Join-Path $DiagPath "monitoring.only"
  Set-Content -Path $flag -Value "Override Active | $(&$Timestamp)"
  Log-Event -Type "INFO" -Message "Monitoring-only mode engaged."
}

# Entry
$authorities = Import-Authorities -Path $AuthorityList
if (Verify-Claim -ClaimPath $Override -Authorities $authorities) {
  Set-MonitoringOnly
} else {
  Log-Event -Type "INFO" -Message "No verified override; enforcement may proceed."
}
