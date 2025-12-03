<# ===================================================================
  PowerGit | Authenticode Signer
  File: PowerGit.Authenticode.Signer.ps1
  Dest: PowerGit/Runner

  Purpose:
    Sign ALN/SAI/PS artifacts with a designated certificate for
    chain-of-custody verification. Publish signatures to ledger.

  j.s.f. Signature Fragment:
    j.s.f.sig: ALN/Doctor0Evil/PowerGit::Signer:v1.0
    j.s.f.hash: sha256-chain: { select -> sign -> verify -> publish }

  Inputs:
    - $ArtifactsRoot: directory to sign (e.g., repo or release folder)
    - $Subject: certificate Distinguished Name (DN) to match
    - $Store: Cert store location (CurrentUser|LocalMachine)
    - $StoreName: My|TrustedPublisher|CodeSigning etc.
    - $Pattern: *.ps1;*.aln;*.sai (semicolon-separated)
    - $LedgerRoot: runner ledger path for publishing

  Output:
    - Authenticode signatures applied
    - Append-only entries in _ledger with thumbprints and hashes
=================================================================== #>

param(
  [string]$ArtifactsRoot = (Resolve-Path ".").Path,
  [string]$Subject       = "CN=Doctor0Evil, O=SuperLiquid.INC",
  [ValidateSet("CurrentUser","LocalMachine")]
  [string]$Store         = "CurrentUser",
  [ValidateSet("My","TrustedPublisher","AuthRoot","CA","Root")]
  [string]$StoreName     = "My",
  [string]$Pattern       = "*.ps1;*.aln;*.sai",
  [string]$LedgerRoot    = $env:GITHUB_RUNNER_ROOT
)

# Ledger setup
$Root        = if ([string]::IsNullOrWhiteSpace($LedgerRoot)) { "$env:RUNNER_TEMP" } else { $LedgerRoot }
$LedgerPath  = Join-Path $Root "_ledger"
$LedgerFile  = Join-Path $LedgerPath "powergit.alnlog"
$ChainFile   = Join-Path $LedgerPath "powergit.chain"
$Timestamp   = { (Get-Date).ToString("o") }
$AgentName   = "PowerGit.Authenticode.Signer"
foreach ($p in @($LedgerPath)) { if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }

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
    [ValidateSet("INFO","WARN","ERROR","SIGN","VERIFY","PUBLISH")]
    [string]$Type,
    [string]$Message,
    [hashtable]$Meta = @{}
  )
  $metaStr = if ($Meta.Count) { ($Meta.GetEnumerator() | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ";" } else { "" }
  Write-Chain "$AgentName|$Type|$Message|$metaStr"
}

Function Get-CodeSigningCert {
  param([string]$Subject, [string]$Store, [string]$StoreName)
  $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, $Store)
  $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
  $cert = $store.Certificates | Where-Object { $_.Subject -like "*$Subject*" -and $_.HasPrivateKey } | Sort-Object NotAfter -Descending | Select-Object -First 1
  $store.Close()
  if (!$cert) { Log-Event -Type "ERROR" -Message "No signing certificate found." -Meta @{ Subject = $Subject; Store = "$Store/$StoreName" } }
  return $cert
}

Function Enumerate-Artifacts {
  param([string]$Root, [string]$Pattern)
  $patterns = $Pattern.Split(";") | Where-Object { $_ -ne "" }
  $files = @()
  foreach ($p in $patterns) { $files += Get-ChildItem -Path $Root -Recurse -File -Filter $p -ErrorAction SilentlyContinue }
  return $files | Sort-Object FullName -Unique
}

$cert = Get-CodeSigningCert -Subject $Subject -Store $Store -StoreName $StoreName
if (!$cert) { exit 1 }

$artifacts = Enumerate-Artifacts -Root $ArtifactsRoot -Pattern $Pattern
if ($artifacts.Count -eq 0) {
  Log-Event -Type "WARN" -Message "No artifacts matched pattern." -Meta @{ Root = $ArtifactsRoot; Pattern = $Pattern }
  exit 0
}

foreach ($f in $artifacts) {
  try {
    $sig = Set-AuthenticodeSignature -FilePath $f.FullName -Certificate $cert -TimestampServer "http://timestamp.digicert.com"
    if ($sig.Status -eq "Valid" -or $sig.Status -eq "Unknown") {
      Log-Event -Type "SIGN"   -Message "Signed artifact." -Meta @{ File = $f.FullName; Thumb = $cert.Thumbprint }
      $hash = Get-FileHash -Algorithm SHA256 -Path $f.FullName
      Log-Event -Type "VERIFY" -Message "Artifact hash." -Meta @{ File = $f.FullName; Sha256 = $hash.Hash }
      Log-Event -Type "PUBLISH"-Message "Published signature to ledger." -Meta @{ Subject = $cert.Subject; NotAfter = $cert.NotAfter }
    } else {
      Log-Event -Type "ERROR" -Message "Signature failed." -Meta @{ File = $f.FullName; Status = $sig.Status }
    }
  } catch {
    Log-Event -Type "ERROR" -Message "Signing exception." -Meta @{ File = $f.FullName; Err = $_.Exception.Message }
  }
}

Log-Event -Type "INFO" -Message "Signing pipeline completed." -Meta @{ Count = $artifacts.Count }
