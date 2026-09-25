# The work file

Every run keeps one Markdown file in your project: `docs/work/<slug>.md`. It holds the run's whole record: the plan, every decision, every check with its evidence, what everything cost, and where the run is right now.

The run's state lives here and in git, not in the conversation. A compacted, crashed or restarted session can carry on from this file alone.

![The top of a real work file, as GitHub shows it](images/work-file.png)

*The top of the work file from test run 4, as GitHub renders it.*

## Sections

| Section | Written by | What goes in it |
|---|---|---|
| Header | architect and coordinator | `Status` (`planning` while the architect writes, then `planned`, then `done` or `abandoned`), the branch, and the start commit that every later check compares against |
| Direction | architect | The premises and approaches you chose from at Gate 0 (medium and large Features, and spec builds) |
| Goal, Out of scope | architect | What "done" means, and what this run deliberately won't do |
| Acceptance criteria | architect | `AC-n: <something observable> - verify by: <command or test>`. A superseded criterion is struck through, not deleted. |
| Interfaces and contracts | architect | Routes, request and response shapes, status codes, error formats, settings, AI limits |
| Failure modes | architect | One row per thing that can go wrong: how it fails, whether it's handled, which AC tests it, what the user sees |
| File ownership | architect | Which persona owns which files. It's copied into `.claude/team/ownership.json` before each step. |
| Tasks | architect | `- [ ] T1 (persona): ... -> AC-n`, ticked when done |
| Risks and open questions | architect | What's still uncertain, and questions for you |
| Decisions | architect and coordinator | Each decision, with the alternatives rejected and why. Also the work type, your gate answers, and the results of the architect's plan self-check. |
| Handoff | coordinator | Where the run is and what comes next. Rewritten at every step, so a new session can resume from it. |
| Log | every persona except code-reviewer and verifier (the coordinator adds entries for personas that ran in parallel) | One entry per step: date, persona, what it did, files changed |
| Tally | coordinator | Every failed check and fix round, with its cause. Review findings are written here as soon as each reviewer reports. |
| Verification | coordinator, from the verifier's and reviewers' reports | The baseline, then each check's verdict, evidence and fingerprint |
| Cost | coordinator | One row per step: persona, whether it was a fix, tokens, tool uses, duration |
| Retro | coordinator, at the end | What failed and why, cost by persona, what the checks caught |

## A real example

These excerpts come from **test run 4**: an API returned status 400 for a missing city, and the request was to return 422 instead. It's a small Change, so there is no direction stage. In this older run the coordinator wrote the plan itself; small plans are now written by the architect ([why](lessons-learned.md#what-changed-and-why)).

**Header, goal and an acceptance criterion:**

```markdown
# Change: GET /weather returns 422 (not 400) for a missing or invalid city
Status: done
Branch: team/weather-422
Start commit: 5cc8cbb069c64649a389f519ec1f6d7097960417

## Goal
Match POST /notes validation: a missing or invalid `city` gets 422 instead of 400, with the same
error bodies.

## Acceptance criteria
- AC-1: GET /weather with no city, `city=` or whitespace-only returns 422 `{"error":"city is required"}`;
  over 100 code points or control characters returns 422 `{"error":"city is invalid"}`. Still 0 fetch
  calls and 0 log lines. - verify by: `node --test test/weather.route.test.js …` passes; before the
  code change, exactly 10 tests fail.
```

**Decisions, including a gate answer:**

```markdown
- D1 (coordinator): **Change, small.** The route works; the user wants different behavior ("instead of
  400, return 422"). One status in one file, plus tests and README; no new interfaces. …
- D5 (GATE 1): plan approved (AC-1..AC-3, non-functional N/A). Baseline pre-existing failure:
  GET /notes/:id (out of scope on this branch).
```

**The Tally, recording what went wrong.** The plan check caught a flaw in the plan, and the tests caught a miscount:

```markdown
- F1: full check of plan (verifier) FAIL, coordinator (small-path plan author): … a verify-by that
  ignores the baseline … Fix round 1 by the coordinator.
- F2 (miss, not a failed check): the plan and the verifier plan check both counted 9 fail-before
  tests; test-engineer measured 10. … the executed fail-before run is the authority.
```

**Verification, each verdict with its fingerprint:**

```markdown
- Baseline (verifier, 5cc8cbb): BASELINE RECORDED. npm test 189 tests, 188 pass, 1 fail:
  "GET /notes/:id returns 404 for an unknown id" (pre-existing …).
- Full check of builders (verifier, 8b0f34c): PASS. … fail-before count 10 confirmed on start-commit
  src; bad-URL 400 and all other mappings unchanged … Fingerprint: e1dffd88…
- Final check (verifier, 3286683): PASS. … Fingerprint: e1dffd88… (matches core pass …)
```

**The Handoff at the end:**

```markdown
## Handoff
- Flow: Change (small). Step: DONE. Gate 2 answered (D7): no deploy. Retro written; guard removed.
- Next actions: none. Branch team/weather-422 left unmerged; nothing pushed.
- Gates approved: Gate 1 (D5), Gate 2 (D7).
- Fix rounds: plan 1/2 (resolved). Verify gate: never armed (baseline failure on this branch).
- Last fingerprint: e1dffd88b77f42b8fbdf82bad9d4242c644dcf8a. Processes: none.
```

**Cost, one row per step:**

```markdown
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
KPI: failed checks 1 (plan check, coordinator-authored plan) | fix rounds 1 | BLOCKER/MAJOR 0 |
defects found after review 0 | user corrections at gates 0 | persona calls 8 |
subagent tokens about 439k | agent time about 9 min
```

## Reading a work file

- **Where is the run now?** Read the Handoff.
- **Why was something done this way?** Read the Decisions. Superseded decisions stay visible.
- **Can I trust the result?** Read Verification from the bottom up. The last final check should say PASS, cover every AC, and carry the same fingerprint as the last review.
- **What went wrong along the way?** Read the Tally.
- **Was it worth it?** Read the Cost table and the Retro.
