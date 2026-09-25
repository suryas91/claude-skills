# The work file

Every run keeps one Markdown file in your project: `docs/work/<slug>.md`. It holds the run's whole record: the plan, every decision, every check with its evidence, what everything cost, and where the run is right now.

The run's state lives here and in git, not in the conversation, so a compacted, crashed or restarted session can carry on from this file alone.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/work-file-dark.png">
  <img alt="The top of a real work file as GitHub shows it: title, status line, goal, out of scope and acceptance criteria" src="images/work-file.png">
</picture>

*The top of test run 4's work file, as GitHub shows it. GitHub joins the three header lines (Status, Branch, Start commit) into one.*

## Sections

| Section | Written by | What goes in it |
|---|---|---|
| Header | architect and coordinator | `Status` (`planning` while the architect writes, then `planned`, then `done` or `abandoned`), the branch, and the start commit that every later check compares against |
| Direction | architect | The premises and approaches you chose from at Gate 0 (medium and large Features, and spec builds) |
| Goal, Out of scope | architect | What "done" means, and what this run deliberately won't do |
| Acceptance criteria | architect | `AC-n: <something observable> - verify by: <command or test>`. Criteria that a change replaces are marked as superseded. |
| Interfaces and contracts | architect | Routes, request and response shapes, status codes, error formats, settings, AI limits |
| Failure modes | architect | One row per thing that can go wrong: how it fails, whether it's handled, which AC tests it, what the user sees |
| File ownership | architect | Which persona owns which files. It's copied into `.claude/team/ownership.json` before each step. |
| Tasks | architect | `- [ ] T1 (persona): ... -> AC-n`, ticked when done |
| Risks and open questions | architect | What's still uncertain, and questions for you |
| Decisions | architect and coordinator | Each decision, with the alternatives rejected and why. It also records the work type, your gate answers, and the results of the architect's plan self-check. |
| Handoff | coordinator | Where the run is and what comes next. It's rewritten at every step, so a new session can resume from it. |
| Log | every persona except code-reviewer and verifier; the coordinator adds entries for personas that ran in parallel | One entry per step: date, persona, what it did, files changed |
| Tally | coordinator | Every failed check and fix round, with its cause. Review findings are written here as soon as each reviewer reports. |
| Verification | coordinator, from the verifier's and reviewers' reports | The baseline, then each check's verdict, evidence and fingerprint |
| Cost | coordinator | One row per step: persona, whether it was a fix, tokens, tool uses, duration |
| Retro | coordinator, at the end | What failed and why, cost by persona, what the checks caught |

## A real example

These excerpts come from **test run 4**. An API returned status 400 for a missing city, and the request was to return 422 instead. It's a small Change, so there's no direction stage. The excerpts are copied exactly, including their shorthand.

A few notes before reading:
- **References to other runs:** names like `weather-open-meteo AC-3` and `R2-R8` point to an earlier run's work file.
- **Who answered the gates:** this run was part of the testing, so the gates were answered by standing instructions given in advance.
- **Who wrote the plan:** in this older run the coordinator wrote the plan. Small plans are now written by the architect ([why](lessons-learned.md#what-changed-and-why)).

**Header, goal and the first acceptance criterion:**

```markdown
# Change: GET /weather returns 422 (not 400) for a missing or invalid city
Status: done
Branch: team/weather-422
Start commit: 5cc8cbb069c64649a389f519ec1f6d7097960417

## Goal
Match POST /notes validation: a missing or invalid `city` gets 422 instead of 400, with the same error bodies.

## Acceptance criteria
Supersedes weather-open-meteo AC-3's status only (400 -> 422); its bodies, order and "0 fetch calls, 0 log lines" rules still hold.
- AC-1: GET /weather with no city, `city=` or whitespace-only returns 422 `{"error":"city is required"}`; over 100 code points or control characters returns 422 `{"error":"city is invalid"}`. Still 0 fetch calls and 0 log lines. - verify by: `node --test test/weather.route.test.js test/http-guard.test.js test/server.pipes.test.js` passes; before the code change, exactly 10 tests fail (7 route, 1 guard, 2 pipes: the pipes assertion runs in the 2-case AC-24 loop).
```

**Two decisions, including a gate answer:**

```markdown
- D1 (coordinator): **Change, small.** The route works; the user wants different behaviour ("instead of 400, return 422"). One status in one file, plus tests and README; no new interfaces. The coordinator writes the plan (small path, no architect); one builder; one reviewer. Gate 1 still applies to the Change flow.
- D5 (GATE 1, 2026-09-24; answered by the coordinator per the user's standing delegation): plan approved (AC-1..AC-3, non-functional N/A). Baseline pre-existing failure: GET /notes/:id (out of scope on this branch).
```

**The Tally.** The plan check caught a flaw in the plan, and the test-engineer caught a miscount:

```markdown
## Tally
- F1: full check of plan (verifier) FAIL, coordinator (small-path plan author): same defect class as run 1 architect (a verify-by that ignores the baseline) plus missing N/A NFR lines. Fix round 1 by the coordinator.
- F2 (miss, not a failed check): the plan and the verifier plan check both counted 9 fail-before tests; test-engineer measured 10. Counting assertions without checking loops is error-prone; the executed fail-before run is the authority.
```

**Two Verification entries,** each with its evidence and fingerprint:

```markdown
- Baseline (verifier, 5cc8cbb): BASELINE RECORDED. npm test 189 tests, 188 pass, 1 fail: "GET /notes/:id returns 404 for an unknown id" (pre-existing; fixed only on team/fix-notes-404). Fingerprint: 3b7306fdb5dd9e89eb58250c7738419e6945d3a6
- Full check of builders (verifier, 8b0f34c): PASS. AC-1..AC-3 with live and in-process probes; fail-before count 10 confirmed on start-commit src; bad-URL 400 and all other mappings unchanged; test diff 4 lines (status + titles only). npm test 188/1 (baseline only). Fingerprint: e1dffd88b77f42b8fbdf82bad9d4242c644dcf8a
```

**The Handoff at the end:**

```markdown
## Handoff
- Flow: Change (small). Step: DONE. Gate 2 answered (D7): no deploy. Retro written; guard removed.
- Next actions: none. Branch team/weather-422 left unmerged; nothing pushed.
- Gates approved: Gate 1 (D5), Gate 2 (D7).
- User-owned paths: scratch/ (untouched).
- Fix rounds: plan 1/2 (resolved). Verify gate: never armed (baseline failure on this branch).
- Last fingerprint: e1dffd88b77f42b8fbdf82bad9d4242c644dcf8a. Processes: none.
```

**The Cost table:**

```markdown
## Cost
| Persona | Step | Fix round | Tokens | Tool uses | Duration |
|---|---|---|---|---|---|
| verifier | baseline + plan check | no | 66900 | 10 | 91.4 s |
| verifier | plan re-check (resume) | yes | n/a (resumed) | n/a | n/a |
| test-engineer | T1 update tests | no | 77290 | 18 | 117.6 s |
| backend-dev | T2 change | no | 70503 | 12 | 57.1 s |
| verifier | full check of builders | no | 70586 | 13 | 96.0 s |
| code-reviewer | core pass | no | 92480 | 13 | 62.7 s |
| verifier | final check | no | 60928 | 12 | 76.4 s |
```

**The start of the Retro:**

```markdown
## Retro
Process: 5f63747efc1e
KPI: failed checks 1 (plan check, coordinator-authored plan) | fix rounds 1 | BLOCKER/MAJOR 0 (refuted 0) | defects found after review 0 | user corrections at gates 0 (delegated) | persona calls 8 (one a resume) | subagent tokens about 439k (resume counted once) | agent time about 9 min
```

## Reading a work file

- **Where is the run now?** Read the Handoff.
- **Why was something done this way?** Read the Decisions. Superseded decisions stay visible.
- **Can I trust the result?** Read Verification from the bottom up. The last final check should say PASS, cover every AC, and carry the same fingerprint as the last review.
- **What went wrong along the way?** Read the Tally.
- **Was it worth it?** Read the Cost table and the Retro.
