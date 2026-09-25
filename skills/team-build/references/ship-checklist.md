# Ship checklist

devops runs this **read-only** over the whole repo, not only the diff. The coordinator asks for it before a project's first production deploy, and again when auth, model-calling endpoints or deploy config change. Adapted from the ship-gate skill in claude-skills (MIT); see NOTICE.md.

Run the greps from the project root in Git Bash. Each one excludes dependency and build folders:
`X='--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=.venv'`

Report every item as PASS, FAIL (with file:line) or N/A (with the reason). A grep hit is a lead, not a verdict: read the line before calling it a FAIL. CRITICAL and HIGH failures block the deploy. The coordinator routes them to the file's owner. ADVISORY items are listed at Gate 2.

## CRITICAL
- **C1 `.env` files in git history** (they stay exposed after deletion, and any secret in them needs rotating): `git log --all --name-only --diff-filter=A --format= | grep -E '(^|/)\.env($|\.)' | grep -v '\.env\.example$'`
- **C2 Secrets in tracked files** (`secret-scan.ps1` only sees staged diffs, so this checks the whole tree). The `cut` keeps only file:line, so values are never printed: `git ls-files -z | xargs -0 grep -HnIE 'sk-ant-[A-Za-z0-9_-]{20,}|sk-(proj-)?[A-Za-z0-9_-]{32,}|(AKIA|ASIA)[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36}|github_pat_|xox[baprs]-|(sk|rk)_live_|AIza[0-9A-Za-z_-]{35}|BEGIN ([A-Z]+ )?PRIVATE KEY|://[^:/ @]+:[^@/ ]+@' | cut -d: -f1,2`. Report each file:line and the kind of secret.
- **C3 Auth or security TODOs:** `grep -rnEi $X '(TODO|FIXME|HACK|XXX).*(auth|security|permission|validation|sanitiz)' .`
- **C4 Model-calling endpoints without per-user or per-IP rate limits and a spend cap** (cost denial of service). Find the model calls (`grep -rnE $X 'anthropic|messages\.create|openai' --include=*.{ts,tsx,js,py} .`), then check that each route reaching one has a limiter and a cap.
- **C5 Debug or admin routes reachable in production** without auth: `grep -rnEi $X '(/debug|/admin|/internal|/test)[\x27"/]' --include=*.{ts,tsx,js,py} .`

## HIGH
- **H1 CORS wildcard:** `grep -rnE $X "(Access-Control-Allow-Origin['\"]?\s*[:,]\s*['\"]\*|origin:\s*['\"]\*|allow_origins=\[['\"]\*)" .`
- **H2 No Content-Security-Policy** for a site serving HTML: `grep -rnEi $X 'content-security-policy|helmet\(' .`. No hit means FAIL, unless the host config sets it (check `vercel.json`, `netlify.toml`, `_headers`, nginx config).
- **H3 Cookie flags:** session cookies set without `HttpOnly`, `Secure` and `SameSite`: `grep -rnEi $X 'set-cookie|cookies\(\)\.set|res\.cookie\(|set_cookie\(' .`, then read each hit.
- **H4 Lockfile committed and not ignored:** `git ls-files | grep -E '(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb|poetry\.lock|uv\.lock)$'` should print one, and `grep -nE 'lock' .gitignore` should not ignore it.
- **H5 Install scripts in dependencies:** `grep -nE '"(pre|post)?install"' package.json`, and for a lockfile v3, `grep -c '"hasInstallScript": true' package-lock.json`. List each package with an install script.
- **H6 Known vulnerable dependencies:** `npm audit --omit=dev --audit-level=high` or `pip-audit`. Report the counts by severity.
- **H7 Error pages leak internals:** stack traces, SQL or file paths in error responses. Check the error handler and, for Next.js, that `app/error.tsx` or `pages/_error` exists.
- **H8 Model output rendered as HTML** without sanitising: `grep -rnE $X 'dangerouslySetInnerHTML|v-html|innerHTML\s*=' .`

## ADVISORY
- **A1** A health endpoint exists and is cheap.
- **A2** Every env var the code reads is in `.env.example` (compare `grep -rhoE $X 'process\.env\.[A-Z_0-9]+|os\.environ\[.[A-Z_0-9]+|os\.getenv\(.[A-Z_0-9]+' .` with `.env.example`).
- **A3** Structured logs and an error tracker are wired up. Logs contain no tokens or personal data.
- **A4** For AI features: token-usage and latency metrics, plus a spend alert.

## Manual items (the user answers each one at Gate 2)
- **M1** A backup **restore** has been tested, not just the backup.
- **M2** The rollback steps are written down and someone can run them.
- **M3** The change passed on staging or a preview environment first.
- **M4** Production secrets are in the platform's secret store, and any secret found by C1 or C2 has been rotated.
- **M5** DNS, OAuth redirect URLs and third-party dashboard settings match production.
