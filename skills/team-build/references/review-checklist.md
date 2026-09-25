# Review checklist

Used by code-reviewer. Adapted from gstack's `/review` checklist and specialist checklists (MIT, © 2026 Garry Tan, https://github.com/garrytan/gstack). Additions from the 2026-09-24 audit of gstack, ruflo and claude-skills are listed in NOTICE.md.

Work through the **core pass** on every review. When your task names a **lens**, also go deep on that lens section. When no lens is named, skim every lens section that matches the diff (for example the migration lens only when there are migrations). For AI features, also check the diff against `ai-feature-standards.md`.

## Core pass: critical (check every diff)

### Data safety
- String-built SQL, even with "safe" values. Use parameterized queries or the ORM (Prisma raw queries, SQLAlchemy `text()` with f-strings, Node template strings).
- Check-then-write (TOCTOU): `find` then `create`, or `read status` then `update status`, without a unique constraint or an atomic `UPDATE ... WHERE status = <old>`. Concurrent requests create duplicates or skip transitions.
- find-or-create without a unique DB index.
- Writes that bypass model validation (raw updates, `QuerySet.update()`, Prisma `$executeRaw`).
- **Mass assignment through spread order:** `{...serverSet, ...req.body}` or `Object.assign(record, input)` lets the caller overwrite id, owner, role, author, price or timestamps. Whitelist fields.
- Unsafe HTML rendering of user or model content: `dangerouslySetInnerHTML`, `v-html`, `innerHTML`, `|safe`.

### Wired and enforced (requires reading outside the diff)
AI-written code often builds things that nothing uses. For every new function, config option, flag, env var, validator, guard, event or field in the diff, grep for a **non-test reader or caller on the real entry path**.
- An option that's parsed but never consumed, a validator that's exported but never called, or an event nobody listens to.
- A limit, budget, retry count, TTL or cap that's reset or bypassed on some path (for example, a retry counter reset on re-queue retries forever).
- A computed value that's thrown away.
- A check that writes the signal it checks (a health check that refreshes its own heartbeat).
- A security control that's declared, configured or shown in the UI ("verified", checksum, permission prompt) but not enforced on the real path: **MAJOR**.
- A fallback (mock or stub, keyword-only search, cached answer, empty `catch` that switches implementation) that isn't visible in logs or the response, or that still reports the real backend's name.

### LLM output trust boundary
- Model-generated values (emails, URLs, names, IDs, enum values) written to the DB, sent to mailers or used in queries without format validation.
- Tool-use or JSON output accepted without runtime schema validation before it's used. A TypeScript cast on tool arguments (`args.id as number`) is not validation.
- Model-generated URLs fetched without an allowlist (SSRF); model-produced links or images rendered from untrusted domains (exfiltration).
- Model output stored in a knowledge base or vector store without sanitizing (stored prompt injection).
- `eval`/`exec`, or shell commands built from model output. Model-generated SQL run under anything but a read-only role with a timeout and row limit. A keyword denylist is not a control.
- Prompt text that lists tools or capabilities that don't match the tools actually wired up. Tool descriptions that are near-duplicates, very short, or give no "use when / not when" guidance.
- An agent loop that returns partial or budget-exhausted output as success.
- 0-indexed lists in prompts (models reliably answer 1-indexed). Word or token limits stated in more than one place that can drift apart.
- Quoted or extracted spans from a model that aren't checked against the source.

### Shell and code injection
- `subprocess` with `shell=True` plus interpolation, `os.system` with variables, Node `exec` with template strings. Use argument arrays.
- **Argument arrays stop shell injection but not option injection.** Where user or model input becomes an argv element (`execFile('git', [input])`, `subprocess.run([...])`), a value like `--upload-pack=...` or `-oProxyCommand=...` becomes an option. Require `--` before it, or reject values starting with `-`.
- `new Function(...)`, or string-form `setTimeout`/`setInterval`, with input.
- Env vars or package names from user or model input passed to child processes. Allowlist env keys, and never pass `NODE_OPTIONS`, `LD_*` or `DYLD_*`.

### Enum and value completeness (requires reading outside the diff)
When the diff adds an enum value, status, role, tier, event type or union member:
- Grep for the sibling values and **read** every consumer: switch/case and if-chains, allowlists and filter arrays, display maps, DB check constraints, frontend dropdowns, API validators, analytics.
- Flag any consumer that doesn't handle the new value or falls through to a wrong default. The classic miss: the frontend offers the value and the backend never persists it.

### Sibling divergence
When the diff adds or changes one of several parallel functions, handlers or branches (CRUD handlers, per-provider adapters, per-role paths), compare it with its siblings. An asymmetry (a missing auth check, validation or reciprocal update) is a likely bug. Cite the sibling line.

## Core pass: informational

- **Scope drift:** changed lines that trace to no task or AC in the work file (reformatting, comment churn, renames, "while I'm here" refactors or features). Report as MINOR naming the lines, or MAJOR if they change behaviour. Also flag **silent interpretation**: code that picks one reading of an ambiguous AC without a record in Decisions. Route that to the architect.
- **Dependency and config parity:** each new import is declared in the owning manifest (package.json, pyproject), not just reachable through a transitive dependency or workspace hoisting. Each env var the diff reads (`process.env.X`, `os.environ[...]`, `os.getenv(...)`) is in `.env.example` and CLAUDE.md. MAJOR if it breaks a clean install or deploy.
- **Leftover scaffolding in non-test code:** mock or fake data (`Promise.resolve(mockData)`, `setTimeout(() => resolve(data))`, faker imports), `throw new Error('not implemented')`, TODO/FIXME on auth, validation or security, hardcoded `localhost` or `example.com`, `console.log` debugging.
- **Architecture decisions:** a diff that contradicts an Accepted ADR in `docs/adr/`, or cites a superseded one. MAJOR, route to the architect.
- **Async/sync mixing:** blocking I/O (`requests`, `open`, sync DB calls, `time.sleep`) inside `async def` or Node request handlers. Also un-awaited promises, `async` callbacks passed to `forEach`, and timers or subscriptions not cleared on unmount.
- **Field-name safety:** column and field names in queries and `.select()` checked against the real schema; wrong names silently return empty results.
- **Time windows:** "today" keys that assume a full 24h, timezone-naive dates, related features bucketing the same data differently.
- **Type coercion at boundaries:** values crossing JSON, forms, query strings or env vars (number vs string, `"false"` is truthy). Inputs to hashes or cache keys not normalized.
- **Frontend:** O(n*m) lookups in render, filtering in the client what a query could filter, unstable references causing re-renders, missing loading, empty or error states.
- **Conditional side effects:** one branch updates related state, emits an event or logs "done" and the other branch forgets to.
- **Completeness gaps:** partial enum handling, missing error paths, or negative-path tests that mirror an existing happy-path test, when the complete version is small. Report them as MINOR unless they break an AC.
- **Documentation staleness:** a doc file (README, CLAUDE.md, docs/, API docs, `.env.example`) describes behavior this diff changed, and the doc wasn't updated. Report as MINOR with the doc path. A number in a doc or README (speedup, latency, coverage, eval pass rate) with no command or run behind it is also MINOR.
- **CI and release:** workflow changes with wrong tool versions or artifact paths, and secrets hardcoded instead of `${{ secrets.X }}`. Also:
  - `${{ github.event.* }}` (titles, bodies, labels, branch names) interpolated directly into `run:` is script injection: pass it through `env:` and quote it.
  - `pull_request_target` or `workflow_run` workflows must not check out or run PR code with secrets in scope.
  - Workflows need least-privilege `permissions:`, with read as the default.
  - Third-party actions should be pinned to a SHA.
  - Publish steps must be safe to re-run.
- **New dependencies:** licence (AGPL, GPL or SSPL in a proprietary or hosted app), maintenance status and size. When package.json or a lockfile changes, run the stack's audit read-only (`npm audit --omit=dev`; `pip-audit` if Python is present, otherwise UNVERIFIED) and report new high or critical advisories.

## Lenses (deep passes)

### security
- Endpoints missing authentication; authorization that defaults to allow; user A reaching user B's data by changing an ID (IDOR); users able to change their own role. IDOR claims are checked with **two users**.
- Input accepted at the boundary without schema validation (Zod, Pydantic); file uploads without type or size limits.
- **Webhooks:** a signature check alone isn't enough. Also check the timestamp or replay window, idempotency (the same event processed twice), and whether a forged or replayed event changes money, ownership or access.
- Injection beyond SQL: command, argument/option, template, path traversal, header injection, SSRF through user-controlled URLs.
- **Prototype pollution:** deep merge, `Object.assign` or `lodash.merge` of user JSON without guarding `__proto__`, `constructor` and `prototype`.
- **Cross-user cache bleed:** a server memo cache, framework data cache (`unstable_cache`, fetch cache), Redis or a CDN rule keyed without the user, tenant or auth scope for per-user data. **Tenant or scope identity taken from request input** instead of the validated token or session.
- **Credential selection:** `req.headers.authorization || process.env.SERVER_KEY` chains forward the caller's token upstream or silently upgrade to the server key.
- **Auth config:** OAuth or JWT verification without an audience or issuer check accepts other apps' tokens. A token that fails verification must get a 401, never be treated as anonymous. Secrets generated at startup when missing create an unaudited identity. Insecure config combinations should fail at boot.
- Crypto misuse: `Math.random` or `random` for tokens, `==` on secrets (use constant-time compare), weak hashes, hardcoded keys.
- Secrets in code, logs, error responses or URLs; PII logged or returned. A secret removed from a later commit is still in git history and still needs rotating.
- Unsafe deserialization (`pickle`, `yaml.load`).
- **AI features:** prompt injection from user input, retrieved documents or tool results into privileged tools; API keys reachable from the browser; model-calling endpoints without per-user or per-IP rate limits and quotas (cost DoS); one request that can trigger unbounded paid model or tool calls; one user's stored content steering another user's agent. See `ai-feature-standards.md` §2-3. For model text shown to users, probe the output checks with:
  - `.Buy`, `。`, `." Buy`, `.; Buy` and `.💰 Buy` (a second sentence);
  - U+2028 and a lone surrogate (invisible characters);
  - a bare `example.com` (a link);
  - a combining mark such as U+FE0F placed right after the dot, in both a domain and a second sentence.

  Then sweep every code point after the stop, not just these samples. Each of these got past a checker built on simple regexes in the smoke runs.
- **Per-IP limiters:** a key taken straight from the socket address lets one IPv6 holder use many keys. Key IPv6 by /64, and treat IPv4-mapped `::ffff:a.b.c.d` as its IPv4. A bounded map that refuses every new key when full can be filled, and then it locks everyone out.
- **Redirects on keyed calls:** any outbound fetch that sends a key or token sets `redirect: 'error'` (or `'manual'` with a check). fetch strips only `Authorization` on a cross-origin redirect, so `x-api-key` and other custom headers go to the redirect target.
- **A partial fix is a blocker.** For a fix to a security or integrity threat, list the equivalent paths to the same outcome (other endpoints, other roles, create vs update, direct vs indirect). Any path left open is MAJOR, even if the report discloses it.
- For each security finding, state the **entrypoint**, the **boundary crossed** and the **impact**. After confirming one, grep for the same root cause elsewhere in the diff and in its callers.
- **MCP servers and agent tool endpoints:** when the diff adds an MCP server, an agent tool endpoint or a new third-party MCP server, also run `mcp-checklist.md` (same folder) and report each failed item.

### testing
- New error branches, guard clauses and early returns with no failing-path test.
- Tests that can't fail: assertions on "renders" or "doesn't throw", mocks that assert on themselves, snapshot-only coverage of logic.
- **Test honesty:** existing tests or assertions deleted, loosened (an exact value changed to `toBeGreaterThanOrEqual`, a regex widened) or re-thresholded in the same diff that changes the code under test; new `.skip`, `xit`, `test.todo` or `@pytest.mark.skip` without a reason and owner; `test.only` committed; fakes that accept any input (a mock `get()` that returns a hit for any id); production code returning hardcoded success, scores or metrics (a "benchmark" built from `sleep`).
- ACs in the work file without a test, or tests named for an AC that don't exercise it.
- Flaky patterns: sleeps, `networkidle`, order dependence, shared state, real network in unit tests, clock or timezone dependence, assertions on the order of unordered results.
- Existing tests that only cover the old behaviour of a changed function.
- **Revert the fix:** for each fix-round commit in the diff, revert that fix in a scratch copy and run the tests. If nothing fails, the fix has no test behind it: report it as **MAJOR** (a vacuous guard). A common cause is a fake or blocked network that fails within microtasks, so no call is ever still in flight at shutdown, EOF or EPIPE.
- AI features: no fixture-based tests for malformed, truncated or refused model output; eval changes that break `ai-feature-standards.md` §1. **Fixture-mode evals must require 100% of cases**, because fixture runs are deterministic. A threshold below 100% only lets a deleted guardrail pass. Fractional thresholds belong to live runs.
- Playwright tests: check against `playwright-testing` (role-based locators, web-first assertions, no `waitForTimeout`).

### performance
- N+1 queries (loops over ORM relations without `include`, `joinedload` or batching).
- New WHERE, ORDER BY or foreign-key columns without an index.
- Unbounded list endpoints or queries (no LIMIT or pagination).
- O(n²) work, repeated linear scans where a Map or Set fits.
- **Process memory:** module-level Maps, arrays or caches in servers or workers that grow per request or session with no cap, TTL or eviction; `shift()` eviction in hot paths.
- Frontend: request waterfalls that could be `Promise.all` or server-side, heavy new dependencies, barrel imports, missing code splitting, unoptimized images.
- Unbounded loops or model calls; missing timeouts on external calls. Streaming endpoints that don't release resources and cancel the upstream model stream when the client disconnects (tokens keep billing).

### api-contract
- Breaking changes: removed or renamed response fields, changed types or status codes, new required params, changed auth requirements.
- Error responses that don't match the project's agreed error shape, or leak stack traces or SQL.
- Frontend and backend disagreeing on field names, types or error handling (compare both sides against the work file's contract).
- **Tool and MCP wrappers** whose argument or field mapping has drifted from the API they wrap. Each wrapper should be called in a test.
- OpenAPI, typed clients or docs not updated.

### data-migration
- Migration not reversible, or the rollback breaks currently running code.
- Data-loss risk: dropping populated columns, narrowing types, NOT NULL on columns with existing NULLs without a backfill. Backfills of large tables not done in batches.
- Before dropping or renaming a column or storage location, grep **every reader and writer**. Readers and writers that disagree about where data lives is a classic bug, and fixing one side can unmask a latent bug in the other.
- Long locks: index creation without `CONCURRENTLY` (Postgres) on large tables, multiple ALTERs on a hot table.
- Deploy ordering: new schema with old code (or the reverse) crashes during a rolling deploy.

### red-team (run last)
Your task gives you the **locations and invariants** the other reviewers examined, not their conclusions, so you aren't anchored on what they decided. Your job is what they missed. Think like an attacker, a chaos engineer and a hostile QA tester:
- 10x load; two requests for the same resource at once; a double click within 100ms.
- A slow database (over 5s), an external service returning garbage, a model returning malformed JSON or refusing.
- Silent failures: swallowed exceptions, partial completion (3 of 5 items, then a crash), records left in inconsistent states, background jobs failing without alerting.
- **Recorded defect classes that capable reviewers miss:**
  - Stale cache fill after invalidation: a read in flight while a write deletes the key re-fills the cache with the old value. The fix is a generation or version check before `set`; re-checking `get() === undefined` does not fix it.
  - A secondary side effect (cache delete, event, email) that throws after the primary write committed. The caller sees an error and retries, causing a double write.
  - Composite keys built by joining strings (`${tenant}:${id}` where IDs can contain `:`). Use a structured key.
  - A timeout on a call with external side effects (payment, email) means **outcome unknown**, not failed. Reconcile with the same idempotency key, never start a fresh attempt.
  - A single-flight or in-flight map entry not cleared on failure, so later callers hang or keep getting the error.
  - Both completion orders of overlapping awaits on shared state, unless a named mechanism prevents one of them.
  - A throw before or outside the handler's error handling (URL, header or body parsing, middleware) or inside the error handler itself. In Node, an async request handler that rejects can end the whole process: one malformed request line takes the server down.
  - Validate-then-reread of an untrusted object: code validates a value from an injected source, then reads the same object again to build output. Getters or a Proxy can return something different on the second read. Validate one copy and send that copy.
  - Headers written before the body is serialised: a serialisation error makes the catch-all try to write headers a second time.
  - Per-IP limiter lockout: flood one IPv6 /64 (or /48) with distinct addresses until a bounded fail-closed map is full, then check that a new client is still served.
  - A keyed outbound call that follows a redirect: point it at a local stub that answers 307 to a second origin, and check whether the key arrives there.
- **Live-server crash probe:** for any change to a server, start the real entry point on a free port (stop it by PID afterwards). Send a raw malformed request line, an invalid URL, an oversized header and invalid JSON, then a normal request. The process must survive and still answer.
- Trust assumptions: validated on the frontend but not the backend, "internal" endpoints without auth, config assumed present.
- Error handling: flag catch-alls on data paths, and branching on error-message text. Don't flag catch-alls in best-effort cleanup or fire-and-forget telemetry. Do flag a cleanup step that throws and stops the rest of the cleanup.
- Edges: maximum input size, empty, null, first run with no data, lone Unicode surrogates in text sent to a model API (they cause 400s).
- Gaps between the other lenses and at integration boundaries.

## Rules for every finding

**Quote the line.** Every finding quotes the code that triggered it, verbatim, with `path:line`. A finding without a quote is capped at confidence 4, and so dropped. For symbols generated by an ORM, a decorator or codegen, quote the schema or decorator that defines them, not a failed grep.

**Prove every claim.**
- "This is safe" must cite the line that makes it safe.
- "Handled elsewhere" must cite the handling code.
- "Tests cover this" must name the test.
- Never write "likely handled" or "probably tested". Verify it, or report it as unverified.
- "Looks fine" is not a finding. "No issues" states what was examined.

**Confidence.** Give each finding a confidence from 1-10. Drop findings below 5. Mark 5-6 as "medium confidence, verify".

**Fingerprint.** Give each finding a fingerprint `path:line:category`, so the coordinator can merge findings across parallel reviewers.

**Optional test.** Where cheap, give a one-line test that would catch the bug.

## Do not flag
- Harmless redundancy that aids readability.
- "Add a comment explaining this threshold": thresholds change and comments rot.
- "This assertion could be tighter" when it already covers the behavior.
- Consistency-only changes with no behavioral effect.
- Edge cases in regexes or parsers whose input is constrained so that the case can't occur.
- Tests that exercise several guards at once.
- Harmless no-ops.
- Style the linter already enforces.
- Debt the user explicitly accepted at a gate, when the work file's Decisions records it.
- Anything the diff already addresses. Read the FULL diff before commenting.
