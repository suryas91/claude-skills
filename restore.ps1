# Installs this Claude Code setup into ~/.claude (global, all Claude Code sessions):
#   1. every third-party skill in skills-lock.json
#   2. this repo's files: the 9 personas, /team-build (with its references and scripts),
#      the custom skills (freeze, playwright-testing) and the 4 hooks with their test suite
#   3. settings.json: skill list overrides, auto mode, and the hook wiring (merged, never overwritten)
#   4. the Playwright MCP server and the Impeccable design plugin
#   5. checks: lists any skill that failed to install and runs the hook test suite
# Usage (Windows blocks local scripts by default, hence -ExecutionPolicy Bypass):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\restore.ps1                  full install
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\restore.ps1 -SkipDownloads   only steps 2, 3 and 5:
#       no skill downloads, no npx, no network. Use it to update the team files after a git pull.
# Safe to re-run: files from this repo are overwritten with the repo's copy, settings are merged.
param([switch]$SkipDownloads)
$ErrorActionPreference = 'Stop'

$claude = Join-Path $env:USERPROFILE '.claude'
$lock = (Get-Content "$PSScriptRoot\skills-lock.json" -Raw | ConvertFrom-Json).skills

# ---------------------------------------------------------------------------------------------
# 1. Third-party skills from skills-lock.json
# ---------------------------------------------------------------------------------------------
# design-system-nextlevelbuilder shares the name "design-system" with the affaan-m/ecc skill,
# so it is installed separately under its own name below.
$renamed = 'design-system-nextlevelbuilder'
if (-not $SkipDownloads) {
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

    $entry = $lock.$renamed
    $tmp = Join-Path $env:TEMP "skills-restore-$(Get-Random)"
    git clone -q --depth 1 "https://github.com/$($entry.source).git" $tmp
    $dest = "$claude\skills\$renamed"
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Copy-Item -Recurse (Join-Path $tmp (Split-Path $entry.skillPath -Parent)) $dest
    $md = "$dest\SKILL.md"
    $text = [IO.File]::ReadAllText($md)
    $text = ([regex]'(?m)^name:.*$').Replace($text, "name: $renamed", 1)
    [IO.File]::WriteAllText($md, $text)
    Remove-Item -Recurse -Force $tmp
}

# ---------------------------------------------------------------------------------------------
# 2. This repo's files
# ---------------------------------------------------------------------------------------------
New-Item -ItemType Directory -Force "$claude\agents", "$claude\skills", "$claude\hooks\tests" | Out-Null
Copy-Item "$PSScriptRoot\agents\*.md" "$claude\agents\" -Force
foreach ($skill in 'team-build', 'freeze', 'playwright-testing') {
    $dest = "$claude\skills\$skill"
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }   # drop files the repo no longer has
    Copy-Item -Recurse -Force "$PSScriptRoot\skills\$skill" "$claude\skills\"
}
Copy-Item "$PSScriptRoot\hooks\*.ps1" "$claude\hooks\" -Force
Copy-Item "$PSScriptRoot\hooks\tests\*.ps1" "$claude\hooks\tests\" -Force
Write-Output "Installed $((Get-ChildItem "$PSScriptRoot\agents\*.md").Count) personas, /team-build, /freeze, playwright-testing and 4 hooks."

# ---------------------------------------------------------------------------------------------
# 3. settings.json (merged into what is already there; other settings are kept)
# ---------------------------------------------------------------------------------------------
$settingsPath = "$claude\settings.json"
# Read and write as UTF-8 explicitly: Windows PowerShell 5.1 otherwise reads a BOM-less file as ANSI
# and would corrupt any non-ASCII text in your existing settings.
$utf8 = New-Object Text.UTF8Encoding $false
$settings = [pscustomobject]@{}
if (Test-Path $settingsPath) {
    $raw = [IO.File]::ReadAllText($settingsPath, $utf8)
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try { $settings = $raw | ConvertFrom-Json }
        catch { throw "$settingsPath is not valid JSON (or has keys that differ only in case), so it was left untouched. Fix it and run the installer again. Details: $($_.Exception.Message)" }
    }
}
if ($null -eq $settings) { $settings = [pscustomobject]@{} }

# 3a. Show only skill names in the main skill list (personas still preload full skills).
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

# 3b. Auto mode as the default permission mode (unless one is already set).
if (-not ($settings.PSObject.Properties.Name -contains 'permissions')) { $settings | Add-Member -NotePropertyName permissions -NotePropertyValue ([pscustomobject]@{}) }
if (-not $settings.permissions.defaultMode) { $settings.permissions | Add-Member -NotePropertyName defaultMode -NotePropertyValue 'auto' -Force }

# 3c. Hook wiring. An entry is added only if no existing hook already runs that script,
#     so re-running never duplicates a hook and never changes one you customised.
$hookDir = ($claude -replace '\\', '/') + '/hooks'
$wanted = @(
    @{ event = 'PreToolUse';   matcher = 'Bash|PowerShell';        script = 'careful.ps1';         timeout = 15 },
    @{ event = 'PreToolUse';   matcher = 'Edit|Write|NotebookEdit'; script = 'ownership-guard.ps1'; timeout = 15 },
    @{ event = 'Stop';         matcher = $null;                    script = 'verify-gate.ps1';     timeout = 600 },
    @{ event = 'SessionStart'; matcher = 'startup|compact|resume'; script = 'team-resume.ps1';     timeout = 15 }
)
if (-not ($settings.PSObject.Properties.Name -contains 'hooks')) { $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
foreach ($w in $wanted) {
    $groups = @()
    if ($settings.hooks.PSObject.Properties.Name -contains $w.event) { $groups = @($settings.hooks.($w.event)) }
    $present = $false
    foreach ($g in $groups) { foreach ($h in @($g.hooks)) { if ([string]$h.command -like "*$($w.script)*") { $present = $true } } }
    if ($present) { Write-Output "Hook already wired: $($w.script)"; continue }
    $cmd = [pscustomobject]@{ type = 'command'; command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$hookDir/$($w.script)`""; timeout = $w.timeout }
    $group = if ($w.matcher) { [pscustomobject]@{ matcher = $w.matcher; hooks = @($cmd) } } else { [pscustomobject]@{ hooks = @($cmd) } }
    $settings.hooks | Add-Member -NotePropertyName $w.event -NotePropertyValue (@($groups) + @($group)) -Force
    Write-Output "Hook wired: $($w.event) -> $($w.script)"
}
[IO.File]::WriteAllText($settingsPath, (ConvertTo-Json -InputObject $settings -Depth 20), $utf8)

# ---------------------------------------------------------------------------------------------
# 4. Playwright MCP server and the Impeccable design plugin (user scope)
# ---------------------------------------------------------------------------------------------
if (-not $SkipDownloads) {
    # The Claude CLI may report "not found" on stderr. Under 'Stop', Windows PowerShell 5.1 turns any
    # native stderr output into a terminating error, so this step runs with 'Continue'.
    $ErrorActionPreference = 'Continue'
    $failed = @()
    try {
        $mcp = npx -y @anthropic-ai/claude-code mcp get playwright 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $mcp) {
            npx -y @anthropic-ai/claude-code mcp add playwright -s user -- cmd /c npx -y "@playwright/mcp@latest"
            if ($LASTEXITCODE -ne 0) { $failed += 'the Playwright MCP server' }
        }

        $plugins = npx -y @anthropic-ai/claude-code plugin list 2>$null | Out-String
        if ($plugins -notmatch 'impeccable@impeccable') {
            npx -y @anthropic-ai/claude-code plugin marketplace add pbakaus/impeccable
            if ($LASTEXITCODE -ne 0) { $failed += 'the Impeccable marketplace' }
            npx -y @anthropic-ai/claude-code plugin install impeccable@impeccable --scope user
            if ($LASTEXITCODE -ne 0) { $failed += 'the Impeccable plugin' }
        }
    } catch {
        $failed += "the MCP server and plugin step ($($_.Exception.Message))"
    } finally {
        if ($failed) { Write-Output "Warning: could not install $($failed -join ', '). Everything else is installed; add these by hand (see docs/troubleshooting.md)." }
        $ErrorActionPreference = 'Stop'
    }
}

# ---------------------------------------------------------------------------------------------
# 5. Checks
# ---------------------------------------------------------------------------------------------
if (-not $SkipDownloads) {
    $missing = $lock.PSObject.Properties.Name | Where-Object { -not (Test-Path "$claude\skills\$_\SKILL.md") }
    if ($missing) { Write-Output "Missing skills: $($missing -join ', ')" } else { Write-Output "All $($lock.PSObject.Properties.Name.Count) skills installed." }
}
Write-Output "Running the hook test suite..."
$results = & powershell -NoProfile -ExecutionPolicy Bypass -File "$claude\hooks\tests\test-hooks.ps1"
$results | Where-Object { $_ -match '^FAIL ' } | ForEach-Object { Write-Output $_ }
Write-Output ($results | Select-Object -Last 1)
Write-Output "Start a new Claude Code session to pick up the changes."
