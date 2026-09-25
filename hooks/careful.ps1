# careful.ps1 - PreToolUse guard for Bash and PowerShell tool calls.
# Adapted from gstack's /careful (MIT, (c) 2026 Garry Tan, https://github.com/garrytan/gstack).
#   deny: recursive delete of a drive/home root, force-push to main/master,
#         stopping processes by name (taskkill /IM, Stop-Process -Name, pkill, killall).
#   ask:  other destructive commands (recursive deletes, DROP/TRUNCATE, reset --hard, ...).
# Commands are matched as text, so this is a safety net, not a security boundary.
$ErrorActionPreference = 'Stop'

function Out-Decision([string]$decision, [string]$reason) {
    $o = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = $decision; permissionDecisionReason = $reason } }
    [Console]::Out.Write(($o | ConvertTo-Json -Compress -Depth 4))
    exit 0
}

try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    $payload = $raw | ConvertFrom-Json
} catch {
    if ($raw) { Out-Decision 'ask' '[careful] Could not parse the tool payload to safety-check this command. Approve only if you know what it does.' }
    exit 0
}

# Fail closed: an unexpected error would otherwise exit 1, which Claude Code treats as a
# non-blocking error and lets the command run unchecked.
trap { Out-Decision 'ask' ("[careful] The safety check could not complete (" + $_.Exception.Message + "). Approve only if you know what this command does.") }

$cmd = [string]$payload.tool_input.command
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }
$c = $cmd.ToLowerInvariant()
$isSimple = -not ($c -match ';|&&|\|\||\||\r|\n')

# Obfuscation: word splitting via IFS, base64 piped to a shell, encoded PowerShell.
if ($c -match '\$\{?ifs\}?|base64\s+(-d|--decode)[^|]*\|\s*(sh|bash)|\s-e(nc|ncodedcommand)?\s+[a-z0-9+/=]{20,}') {
    Out-Decision 'ask' '[careful] Obfuscated command (IFS splitting, base64-to-shell or an encoded PowerShell command). Read it carefully before approving.'
}

# Commands that print secret values into tool output end up in the session transcript.
# From ruflo ADR-378 (MIT, (c) 2024-2026 ruvnet): a real signing key leaked this way and had to be rotated.
# Only ask when the output isn't redirected to a file or piped into another command.
$secretRead = '\bgcloud\s+secrets\s+versions\s+access\b|\baws\s+secretsmanager\s+get-secret-value\b|\baws\s+ssm\s+get-parameters?\b[^;&|]*--with-decryption|\baz\s+keyvault\s+secret\s+show\b|\bkubectl\s+get\s+secrets?\b[^;&|]*-o\s*(yaml|json|jsonpath)|\bgh\s+auth\s+token\b|\bop\s+(read|item\s+get)\b|\bvercel\s+env\s+pull\b[^;&|]*--stdout|\bheroku\s+config\b|^\s*(printenv|env|set|export\s+-p)\s*$|\b(get-childitem|gci|ls|dir)\s+env:|\b(cat|type|more|less|head|tail|get-content|gc)\s+[^;&|]*\.env\b(?!\.example)|\becho\s+[^;&|]*\$(env:)?\w*(key|token|secret|passw)'
if ($c -match $secretRead -and $c -notmatch '(^|[^2&])>\s*[^&]' -and $c -notmatch '\|') {
    Out-Decision 'ask' '[careful] This command may print a secret into the transcript. Redirect it into a file or pipe it straight into the command that needs it, or approve only if the output holds no secret.'
}

# Stopping processes by name kills other programs on this machine, possibly this session.
if ($c -match '\btaskkill\b[^;&|]*\s/im\b|\bstop-process\b[^;&|]*\s-(name|processname)\b|\b(pkill|killall)\b|\bget-process\b[^;&|]*\|\s*stop-process') {
    Out-Decision 'deny' '[careful] Stopping processes by name is blocked: it kills other programs on this machine. Find the PID of the process you started and stop only that PID (taskkill /PID <pid> /T /F or Stop-Process -Id <pid>).'
}

# Recursive deletes.
$recursiveDelete = ($c -match '(^|[;&|(])\s*(sudo\s+)?rm\s' -and $c -match '(^|\s)(-[a-z]*r[a-z]*|--recursive)(\s|$)') -or
                   ($c -match '(^|[;&|(])\s*(remove-item|ri)\b[^;&|]*\s-r(ecurse)?\b') -or
                   ($c -match '\b(rmdir|rd|del|erase)\b[^;&|]*\s/s\b')
if ($recursiveDelete) {
    $rootTargets = @('/', '/*', '~', '~/', '$home', '${home}', '$env:userprofile', 'c:\', 'c:/', 'c:', '\', '//')
    $safeNames = @('node_modules', '.next', 'dist', 'build', 'out', '__pycache__', '.cache', '.turbo', 'coverage', '.pytest_cache', '.mypy_cache', '.ruff_cache', '.venv', 'venv', '.parcel-cache', '.svelte-kit', '.nuxt', '.expo', 'target', 'tmp', '.tmp')
    $targets = @()
    foreach ($tok in ($cmd -split '\s+')) {
        $t = $tok.Trim('"', "'").ToLowerInvariant()
        if ($t -eq '' -or $t -match '^(sudo|rm|remove-item|ri|del|erase|rmdir|rd|-.*|/[a-z]$|--|\d?>.*|<.*|&|-force|-recurse|-path|-literalpath)$') { continue }
        $targets += $t
    }
    $hitsRoot = @($targets | Where-Object { $rootTargets -contains $_ }).Count -gt 0
    if ($isSimple -and $hitsRoot) {
        Out-Decision 'deny' '[careful] Recursive delete of a drive root or the home directory is blocked.'
    }
    $allSafe = $isSimple -and $targets.Count -gt 0 -and (@($targets | Where-Object {
        $leaf = ($_.TrimEnd('/', '\') -split '[\\/]')[-1]
        -not ($safeNames -contains $leaf)
    }).Count -eq 0)
    if (-not $allSafe) {
        Out-Decision 'ask' ('[careful] Recursive delete: ' + $cmd.Substring(0, [Math]::Min(200, $cmd.Length)) + '. Check the target before approving.')
    }
}

# git push --force (not --force-with-lease) or +refspec.
if ($c -match '\bgit\s+push\b') {
    $force = ($c -match '\s(-f|--force)(\s|$)') -or ($c -match '\s\+[^\s]')
    if ($force) {
        if ($isSimple -and $c -match '(\s|\+|:)(main|master)(\s|$)') {
            Out-Decision 'deny' '[careful] Force-push to main/master is blocked. Use --force-with-lease on a feature branch.'
        }
        Out-Decision 'ask' '[careful] Force push rewrites remote history. Prefer --force-with-lease.'
    }
}

$medium = @(
    @('\bdrop\s+(table|database|schema|view)\b', 'SQL DROP (data loss)'),
    @('\btruncate\s+(table\s+)?[a-z_"`]', 'SQL TRUNCATE (data loss)'),
    @('\bdelete\s+from\s+[a-z_."`]+\s*(;|$|")', 'DELETE without WHERE (data loss)'),
    @('\bdropdb\b', 'dropdb (data loss)'),
    @('\bprisma\s+migrate\s+reset\b|--force-reset\b|\bdb\s+reset\b', 'database reset (data loss)'),
    @('\bgit\s+reset\s+--hard\b', 'git reset --hard (loses uncommitted work)'),
    @('\bgit\s+(checkout|restore)\s+(--\s+)?\.(\s|$)', 'discards all uncommitted changes'),
    @('\bgit\s+clean\s+-[a-z]*f', 'git clean (deletes untracked files)'),
    @('\bgit\s+branch\s+(-d|--delete)\s+(-f|--force)\b|\bgit\s+branch\s+(-f|--force)\s+(-d|--delete)\b', 'force-deletes a branch'),
    @('\bgit\s+stash\s+(drop|clear)\b', 'deletes stashed work'),
    @('\bkubectl\s+delete\b', 'kubectl delete (production impact)'),
    @('\bdocker\s+(rm\s+-f|system\s+prune|volume\s+(rm|prune)|compose\s+down\s+.*-v)\b', 'Docker removal (containers or volumes)'),
    @('\bformat-volume\b|\bdiskpart\b|\bclear-disk\b', 'disk formatting')
)
foreach ($m in $medium) {
    if ($c -match $m[0]) { Out-Decision 'ask' ('[careful] ' + $m[1] + '. Approve only if this is intended.') }
}
# git branch -D is case-sensitive and was lowercased above, so check the original text.
if ($cmd -cmatch '\bgit\s+branch\s+(\S+\s+)*-D\b') { Out-Decision 'ask' '[careful] git branch -D force-deletes a branch. Approve only if this is intended.' }

exit 0
