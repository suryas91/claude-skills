# fingerprint.ps1 - content fingerprint of a git working tree, for /team-build evidence.
# Idea from gstack's gstack-wtree and gstack-evidence (MIT, (c) 2026 Garry Tan, https://github.com/garrytan/gstack).
# Prints the git tree hash of the files on disk (tracked plus untracked, honoring .gitignore),
# excluding the work files and persona memory, which change without changing the product.
# Identical content gives the same hash across commits, amends and rebases, so a verdict
# recorded with a fingerprint is still valid exactly when the fingerprint still matches.
# It uses a temporary index, so it never changes the real index or the working tree.
# Usage (from the project root): powershell -NoProfile -File "$HOME/.claude/skills/team-build/scripts/fingerprint.ps1"
param([string]$Path = '.')
# Not 'Stop': in Windows PowerShell 5.1, git's stderr warnings (for example CRLF notices) would
# become terminating errors. Failures are detected through $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'
# A process started before Git was installed can lack it on PATH; fall back to the standard location.
if (-not (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path 'C:\Program Files\Git\cmd\git.exe')) {
    $env:Path = 'C:\Program Files\Git\cmd;' + $env:Path
}

Push-Location -LiteralPath $Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("team-fp-" + [guid]::NewGuid().ToString('N') + ".idx")
$oldIndex = $env:GIT_INDEX_FILE
try {
    $top = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $top) { [Console]::Error.WriteLine('fingerprint: not a git repository'); exit 2 }
    Set-Location -LiteralPath $top
    $env:GIT_INDEX_FILE = $tmp
    # An empty index when there are no commits yet; otherwise start from HEAD so the add is fast.
    & git rev-parse --verify -q HEAD *> $null
    if ($LASTEXITCODE -eq 0) { & git read-tree HEAD } else { & git read-tree --empty }
    if ($LASTEXITCODE -ne 0) { throw 'git read-tree failed' }
    & git add -A -- . 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
    & git rm -r -q --cached --ignore-unmatch -- docs/work .claude/agent-memory .claude/team *> $null
    $tree = (& git write-tree).Trim()
    if ($LASTEXITCODE -ne 0 -or $tree -notmatch '^[0-9a-f]{40,64}$') { throw 'git write-tree failed' }
    [Console]::Out.WriteLine($tree)
    exit 0
} catch {
    [Console]::Error.WriteLine("fingerprint: $($_.Exception.Message)")
    exit 1
} finally {
    $env:GIT_INDEX_FILE = $oldIndex
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    Pop-Location
}
