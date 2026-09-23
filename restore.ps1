# Reinstalls every skill in skills-lock.json into ~/.claude/skills (global, all Claude Code sessions).
# Usage: .\restore.ps1
$ErrorActionPreference = 'Stop'
$lock = (Get-Content "$PSScriptRoot\skills-lock.json" -Raw | ConvertFrom-Json).skills

# design-system-nextlevelbuilder shares the name "design-system" with the affaan-m/ecc skill,
# so it is installed separately under its own name below.
$renamed = 'design-system-nextlevelbuilder'

$bySource = @{}
foreach ($p in $lock.PSObject.Properties) {
    if ($p.Name -eq $renamed) { continue }
    $src = $p.Value.source
    if (-not $bySource.ContainsKey($src)) { $bySource[$src] = @() }
    $bySource[$src] += $p.Name
}

foreach ($src in $bySource.Keys) {
    $names = $bySource[$src]
    Write-Output "=== $src ($($names.Count) skills)"
    npx -y skills@latest add $src -g -a claude-code --copy -y -s @names
}

# Install the renamed design-system skill
$entry = $lock.$renamed
$tmp = Join-Path $env:TEMP "skills-restore-$(Get-Random)"
git clone -q --depth 1 "https://github.com/$($entry.source).git" $tmp
$dest = "$env:USERPROFILE\.claude\skills\$renamed"
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Copy-Item -Recurse (Join-Path $tmp (Split-Path $entry.skillPath -Parent)) $dest
$md = "$dest\SKILL.md"
$text = [IO.File]::ReadAllText($md)
$text = ([regex]'(?m)^name:.*$').Replace($text, "name: $renamed", 1)
[IO.File]::WriteAllText($md, $text)
Remove-Item -Recurse -Force $tmp

# Personas (subagents) and the /team-build skill
$claude = "$env:USERPROFILE\.claude"
New-Item -ItemType Directory -Force "$claude\agents" | Out-Null
Copy-Item "$PSScriptRoot\agents\*.md" "$claude\agents\" -Force
Copy-Item -Recurse -Force "$PSScriptRoot\skills\team-build" "$claude\skills\"
Write-Output "Installed $((Get-ChildItem "$PSScriptRoot\agents\*.md").Count) personas and /team-build."

# Show only skill names in the main skill list (personas still preload full skills).
# Merges into existing settings.json without touching other settings.
$settingsPath = "$claude\settings.json"
$settings = if (Test-Path $settingsPath) { Get-Content $settingsPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
$overrides = [ordered]@{}
if ($settings.PSObject.Properties.Name -contains 'skillOverrides') {
    foreach ($p in $settings.skillOverrides.PSObject.Properties) { $overrides[$p.Name] = $p.Value }
}
foreach ($name in $lock.PSObject.Properties.Name) { if (-not $overrides.Contains($name)) { $overrides[$name] = 'name-only' } }
# ECC orchestration skills conflict with /team-build and need ECC agents that aren't installed; their
# work types (change, bug fix, refactor, spec build) are built into /team-build instead.
foreach ($name in 'orch-add-feature','orch-build-mvp','orch-change-feature','orch-fix-defect','orch-pipeline','orch-refine-code') {
    if ($overrides[$name] -eq 'name-only') { $overrides[$name] = 'off' }
}
$settings | Add-Member -NotePropertyName skillOverrides -NotePropertyValue ([pscustomobject]$overrides) -Force
[IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 10))

# Playwright MCP server (browser control for personas), user scope
$mcp = npx -y @anthropic-ai/claude-code mcp get playwright 2>$null
if (-not $mcp) { npx -y @anthropic-ai/claude-code mcp add playwright -s user -- cmd /c npx -y "@playwright/mcp@latest" }

# Impeccable design plugin (skill + design hook), user scope
$plugins = npx -y @anthropic-ai/claude-code plugin list 2>$null | Out-String
if ($plugins -notmatch 'impeccable@impeccable') {
    npx -y @anthropic-ai/claude-code plugin marketplace add pbakaus/impeccable
    npx -y @anthropic-ai/claude-code plugin install impeccable@impeccable --scope user
}

# Verify
$missing = $lock.PSObject.Properties.Name | Where-Object { -not (Test-Path "$claude\skills\$_\SKILL.md") }
if ($missing) { Write-Output "Missing: $($missing -join ', ')" } else { Write-Output "All $($lock.PSObject.Properties.Name.Count) skills installed." }
