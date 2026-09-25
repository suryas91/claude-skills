# verify-gate.ps1 - Stop hook: blocks the main session from ending its turn while the project's
# test command fails. Adapted from gstack's gstack-verify-gate (MIT, (c) 2026 Garry Tan,
# https://github.com/garrytan/gstack).
# It acts only when <project>/.claude/team/verify-gate.json exists with "armed": true.
# /team-build writes that file after the builders' full check passes and deletes it at finish,
# so ordinary sessions only pay for the file check.
#   { "command": "npm test", "armed": true, "maxBlocks": 3, "blocks": 0 }
# After maxBlocks consecutive blocks it lets the turn end with a warning instead of looping.
# Trust: the command runs only if ~/.claude/state/verify-gate-trust.json maps this project to the
# SHA-256 of that exact command. team-build writes both through scripts/arm-gate.ps1, so a gate
# file shipped in a cloned repo, or edited afterwards, is ignored instead of executed.
$ErrorActionPreference = 'Stop'

function Save-Gate($gate, [string]$path) {
    [IO.File]::WriteAllText($path, ($gate | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
}

try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch { exit 0 }

$project = $env:CLAUDE_PROJECT_DIR
if ([string]::IsNullOrWhiteSpace($project)) { $project = [string]$payload.cwd }
if ([string]::IsNullOrWhiteSpace($project)) { exit 0 }
$gateFile = Join-Path $project '.claude\team\verify-gate.json'
if (-not (Test-Path -LiteralPath $gateFile)) { exit 0 }

try { $gate = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { exit 0 }
if (-not $gate.armed -or [string]::IsNullOrWhiteSpace([string]$gate.command)) { exit 0 }

# Trust check: never run a command the user's own team-build run didn't arm.
$trusted = $false
try {
    $trustFile = Join-Path $env:USERPROFILE '.claude\state\verify-gate-trust.json'
    if (Test-Path -LiteralPath $trustFile) {
        $root = ([IO.Path]::GetFullPath($project) -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
        $t = Get-Content -LiteralPath $trustFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $want = [string]($t.PSObject.Properties | Where-Object { $_.Name -eq $root } | Select-Object -ExpandProperty Value -First 1)
        $bytes = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes([string]$gate.command))
        $have = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
        $trusted = $want -and ($want -eq $have)
    }
} catch { $trusted = $false }
if (-not $trusted) {
    $o = @{ systemMessage = "[verify-gate] Ignoring $gateFile`: its command isn't trusted (it wasn't armed by /team-build here, or it changed since). Not running it." }
    [Console]::Out.Write(($o | ConvertTo-Json -Compress))
    exit 0
}
$max = 3; if ($gate.maxBlocks -as [int]) { $max = [int]$gate.maxBlocks }
# A fresh stop (not a continuation caused by this hook) starts a new count.
$blocks = 0; if ($payload.stop_hook_active -and ($gate.blocks -as [int])) { $blocks = [int]$gate.blocks }

$out = Join-Path ([IO.Path]::GetTempPath()) ("verify-gate-" + [guid]::NewGuid().ToString('N'))
$code = $null
try {
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/c', [string]$gate.command) -WorkingDirectory $project `
        -NoNewWindow -PassThru -RedirectStandardOutput "$out.out" -RedirectStandardError "$out.err"
    # Windows PowerShell 5.1 reports no ExitCode unless the process handle was read while it ran.
    $null = $p.Handle
    if (-not $p.WaitForExit(480000)) {
        try { & taskkill.exe /PID $p.Id /T /F *> $null } catch { }
        $code = 'timeout'
    } else { $code = $p.ExitCode }
    $log = @()
    foreach ($f in "$out.out", "$out.err") { if (Test-Path -LiteralPath $f) { $log += Get-Content -LiteralPath $f -Tail 25 } }
} finally {
    Remove-Item -LiteralPath "$out.out", "$out.err" -Force -ErrorAction SilentlyContinue
}

if ($code -eq 0) {
    if ($gate.blocks) { $gate | Add-Member -NotePropertyName blocks -NotePropertyValue 0 -Force; Save-Gate $gate $gateFile }
    exit 0
}

$tail = (($log | Where-Object { $_ -ne $null }) -join "`n")
if ($tail.Length -gt 3000) { $tail = $tail.Substring($tail.Length - 3000) }

if ($blocks -ge $max) {
    $gate | Add-Member -NotePropertyName blocks -NotePropertyValue 0 -Force; Save-Gate $gate $gateFile
    $o = @{ systemMessage = "[verify-gate] '$($gate.command)' still fails after $max blocked stops; letting the turn end. The work is NOT verified green." }
    [Console]::Out.Write(($o | ConvertTo-Json -Compress))
    exit 0
}

$gate | Add-Member -NotePropertyName blocks -NotePropertyValue ($blocks + 1) -Force
Save-Gate $gate $gateFile
$reason = "[verify-gate] The test command '$($gate.command)' fails (exit $code), so this turn can't end yet (block $($blocks + 1) of $max).`n" +
    "You are the /team-build coordinator: don't fix application code yourself. Route the failure to the owning persona (team-build section 4) and continue.`n" +
    "If you are deliberately stopping with failing tests (a 2-fix-round escalation to the user), disarm it with arm-gate.ps1 -Project <root> -Disarm (never edit the gate file by hand), say so in your message, and re-arm it with -Rearm when the fix work resumes.`n" +
    "Last output:`n$tail"
$o = @{ decision = 'block'; reason = $reason }
[Console]::Out.Write(($o | ConvertTo-Json -Compress -Depth 3))
exit 0
