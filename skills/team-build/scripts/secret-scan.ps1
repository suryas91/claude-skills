# secret-scan.ps1 - scans the STAGED git diff for secrets before a /team-build checkpoint commit.
# Patterns from ruflo's security-auditor and pii-detector agents (MIT, (c) 2024-2026 ruvnet,
# https://github.com/ruvnet/ruflo), extended for Anthropic, Stripe, Slack and Google keys.
# Prints "file:line  kind" for each hit and NEVER prints the matched value.
# Exit 0 = clean, 1 = possible secrets found, 2 = could not run (not a repo, git missing).
# Usage (from the project root, after staging exactly the paths to commit with `git add -- <path> ...`;
# never `git add -A`, which sweeps in user-owned or stray files):
#   powershell -NoProfile -File "$HOME/.claude/skills/team-build/scripts/secret-scan.ps1"
$ErrorActionPreference = 'Continue'
if (-not (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path 'C:\Program Files\Git\cmd\git.exe')) {
    $env:Path = 'C:\Program Files\Git\cmd;' + $env:Path
}

$patterns = @(
    @('Anthropic API key',        'sk-ant-[A-Za-z0-9_\-]{20,}'),
    @('OpenAI-style API key',     'sk-(proj-)?[A-Za-z0-9_\-]{32,}'),
    @('AWS access key id',        '(AKIA|ABIA|ACCA|ASIA)[0-9A-Z]{16}'),
    @('GitHub token',             '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{60,}'),
    @('GitLab token',             'glpat-[A-Za-z0-9_\-]{20}'),
    @('Slack token',              'xox[baprs]-[A-Za-z0-9\-]{10,}'),
    @('Stripe secret key',        '(sk|rk)_live_[A-Za-z0-9]{20,}'),
    @('Google API key',           'AIza[0-9A-Za-z_\-]{35}'),
    @('Private key block',        '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'),
    @('Credentials in URL',       '(postgres(ql)?|mysql|mongodb(\+srv)?|redis|amqps?)://[^:/\s"''@]+:[^@/\s"'']+@'),
    @('JWT',                      'eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}'),
    @('Hardcoded secret assignment', '(?i)(api[_-]?key|secret|password|passwd|token|client[_-]?secret)\s*[:=]\s*["''][^"''\s]{12,}["'']')
)

& git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine('secret-scan: not a git repository'); exit 2 }

# Staged files that are being added, copied or modified (not deletions).
$files = @(& git diff --cached --name-only --diff-filter=ACMR)
if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine('secret-scan: git diff failed'); exit 2 }

$hits = New-Object System.Collections.Generic.List[string]
foreach ($f in $files) {
    if ([string]::IsNullOrWhiteSpace($f)) { continue }
    $leaf = ($f -split '/')[-1]
    if ($leaf -match '^\.env($|\.)' -and $leaf -ne '.env.example') { $hits.Add("${f}  .env file staged (should be gitignored)"); continue }
    # Added lines only, with their new-file line numbers.
    $diff = & git diff --cached -U0 --no-color -- "$f"
    $line = 0
    foreach ($d in $diff) {
        if ($d -match '^@@ -\d+(?:,\d+)? \+(\d+)') { $line = [int]$Matches[1]; continue }
        if ($d.StartsWith('+++') -or $d.StartsWith('---')) { continue }
        if ($d.StartsWith('+')) {
            $text = $d.Substring(1)
            foreach ($p in $patterns) {
                if ($text -match $p[1]) { $hits.Add("${f}:$line  $($p[0])"); break }
            }
            $line++
        }
    }
}

if ($hits.Count -eq 0) { 'secret-scan: clean (' + $files.Count + ' staged files checked)'; exit 0 }
'secret-scan: possible secrets in the staged changes (values not shown):'
$hits | ForEach-Object { "  $_" }
exit 1
