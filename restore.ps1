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

# Verify
$missing = $lock.PSObject.Properties.Name | Where-Object { -not (Test-Path "$env:USERPROFILE\.claude\skills\$_\SKILL.md") }
if ($missing) { Write-Output "Missing: $($missing -join ', ')" } else { Write-Output "All $($lock.PSObject.Properties.Name.Count) skills installed." }
