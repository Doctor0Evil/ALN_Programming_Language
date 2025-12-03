# File: PowerGit/Runner/PowerGit.Manifest-Generate.ps1
param([string]$WorkRoot = "$env:GITHUB_RUNNER_ROOT/_work",
      [string]$OutPath = "$env:ALN_HASH_MANIFEST")

$files = Get-ChildItem -Path $WorkRoot -Recurse -File
$rows = foreach ($f in $files) {
    $h = Get-FileHash -Algorithm SHA256 -Path $f.FullName
    [pscustomobject]@{ Path = $f.FullName; Hash = $h.Hash }
}
$rows | Export-Csv -Path $OutPath -NoTypeInformation
Write-Host "Manifest written to: $OutPath"
