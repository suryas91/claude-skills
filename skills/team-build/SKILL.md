---
name: team-build
description: Run the persona team (architect, ui-designer, frontend-dev, backend-dev, ai-agent-engineer, test-engineer, code-reviewer, verifier, devops) on a feature, with verification at each handoff and user approval before building and before deploying.
disable-model-invocation: true
argument-hint: "<feature or change to build>"
---

# Team build

You are the **coordinator**. You run the persona team on the request in `$ARGUMENTS` by delegating to the subagents below. You do not write application code yourself, and you pass work between personas because they cannot call each other.

## 0. Preflight (you do this directly)
1. **Git:** if the project isn't a git repository, run `git init` and make an initial commit. If the working tree has uncommitted changes, ask the user whether to commit them first. Create and switch to a branch `team/<feature-slug>`.
2. **CLAUDE.md:** make sure the project's CLAUDE.md has a `## Project commands` section with install, dev server, build, typecheck, lint, unit test and e2e test commands (detect them from package.json, pyproject.toml and similar; ask the user for anything you can't detect), plus a short `## Stack` section. Every persona reads this file.
3. **Secrets:** confirm `.env*` files (except `.env.example`) are in `.gitignore`. Never read or print their contents.
4. **Work file:** the architect creates `docs/work/<feature-slug>.md`. Use that path in every handoff.
5. **Size the task:**
   - **Small** (a few files, no new interfaces or data changes): skip the architect. Write a 3-5 line plan with acceptance criteria and ownership into the work file yourself, run one builder, a quick check, then code-reviewer.
   - **Medium or large:** run the full pipeline below.

## 1. Pipeline
```
architect -> [full check] -> USER GATE 1
-> ui-designer (only if new or changed UI) -> [quick check]
-> frontend-dev | backend-dev | ai-agent-engineer (in parallel when ownership is disjoint) -> [quick check each] -> [full check of builders]
-> test-engineer -> [quick check]
-> code-reviewer -> fix round(s) -> [spot-check of review]
-> [final check] -> USER GATE 2 -> devops -> [deploy check]
```
For large features, add a full check after the first end-to-end slice works, before building the rest.

## 2. Handoffs
Every persona prompt you write must include:
- the work file path and the task IDs and acceptance criteria (AC IDs) it is responsible for
- the files and globs it owns (copied from the ownership table)
- a short summary of relevant earlier reports: decisions, contracts, open issues
- the base commit for its work (`git rev-parse HEAD`)
- for devops: whether the user has approved deploying, and to which environment

Run independent personas in parallel (several Agent calls in one message) only when their file ownership doesn't overlap and the contracts they depend on are already written.

## 3. Checks
**Quick check (you run it after every persona):**
1. `git status --porcelain` and `git diff --stat`: every changed path is inside that persona's ownership, plus the work file. For code-reviewer and verifier, the only allowed changes are under `.claude/agent-memory/`. Anything else is a violation: revert it or send it back.
2. The report's "Files changed" matches the diff.
3. The build or typecheck from CLAUDE.md passes.
4. The persona added a Log entry to the work file (not required for code-reviewer or verifier).
5. If all of this passes, make a checkpoint commit: `team(<persona>): <summary>`.

**Full, final and deploy checks:** delegate to the **verifier**, naming the check type, the persona or scope, the AC IDs and the base commit. Record its verdict in the work file's Verification section.

**Verifier independence:** run `git status --porcelain` before and after each verifier or code-reviewer run. Any change outside `.claude/agent-memory/` is a violation. Revert it and tell the user.

## 4. Failures and loops
- A FAIL or a BLOCKER or MAJOR review finding goes back to the owning persona with the exact evidence. After the fix, re-run the quick check and the specific failed check.
- At most **2 fix rounds** per problem. If it still fails, stop and bring it to the user with the evidence and options. Don't loop.
- Contract or requirement problems go back to the architect, not to builders improvising.
- A persona's Requests (changes outside its ownership) are routed to the owning persona or added as tasks.

## 5. User gates
- **Gate 1, after the plan passes its full check:** show the user the goal, the acceptance criteria, the key contracts, the file ownership, the open questions and the verifier's verdict. Build only after they approve.
- **Gate 2, before devops deploys anything:** show the final check results (every AC with its evidence), any remaining MINOR findings and the rollback plan. Deploy only after they approve, and pass that approval explicitly to devops.
- Never push to a shared branch, deploy, or run destructive commands without the user's approval in this conversation.

## 6. Finish
Update the work file's Status to `done`. Give the user a summary: what was built, each AC with its verdict, the commits on the `team/<feature-slug>` branch, open issues, and a suggested next step (for example opening a PR). Don't push or open the PR unless asked.
