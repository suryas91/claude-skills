# ownership-guard.ps1 - PreToolUse guard for Edit, Write and NotebookEdit. Two checks, both from
# gstack's /freeze idea (MIT, (c) 2026 Garry Tan, https://github.com/garrytan/gstack):
# 1. Freeze (any session): if /freeze set edit folders for this project in
#    ~/.claude/state/freeze.json, the main session and every subagent may edit only inside them.
#    Always allowed: your own .claude/agent-memory/<agent>/ (any persona's for the main session), Claude's memory folders and the session scratchpad.
# 2. Ownership (/team-build): blocks a team persona (a subagent) from editing project files
#    outside the globs that team-build assigned it in <project>/.claude/team/ownership.json.
#    Allowed without checks: the main session, subagents not listed in the file, and paths outside
#    the project. A listed persona may write its own .claude/agent-memory/<agent>/ but no other
#    persona's. No ownership file means no team run: allow.
# Any unexpected error fails closed (deny), because a crashed hook would let the edit through.

$ErrorActionPreference = 'Stop'

function Out-Decision([string]$decision, [string]$reason) {
    $o = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = $decision; permissionDecisionReason = $reason } }
    [Console]::Out.Write(($o | ConvertTo-Json -Compress -Depth 4))
    exit 0
}
function Normalize([string]$p) { return ($p -replace '\\', '/').TrimEnd('/').ToLowerInvariant() }

try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch { exit 0 }

# Fail closed: an unexpected error would otherwise exit 1, which Claude Code treats as a
# non-blocking error and lets the edit through unchecked.
trap { Out-Decision 'deny' ("[guard] The freeze/ownership check could not complete (" + $_.Exception.Message + "). Report this to the user instead of retrying another way.") }

$project = $env:CLAUDE_PROJECT_DIR
if ([string]::IsNullOrWhiteSpace($project)) { $project = [string]$payload.cwd }
if ([string]::IsNullOrWhiteSpace($project)) { exit 0 }

$target = [string]$payload.tool_input.file_path
if ([string]::IsNullOrWhiteSpace($target)) { $target = [string]$payload.tool_input.notebook_path }
if ([string]::IsNullOrWhiteSpace($target)) { exit 0 }
if (-not [IO.Path]::IsPathRooted($target)) {
    $base = [string]$payload.cwd; if ([string]::IsNullOrWhiteSpace($base)) { $base = $project }
    $target = Join-Path $base $target
}
$full = Normalize ([IO.Path]::GetFullPath($target))
$root = Normalize ([IO.Path]::GetFullPath($project))
# A subagent may write only its own .claude/agent-memory/<agent>/ folder. The main session (the
# coordinator, which writes retro lessons) may write any persona's memory. Idea from ruflo ADR-G007.
$subAgent = ''
if (-not [string]::IsNullOrWhiteSpace([string]$payload.agent_type) -and -not [string]::IsNullOrWhiteSpace([string]$payload.agent_id)) {
    $subAgent = ([string]$payload.agent_type).ToLowerInvariant()
}
$memRoot = $root + '/.claude/agent-memory/'
$ownMemory = $full.StartsWith($memRoot) -and ($subAgent -eq '' -or $full.StartsWith($memRoot + $subAgent + '/'))

# 1. Freeze.
$freezeFile = Join-Path $env:USERPROFILE '.claude\state\freeze.json'
if (Test-Path -LiteralPath $freezeFile) {
    $frozen = $null
    try {
        $fz = Get-Content -LiteralPath $freezeFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $entry = $fz.projects.PSObject.Properties | Where-Object { (Normalize $_.Name) -eq $root }
        if ($entry) { $frozen = @($entry.Value | ForEach-Object { Normalize ([string]$_) } | Where-Object { $_ }) }
    } catch { Out-Decision 'deny' "[freeze] $freezeFile is not valid JSON, so this edit can't be checked. Run /freeze off or fix the file." }
    if ($frozen -and $frozen.Count) {
        $claudeProjects = Normalize (Join-Path $env:USERPROFILE '.claude\projects')
        $claudeTemp = Normalize (Join-Path ([IO.Path]::GetTempPath()) 'claude')
        $ok = $false
        foreach ($dir in $frozen) { if ($full -eq $dir -or $full.StartsWith($dir + '/')) { $ok = $true; break } }
        # Always writable: persona memory, Claude's memory folders and session scratchpads.
        if (-not $ok -and $ownMemory) { $ok = $true }
        if (-not $ok -and $full.StartsWith($claudeProjects + '/') -and $full -match '/memory/') { $ok = $true }
        if (-not $ok -and $full.StartsWith($claudeTemp + '/') -and $full -match '/scratchpad/') { $ok = $true }
        if (-not $ok) {
            Out-Decision 'deny' ("[freeze] Edits in this project are frozen to: " + ($frozen -join ', ') + ". '$full' is outside them. Don't work around this with shell commands. Ask the user to widen the freeze (/freeze <folder>) or lift it (/freeze off).")
        }
    }
}

# 2. Ownership (team personas only).
$agent = [string]$payload.agent_type
if ([string]::IsNullOrWhiteSpace($agent) -or [string]::IsNullOrWhiteSpace([string]$payload.agent_id)) { exit 0 }
$ownFile = Join-Path $project '.claude\team\ownership.json'
if (-not (Test-Path -LiteralPath $ownFile)) { exit 0 }

try { $own = Get-Content -LiteralPath $ownFile -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { Out-Decision 'deny' "[ownership] $ownFile is not valid JSON, so this edit can't be checked. Report this to the coordinator." }

$prop = $own.personas.PSObject.Properties | Where-Object { $_.Name -eq $agent }
if (-not $prop) { exit 0 }
$globs = @($prop.Value)

if (-not $full.StartsWith($root + '/')) { exit 0 }
$rel = $full.Substring($root.Length + 1)

if ($full.StartsWith($memRoot)) {
    if ($ownMemory) { exit 0 }
    Out-Decision 'deny' "[ownership] $agent may write only its own memory folder (.claude/agent-memory/$agent/). '$rel' belongs to another persona."
}

foreach ($g in $globs) {
    $n = Normalize ([string]$g)
    if ($n.StartsWith('./')) { $n = $n.Substring(2) }
    if ($n -eq '') { continue }
    if ($rel -eq $n) { exit 0 }
    if ($n -notmatch '[*?]' -and $rel.StartsWith($n + '/')) { exit 0 }
    # -like treats [ ] as a character class; escape them so Next.js routes like app/[id]/ match literally.
    $pattern = ($n -replace '\[', '`[' -replace '\]', '`]') -replace '\*\*/', '*' -replace '\*\*', '*'
    if ($rel -like $pattern) { exit 0 }
}

$owned = if ($globs.Count) { ($globs -join ', ') } else { 'nothing (read-only persona)' }
Out-Decision 'deny' "[ownership] $agent may not edit '$rel'. It owns: $owned. Don't work around this with shell commands: list the change under Requests in your report, and the coordinator will route it to the owning persona. (If no /team-build run is active, $ownFile is left over from a crashed run: tell the user it can be deleted.)"
