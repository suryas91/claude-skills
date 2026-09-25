# team-resume.ps1 - SessionStart hook (matcher: startup|compact|resume). When a /team-build run is in
# progress in this project (<project>/.claude/team/ownership.json exists), it tells the coordinator
# to re-read the work file before continuing, so a compacted or resumed session doesn't lose the
# current step, the gate approvals or the fix-round tally.
# Idea from ruflo's Context Autopilot (MIT, (c) 2024-2026 ruvnet) and gstack's context-restore
# (MIT, (c) 2026 Garry Tan), without their compaction blocking.
# Informational only: on any error it exits 0 and adds nothing.
$ErrorActionPreference = 'Stop'
try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $project = $env:CLAUDE_PROJECT_DIR
    if ([string]::IsNullOrWhiteSpace($project)) { $project = [string]$payload.cwd }
    if ([string]::IsNullOrWhiteSpace($project)) { exit 0 }
    $ownFile = Join-Path $project '.claude\team\ownership.json'
    if (-not (Test-Path -LiteralPath $ownFile)) { exit 0 }
    $workFile = 'the work file (docs/work/<slug>.md)'
    try {
        $own = Get-Content -LiteralPath $ownFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace([string]$own.workFile)) { $workFile = [string]$own.workFile }
    } catch { }
    $source = [string]$payload.source
    $msg = "A /team-build run is in progress in this project (session $source). Before doing anything else, re-read " +
        "~/.claude/skills/team-build/SKILL.md and ${workFile}: its Handoff section (current step, next actions, gates approved, " +
        "fix-round tally, verify gate state, last fingerprint, running processes), Decisions, Log and Verification. " +
        "Also run 'git log --oneline' from the start commit. Resume from the Handoff's next step. Don't repeat a gate the user already approved, " +
        "and don't skip one that isn't recorded as approved."
    $o = @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $msg } }
    [Console]::Out.Write(($o | ConvertTo-Json -Compress -Depth 4))
    exit 0
} catch { exit 0 }
