# arm-gate.ps1 - arms, disarms or removes the /team-build verify gate for a project.
# Writes <project>/.claude/team/verify-gate.json AND a trust record in
# ~/.claude/state/verify-gate-trust.json (project path -> SHA-256 of the command).
# verify-gate.ps1 runs a gate command only when the trust record matches, so a gate file that
# arrives with a cloned repo, or is edited later, never executes. Trust model from gstack's
# gstack-verify-gate (MIT, (c) 2026 Garry Tan, https://github.com/garrytan/gstack).
# Usage:
#   arm-gate.ps1 -Project <root> -Command "<test command>"   arm (and trust) this command
#   arm-gate.ps1 -Project <root> -Disarm                      keep the file, set armed=false
#   arm-gate.ps1 -Project <root> -Rearm                       set armed=true again (same trusted command)
#   arm-gate.ps1 -Project <root> -Remove                      delete the gate file and the trust record
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [string]$Command,
    [switch]$Disarm,
    [switch]$Rearm,
    [switch]$Remove
)
$ErrorActionPreference = 'Stop'

function Norm([string]$p) { return ([IO.Path]::GetFullPath($p) -replace '\\', '/').TrimEnd('/').ToLowerInvariant() }
function Sha([string]$s) {
    $h = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($s))
    return (($h | ForEach-Object { $_.ToString('x2') }) -join '')
}
function WriteJson($obj, [string]$path) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
}

$root = Norm $Project
$gateFile = Join-Path $Project '.claude\team\verify-gate.json'
$trustFile = Join-Path $env:USERPROFILE '.claude\state\verify-gate-trust.json'

$trust = [ordered]@{}
if (Test-Path -LiteralPath $trustFile) {
    $j = Get-Content -LiteralPath $trustFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $j.PSObject.Properties) { $trust[$p.Name] = [string]$p.Value }
}

if ($Remove) {
    if (Test-Path -LiteralPath $gateFile) { Remove-Item -LiteralPath $gateFile -Force }
    if ($trust.Contains($root)) { $trust.Remove($root); WriteJson $trust $trustFile }
    "Verify gate removed for $root."
    exit 0
}

if ($Disarm -or $Rearm) {
    if (-not (Test-Path -LiteralPath $gateFile)) { "No verify gate file for $root."; exit 1 }
    $g = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($Rearm -and ($trust[$root] -ne (Sha ([string]$g.command)))) { "The gate command is not the trusted one. Arm it again with -Command."; exit 1 }
    $g | Add-Member -NotePropertyName armed -NotePropertyValue ([bool]$Rearm) -Force
    $g | Add-Member -NotePropertyName blocks -NotePropertyValue 0 -Force
    WriteJson $g $gateFile
    "Verify gate $(if ($Rearm) { 'armed' } else { 'disarmed' }) for $root."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Command)) { "Pass -Command, -Disarm, -Rearm or -Remove."; exit 1 }
WriteJson ([ordered]@{ command = $Command; armed = $true; maxBlocks = 3; blocks = 0 }) $gateFile
$trust[$root] = Sha $Command
WriteJson $trust $trustFile
"Verify gate armed and trusted for ${root}: $Command"
