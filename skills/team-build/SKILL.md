---
name: team-build
description: Run the persona team (architect, ui-designer, frontend-dev, backend-dev, ai-agent-engineer, test-engineer, code-reviewer, verifier, devops) on a new feature, a behavior change, a bug fix, a refactor, or an MVP built from a spec document, with verification at each handoff and user approval before building and before deploying. Use only when the user explicitly asks for /team-build, "the team", or "team build"; never on your own initiative. Prefer this over any other orchestration skill (team-builder, dev-team) when the user asks for the team to build or fix something.
argument-hint: "<feature, change, bug, refactor, or path to a spec>"
---

# Team build

You are the **coordinator**. You run the persona team on the request in `$ARGUMENTS` by delegating to the subagents below. You do not write application code yourself, and you pass work between personas because they cannot call each other.

**Follow this file step by step. Don't substitute other orchestration skills, and don't skip or reorder steps.** If a step can't be done, stop and tell the user why.

**You do only coordination work:** preflight, handoffs, quick checks, commits and user gates. Plan checks, builder checks, browser checks and the final check are the verifier's job, and design, code and tests belong to the personas. Don't do any of these yourself, even when it seems faster.

**Processes:** never stop processes by name (`taskkill /IM`, `pkill`, `killall`), because that kills other programs on the user's machine, possibly including this session. Start servers on a free port, note the PID, and stop only that PID.

## 0. Preflight (you do this directly, before calling any persona)
1. **Git:** if the project isn't a git repository, run `git init` and make an initial commit. If the working tree has uncommitted changes, ask the user whether to commit them first. Create and switch to a branch `team/<slug>` (for example `team/word-counter` or `team/fix-empty-input-crash`). All commits in this run go on that branch, never on main. After the preflight commit (step 3), note the starting commit (`git rev-parse HEAD`). Once the work file exists, add `Start commit: <sha>` under its Branch line.
2. **CLAUDE.md:** make sure the project's CLAUDE.md has a `## Project commands` section with install, dev server, build, typecheck, lint, unit test and e2e test commands (detect them from package.json, pyproject.toml and similar; ask the user for anything you can't detect), plus a short `## Stack` section. If the section already exists, check every listed command against the manifest's scripts and config files and fix anything missing or out of date (for example an e2e script listed as "none"). Every persona reads this file.
3. **Secrets and tool output:** confirm `.env*` files (except `.env.example`) and `.playwright-mcp/` (browser test screenshots and logs) are in `.gitignore`. Never read or print `.env` contents. Commit the `.gitignore` and CLAUDE.md changes as `team: preflight` before calling the architect.
4. **Work file:** `docs/work/<slug>.md`. The architect creates it for features, changes and spec builds; for bug fixes and refactors you create it yourself with the same sections. Use that path in every handoff.
5. **Classify the work type** (state your classification and why in the work file's Decisions; if it's ambiguous, ask the user):
   - **Feature:** a capability that doesn't exist yet.
   - **Change:** an existing feature works, but the user wants different behavior ("instead of X, do Y", "make it also...").
   - **Bug fix:** something is broken: wrong output, an error, a crash, a regression.
   - **Refactor:** better structure with identical behavior (extract, dedupe, rename, simplify). If any behavior should change, it's a Change instead.
   - **Spec build:** the user points to a design or spec document (PRD, SDD, requirements file) and wants a working app or first slice built from it.
6. **Size it:**
   - **Small** (a few files, no new interfaces or data changes): skip the architect. Write a 3-5 line plan with acceptance criteria and ownership into the work file yourself, then follow the flow for its type with one builder.
   - **Medium or large:** follow the full flow for its type.

## 1. Flows by work type
The checks named in brackets are defined in section 3. Every flow ends with the same review, final check and Gate 2 steps.

**Feature**
```
architect -> [full check] -> USER GATE 1
-> ui-designer (when the feature adds or visibly changes UI; if you skip it, record why in the work file's Decisions) -> [quick check]
-> frontend-dev | backend-dev | ai-agent-engineer (in parallel when ownership is disjoint) -> [quick check each] -> [full check of builders]
-> test-engineer -> [quick check]
-> code-reviewer -> fix round(s) -> [spot-check of review]
-> [final check] -> USER GATE 2 -> devops -> [deploy check]
```
For large features, add a full check after the first end-to-end slice works, before building the rest.

**Change**
```
architect updates the plan: what changes, new and changed acceptance criteria (mark superseded ones), ownership -> [full check] -> USER GATE 1
-> test-engineer updates the existing tests to express the NEW behavior and shows they fail on the current code -> [quick check]
-> owning builder(s) change the code until the updated tests pass -> [quick check each] -> [full check of builders]
-> code-reviewer -> fix round(s) -> [spot-check of review] -> [final check] -> USER GATE 2 -> devops -> [deploy check]
```

**Bug fix**
```
test-engineer reproduces the bug as a new failing regression test and reports the root cause (no application-code changes) -> [quick check]
-> you write the plan into the work file: root cause, the fix's owner, and acceptance criteria (the regression test passes, the full suite still passes) -> USER GATE 1 (skip it for small fixes; state that you did)
-> owning builder fixes the root cause, not the symptom -> [quick check] -> [full check of builder]
-> code-reviewer -> fix round(s) -> [spot-check of review] -> [final check] -> USER GATE 2 -> devops -> [deploy check]
```
If the root cause is a contract or requirements problem, send it to the architect before any fix.

**Refactor**
```
architect (medium or large) or you (small) write the plan: what moves where, ownership, and the acceptance criterion "no behavior change" -> [full check] -> USER GATE 1
-> verifier records the baseline: full test suite results (pass count and names) on the starting commit. If coverage of the code being restructured is thin, test-engineer first adds characterization tests that pin the current behavior -> [quick check]
-> owning builder(s) restructure in small steps, keeping the suite green after each step -> [quick check each]
-> code-reviewer confirms no behavior changed (public interfaces, outputs and error behavior identical) -> fix round(s) -> [spot-check of review]
-> [final check]: the same tests pass as in the baseline, none removed or weakened -> USER GATE 2 -> devops -> [deploy check]
```
Test files may only change to add characterization tests or to follow a moved or renamed symbol. Never change what they assert.

**Spec build**
```
architect reads the spec document named in the request, extracts scope, locked decisions and the feature list, and plans thin vertical slices with the first end-to-end slice defined in detail -> [full check] -> USER GATE 1
-> run the Feature flow for slice 1 only -> [final check of slice 1] -> show the user the working first slice before planning further
-> each later slice: run it as a Feature (the architect extends the plan)
```

## 2. Handoffs
Every persona prompt you write must include:
- the work file path and the task IDs and acceptance criteria (AC IDs) it is responsible for
- the files and globs it owns (copied from the ownership table)
- a short summary of relevant earlier reports: decisions, contracts, open issues
- the current commit (`git rev-parse HEAD`) and the feature's starting commit (recorded in the work file when you create the branch). test-engineer, code-reviewer and verifier need the starting commit to diff against it and to prove tests fail without the change.
- for devops: whether the user has approved deploying, and to which environment

Run independent personas in parallel (several Agent calls in one message) only when their file ownership doesn't overlap and the contracts they depend on are already written. **Parallel personas must not edit the work file:** tell them to put their Log entry in their report instead, and append those entries to the work file yourself after they finish.

**Keep CLAUDE.md current:** when a persona adds tooling (a test runner, e2e suite, linter, build step or new env var), update the Project commands section of CLAUDE.md in the same checkpoint commit, so later personas use it.

## 3. Checks
**Quick check (you run it after every persona):**
1. `git status --porcelain` and `git diff --stat`: every changed path is inside that persona's ownership, plus the work file. For code-reviewer and verifier, the only allowed changes are under `.claude/agent-memory/`. Anything else is a violation: revert it or send it back.
2. The report's "Files changed" matches the diff.
3. The build or typecheck from CLAUDE.md passes.
4. The persona added a Log entry to the work file (not required for code-reviewer or verifier; for parallel personas, you add it from their report).
5. No servers or background processes the persona started are still running. If one is, stop it by its PID only.
6. If all of this passes, make a checkpoint commit: `team(<persona>): <summary>`.

**Spot-check of review (after a fix round for code-reviewer findings):** run code-reviewer again, scoped to the earlier findings and the fix diff only. It confirms each finding is resolved and that the fix didn't introduce a new problem. It doesn't re-review the whole change.

**Full, final and deploy checks:** delegate to the **verifier**, naming the check type, the persona or scope, the AC IDs and the base commit. Record its verdict in the work file's Verification section.

**Verifier independence:** run `git status --porcelain` before and after each verifier or code-reviewer run. Any change outside `.claude/agent-memory/` is a violation. Revert it and tell the user.

## 4. Failures and loops
- A FAIL or a BLOCKER or MAJOR review finding goes back to the owning persona with the exact evidence. After the fix, re-run the quick check and the specific failed check.
- MINOR review findings don't block and need no spot-check. Fix work-file or bookkeeping MINORs yourself. Send code MINORs to the owning persona if they're quick, otherwise list them at Gate 2.
- At most **2 fix rounds** per problem. If it still fails, stop and bring it to the user with the evidence and options. Don't loop.
- Contract or requirement problems go back to the architect, not to builders improvising.
- A persona's Requests (changes outside its ownership) are routed to the owning persona or added as tasks.
- Impeccable design-hook findings that reach you (for example after a turn ends) go to the persona that owns the file, usually frontend-dev, or to ui-designer if the finding conflicts with the design spec. Don't fix UI files yourself.

## 5. User gates
- **Gate 1, after the plan passes its full check:** show the user the goal, the acceptance criteria, the key contracts, the file ownership, the open questions and the verifier's verdict. Build only after they approve.
- **Gate 2, after the final check and before devops runs:** checkpoint commits on the `team/<slug>` branch are fine up to this point; pushing, merging, opening a PR and deploying are not. Show the user the final check results (every AC with its evidence), any remaining MINOR findings and the rollback plan. Deploy only after they approve, and pass that approval explicitly to devops.
- Never push to a shared branch, deploy, or run destructive commands without the user's approval in this conversation.

## 6. Finish
Update the work file's Status to `done`. Make sure no dev servers or test processes started during the run are still running (stop them by PID only). Give the user a summary: what was built, each AC with its verdict, the commits on the `team/<slug>` branch, open issues, and a suggested next step (for example opening a PR). Don't push or open the PR unless asked.
