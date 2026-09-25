# freeze.ps1 - sets, lifts or shows the edit freeze that ~/.claude/hooks/ownership-guard.ps1 enforces.
# Idea from gstack's /freeze (MIT, (c) 2026 Garry Tan, https://github.com/garrytan/gstack).
# State: ~/.claude/state/freeze.json  { "projects": { "<project root>": ["<folder>", ...] } }
# Usage: freeze.ps1 -Project <root> [<folder> ...] [-Off] ; no folders and no -Off shows the status.
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [switch]$Off,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Add = @()
)
$ErrorActionPreference = 'Stop'
# powershell -File passes "a,b" as one string; accept commas as separators too.
$Add = @($Add | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$file = Join-Path $env:USERPROFILE '.claude\state\freeze.json'
$root = ([IO.Path]::GetFullPath($Project) -replace '\\', '/').TrimEnd('/')

$state = [ordered]@{ projects = [ordered]@{} }
if (Test-Path -LiteralPath $file) {
    $raw = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    if ($raw.Trim()) {
        $j = $raw | ConvertFrom-Json
        foreach ($p in $j.projects.PSObject.Properties) { $state.projects[$p.Name] = @($p.Value) }
    }
}
$key = @($state.projects.Keys | Where-Object { $_.ToLowerInvariant() -eq $root.ToLowerInvariant() })[0]
if (-not $key) { $key = $root }
$current = @()
if ($state.projects.Contains($key)) { $current = @($state.projects[$key]) }

function Save {
    New-Item -ItemType Directory -Force -Path (Split-Path $file) | Out-Null
    $json = $state | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($file, $json, (New-Object Text.UTF8Encoding $false))
}

if ($Off) {
    if ($state.projects.Contains($key)) { $state.projects.Remove($key); Save }
    "Freeze lifted for $root."
    exit 0
}

if ($Add.Count) {
    foreach ($a in $Add) {
        $p = if ([IO.Path]::IsPathRooted($a)) { $a } else { Join-Path $root $a }
        $n = ([IO.Path]::GetFullPath($p) -replace '\\', '/').TrimEnd('/')
        if (-not (Test-Path -LiteralPath $n -PathType Container)) { "Not a folder, skipped: $n"; continue }
        if ($current -notcontains $n) { $current += $n }
    }
    if ($current.Count) { $state.projects[$key] = $current; Save }
}

if ($current.Count) { "Edits in $root are frozen to:"; $current | ForEach-Object { "  $_" } }
else { "No freeze set for $root." }
