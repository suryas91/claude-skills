# test-hooks.ps1 - regression tests for the hooks in ~/.claude/hooks and the team-build scripts.
# Run after ANY hook or script edit:  powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\hooks\tests\test-hooks.ps1"
# Each case pipes a Claude-Code-style JSON payload into a hook and checks the decision (golden cases,
# idea from ruflo ADR-G013 and ADR-102, MIT). Uses a throwaway project under %TEMP%\claude and restores
# ~/.claude/state files it touches. Prints FAILURES: 0 when everything passes; exit code = failure count.
$ErrorActionPreference = 'Continue'
if (-not (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path 'C:\Program Files\Git\cmd\git.exe')) { $env:Path = 'C:\Program Files\Git\cmd;' + $env:Path }
$H = Join-Path $env:USERPROFILE '.claude\hooks'
$TB = Join-Path $env:USERPROFILE '.claude\skills\team-build\scripts'
$proj = Join-Path $env:TEMP ('claude\hooktest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force "$proj\src\auth", "$proj\src\ui", "$proj\.claude\team", "$proj\.claude\agent-memory\verifier", "$proj\.claude\agent-memory\frontend-dev" | Out-Null
$state = Join-Path $env:USERPROFILE '.claude\state'
$freezeFile = "$state\freeze.json"; $trustFile = "$state\verify-gate-trust.json"
$freezeBackup = if (Test-Path $freezeFile) { Get-Content $freezeFile -Raw } else { $null }
$trustBackup = if (Test-Path $trustFile) { Get-Content $trustFile -Raw } else { $null }
$env:CLAUDE_PROJECT_DIR = $proj
$script:fail = 0

function Run([string]$hook, $obj) {
    $json = $obj | ConvertTo-Json -Compress -Depth 5
    return (($json | powershell -NoProfile -ExecutionPolicy Bypass -File "$H\$hook") -join '')
}
function Decision([string]$out) {
    if ($out -match '"permissionDecision":"(\w+)"') { return $Matches[1] }
    if ($out -match '"decision":"(\w+)"') { return $Matches[1] }
    if ($out -match 'additionalContext') { return 'context' }
    if ($out -match 'systemMessage') { return 'warn' }
    if ($out) { return "raw:$out" }
    return 'allow'
}
function Expect([string]$name, [string]$out, [string]$want) {
    $got = Decision $out
    if ($got -ne $want) { $script:fail++ }
    "{0} {1,-62} want={2,-7} got={3}" -f ($(if ($got -eq $want) { 'ok  ' } else { 'FAIL' })), $name, $want, $got
}
function Check([string]$name, [bool]$cond) { if (-not $cond) { $script:fail++ }; "{0} {1}" -f ($(if ($cond) { 'ok  ' } else { 'FAIL' })), $name }
function Edit($path, $agent) { $o = @{ tool_name = 'Edit'; cwd = $proj; tool_input = @{ file_path = $path } }; if ($agent) { $o.agent_type = $agent; $o.agent_id = 'a1' }; return $o }
function Cmd([string]$c) { return @{ tool_name = 'Bash'; tool_input = @{ command = $c } } }

try {
"--- careful.ps1: destructive commands"
Expect 'rm -rf node_modules (safe name)'                (Run 'careful.ps1' (Cmd 'rm -rf node_modules')) 'allow'
Expect 'rm -rf ~'                                        (Run 'careful.ps1' (Cmd 'rm -rf ~')) 'deny'
Expect 'Remove-Item -Recurse -Force C:\'                 (Run 'careful.ps1' (Cmd 'Remove-Item -Recurse -Force C:\')) 'deny'
Expect 'rm -rf src (ask)'                                (Run 'careful.ps1' (Cmd 'rm -rf src')) 'ask'
Expect 'taskkill /IM node.exe'                           (Run 'careful.ps1' (Cmd 'taskkill /IM node.exe /F')) 'deny'
Expect 'Stop-Process -Name node'                         (Run 'careful.ps1' (Cmd 'Stop-Process -Name node')) 'deny'
Expect 'taskkill /PID 123'                               (Run 'careful.ps1' (Cmd 'taskkill /PID 123 /T /F')) 'allow'
Expect 'git push --force origin main'                    (Run 'careful.ps1' (Cmd 'git push --force origin main')) 'deny'
Expect 'git push --force-with-lease (feature branch)'    (Run 'careful.ps1' (Cmd 'git push --force-with-lease origin team/x')) 'allow'
Expect 'git reset --hard'                                (Run 'careful.ps1' (Cmd 'git reset --hard HEAD~1')) 'ask'
Expect 'git branch -D'                                   (Run 'careful.ps1' (Cmd 'git branch -D team/x')) 'ask'
Expect 'DROP TABLE'                                      (Run 'careful.ps1' (Cmd 'psql -c "DROP TABLE users"')) 'ask'
Expect 'git worktree remove --force'                     (Run 'careful.ps1' (Cmd 'git worktree remove --force C:/tmp/wt')) 'allow'
Expect 'npm test'                                        (Run 'careful.ps1' (Cmd 'npm test')) 'allow'
"--- careful.ps1: secret-printing commands"
Expect 'gcloud secrets versions access (to stdout)'      (Run 'careful.ps1' (Cmd 'gcloud secrets versions access latest --secret=api-key')) 'ask'
Expect 'gcloud secrets ... > file'                       (Run 'careful.ps1' (Cmd 'gcloud secrets versions access latest --secret=k > key.pem')) 'allow'
Expect 'aws secretsmanager get-secret-value'             (Run 'careful.ps1' (Cmd 'aws secretsmanager get-secret-value --secret-id prod')) 'ask'
Expect 'kubectl get secret -o yaml'                      (Run 'careful.ps1' (Cmd 'kubectl get secret db -o yaml')) 'ask'
Expect 'gh auth token'                                   (Run 'careful.ps1' (Cmd 'gh auth token')) 'ask'
Expect 'gh auth token | docker login (piped)'            (Run 'careful.ps1' (Cmd 'gh auth token | docker login ghcr.io -u me --password-stdin')) 'allow'
Expect 'printenv (bare)'                                 (Run 'careful.ps1' (Cmd 'printenv')) 'ask'
Expect 'printenv PATH (named, harmless)'                 (Run 'careful.ps1' (Cmd 'printenv PATH')) 'allow'
Expect 'Get-ChildItem env:'                              (Run 'careful.ps1' (Cmd 'Get-ChildItem env:')) 'ask'
Expect 'cat .env.local'                                  (Run 'careful.ps1' (Cmd 'cat .env.local')) 'ask'
Expect 'cat .env.example (allowed)'                      (Run 'careful.ps1' (Cmd 'cat .env.example')) 'allow'
Expect 'echo $API_KEY'                                   (Run 'careful.ps1' (Cmd 'echo $OPENAI_API_KEY')) 'ask'
Expect 'unparseable payload asks'                        (('not json' | powershell -NoProfile -ExecutionPolicy Bypass -File "$H\careful.ps1") -join '') 'ask'

"--- ownership-guard.ps1: ownership and memory scope"
'{ "workFile": "docs/work/x.md", "personas": { "frontend-dev": ["src/ui/**"], "verifier": [], "backend-dev": ["app/[id]/**"] } }' | Set-Content "$proj\.claude\team\ownership.json"
Expect 'owner edits own file'                            (Run 'ownership-guard.ps1' (Edit "$proj\src\ui\b.tsx" 'frontend-dev')) 'allow'
Expect 'owner edits other file'                          (Run 'ownership-guard.ps1' (Edit "$proj\src\auth\a.ts" 'frontend-dev')) 'deny'
Expect 'verifier edits code'                             (Run 'ownership-guard.ps1' (Edit "$proj\src\ui\b.tsx" 'verifier')) 'deny'
Expect 'bracket route glob app/[id]'                     (Run 'ownership-guard.ps1' (Edit "$proj\app\[id]\page.tsx" 'backend-dev')) 'allow'
Expect 'main session unrestricted'                       (Run 'ownership-guard.ps1' (Edit "$proj\src\auth\a.ts" $null)) 'allow'
Expect 'unlisted subagent unrestricted'                  (Run 'ownership-guard.ps1' (Edit "$proj\src\auth\a.ts" 'Explore')) 'allow'
Expect 'verifier writes OWN memory'                      (Run 'ownership-guard.ps1' (Edit "$proj\.claude\agent-memory\verifier\MEMORY.md" 'verifier')) 'allow'
Expect 'frontend-dev writes VERIFIER memory'             (Run 'ownership-guard.ps1' (Edit "$proj\.claude\agent-memory\verifier\MEMORY.md" 'frontend-dev')) 'deny'
Expect 'coordinator writes any persona memory'           (Run 'ownership-guard.ps1' (Edit "$proj\.claude\agent-memory\verifier\MEMORY.md" $null)) 'allow'
Expect 'malformed path fails CLOSED'                     (Run 'ownership-guard.ps1' (Edit "$proj\src\x<y>|z.ts" 'frontend-dev')) 'deny'
Remove-Item "$proj\.claude\team\ownership.json"
Expect 'no ownership file: allow'                        (Run 'ownership-guard.ps1' (Edit "$proj\src\auth\a.ts" 'frontend-dev')) 'allow'

"--- ownership-guard.ps1: freeze"
$fz = Join-Path $env:USERPROFILE '.claude\skills\freeze\freeze.ps1'
powershell -NoProfile -File $fz -Project $proj -Off | Out-Null
powershell -NoProfile -File $fz -Project $proj "src/auth" | Out-Null
Expect 'frozen: edit inside src/auth'                    (Run 'ownership-guard.ps1' (Edit "$proj\src\auth\a.ts" $null)) 'allow'
Expect 'frozen: edit outside'                            (Run 'ownership-guard.ps1' (Edit "$proj\src\ui\b.tsx" $null)) 'deny'
Expect 'frozen: prefix trick src/auth2'                  (Run 'ownership-guard.ps1' (Edit "$proj\src\auth2\x.ts" $null)) 'deny'
Expect 'frozen: subagent own memory allowed'             (Run 'ownership-guard.ps1' (Edit "$proj\.claude\agent-memory\verifier\m.md" 'verifier')) 'allow'
Expect 'frozen: subagent other memory denied'            (Run 'ownership-guard.ps1' (Edit "$proj\.claude\agent-memory\verifier\m.md" 'frontend-dev')) 'deny'
Expect 'frozen: scratchpad allowed'                      (Run 'ownership-guard.ps1' (Edit "$env:TEMP\claude\x\s1\scratchpad\s.txt" $null)) 'allow'
Expect 'frozen: outside project denied'                  (Run 'ownership-guard.ps1' (Edit "$env:USERPROFILE\notes.txt" $null)) 'deny'
powershell -NoProfile -File $fz -Project $proj -Off | Out-Null
Expect 'after /freeze off: edit anywhere'                (Run 'ownership-guard.ps1' (Edit "$proj\src\ui\b.tsx" $null)) 'allow'

"--- verify-gate.ps1 + arm-gate.ps1"
$arm = "$TB\arm-gate.ps1"
$stop = @{ hook_event_name = 'Stop'; cwd = $proj; stop_hook_active = $false }
Expect 'no gate file'                                    (Run 'verify-gate.ps1' $stop) 'allow'
'{ "command": "echo pwned > pwned.txt & exit 1", "armed": true, "maxBlocks": 3, "blocks": 0 }' | Set-Content "$proj\.claude\team\verify-gate.json"
Expect 'untrusted (repo-shipped) gate file ignored'      (Run 'verify-gate.ps1' $stop) 'warn'
Check  'untrusted command not executed'                  (-not (Test-Path "$proj\pwned.txt"))
powershell -NoProfile -File $arm -Project $proj -Command 'echo all good' | Out-Null
Expect 'trusted passing command'                         (Run 'verify-gate.ps1' $stop) 'allow'
'{ "command": "echo pwned > pwned.txt & exit 1", "armed": true, "maxBlocks": 3, "blocks": 0 }' | Set-Content "$proj\.claude\team\verify-gate.json"
Expect 'tampered gate file ignored'                      (Run 'verify-gate.ps1' $stop) 'warn'
Check  'tampered command not executed'                   (-not (Test-Path "$proj\pwned.txt"))
powershell -NoProfile -File $arm -Project $proj -Command 'echo 2 tests failed & exit 1' | Out-Null
$o = Run 'verify-gate.ps1' $stop
Expect 'failing: block 1'                                $o 'block'
Check  'block reason carries test output'                ($o -match '2 tests failed')
$stop.stop_hook_active = $true
Expect 'failing: block 2'                                (Run 'verify-gate.ps1' $stop) 'block'
Expect 'failing: block 3'                                (Run 'verify-gate.ps1' $stop) 'block'
Expect 'failing: gives up after 3'                       (Run 'verify-gate.ps1' $stop) 'warn'
$stop.stop_hook_active = $false
powershell -NoProfile -File $arm -Project $proj -Disarm | Out-Null
Expect 'disarmed'                                        (Run 'verify-gate.ps1' $stop) 'allow'
powershell -NoProfile -File $arm -Project $proj -Rearm | Out-Null
Expect 're-armed blocks again'                           (Run 'verify-gate.ps1' $stop) 'block'
powershell -NoProfile -File $arm -Project $proj -Remove | Out-Null
Expect 'removed: no gate'                                (Run 'verify-gate.ps1' $stop) 'allow'

"--- team-resume.ps1 (SessionStart)"
$ss = @{ hook_event_name = 'SessionStart'; cwd = $proj; source = 'compact' }
Expect 'no team run: nothing added'                      (Run 'team-resume.ps1' $ss) 'allow'
'{ "workFile": "docs/work/demo.md", "personas": {} }' | Set-Content "$proj\.claude\team\ownership.json"
$o = Run 'team-resume.ps1' $ss
Expect 'team run in progress: context added'             $o 'context'
Check  'context names the work file'                     ($o -match 'docs/work/demo.md')
Remove-Item "$proj\.claude\team\ownership.json"

"--- secret-scan.ps1"
Push-Location $proj
git init -q; git config user.email t@t; git config user.name t
'const x = 1' | Set-Content src\ok.ts
git add -A; $null = powershell -NoProfile -File "$TB\secret-scan.ps1"; Check 'clean diff exits 0' ($LASTEXITCODE -eq 0)
$fake = 'sk-ant-api03-' + ('A' * 40)
"const key = '$fake'" | Set-Content src\leak.ts
# Fake credentials are built at runtime, so this test file itself never trips the scan it tests.
$pw = 'hunter' + '2'
('DATABASE_URL=postgres://admin:' + $pw + '@db:5432/app') | Set-Content src\conf.txt
git add -A; $o = powershell -NoProfile -File "$TB\secret-scan.ps1"; $code = $LASTEXITCODE
Check 'secrets found: exit 1'                            ($code -eq 1)
Check 'reports Anthropic key location'                   (($o -join "`n") -match 'src/leak.ts:1\s+Anthropic API key')
Check 'reports credentials-in-URL'                       (($o -join "`n") -match 'src/conf.txt:1\s+Credentials in URL')
Check 'never prints the secret value'                    (-not (($o -join "`n") -match [regex]::Escape($fake)) -and -not (($o -join "`n") -match [regex]::Escape($pw)))
'X=1' | Set-Content .env.local; git add -f .env.local
$o = powershell -NoProfile -File "$TB\secret-scan.ps1"
Check 'staged .env file flagged'                         (($o -join "`n") -match '\.env\.local\s+\.env file staged')
Pop-Location
} finally {
    Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
    Remove-Item $proj -Recurse -Force -ErrorAction SilentlyContinue
    if ($freezeBackup) { [IO.File]::WriteAllText($freezeFile, $freezeBackup) } elseif (Test-Path $freezeFile) { Remove-Item $freezeFile }
    if ($trustBackup) { [IO.File]::WriteAllText($trustFile, $trustBackup) } elseif (Test-Path $trustFile) { Remove-Item $trustFile }
}
"FAILURES: $script:fail"
exit $script:fail
