# Third-party notice

All three sources are MIT-licensed. The full licence text is at the end. The author kept the evidence for every idea below (file, lines and reviewer) in local audit notes from 2026-09-24. Those notes are not part of this repository.

## gstack (https://github.com/garrytan/gstack), MIT, (c) 2026 Garry Tan
- `review-checklist.md` and `qa-issue-taxonomy.md` are adapted from `review/checklist.md`, `review/specialists/*.md` and `qa/references/issue-taxonomy.md` (2026-09-23).
- Ported as new PowerShell code (no gstack code copied), 2026-09-23:
  - `scripts/fingerprint.ps1`: from `gstack-wtree` and `gstack-evidence`.
  - `~/.claude/hooks/verify-gate.ps1` and `scripts/arm-gate.ps1`: from `gstack-verify-gate`, including its per-repo trust model.
  - `~/.claude/hooks/careful.ps1`, the freeze check in `ownership-guard.ps1`, and `~/.claude/skills/freeze/`: from `/careful`, `/freeze`, `/unfreeze` and `/guard`.
- Ideas added 2026-09-24:
  - From `plan-ceo-review`, `plan-eng-review` and `autoplan`: the failure-modes table with the critical-gap rule.
  - From `review` and `ship`: "pre-existing needs receipts", plan-completion and scope-drift audits, and quoting the triggering line.
  - From `codex` (review-mode): fail-closed review merging.
  - From `cso`: webhook replay, cost amplification, the entrypoint/boundary/impact rubric, and blind red-team.
  - From `docs/designs/*` (SESSION_INTELLIGENCE, ML_PROMPT_INJECTION_KILLER, GCOMPACTION, PLAN_TUNING_V0): compaction recovery, the Rule of Two, verbatim grounding, and the memory-poisoning defence.
  - From `TODOS.md` and `docs/TESTING_INTERNALS.md`: the "green means green" test rules.
  - From recorded review fixtures: the red-team defect classes.
- Ideas added 2026-09-24, after the first smoke run:
  - the builder scope rule ("the explicit task is the lake", `model-overlays/`);
  - the builders' `Not tested:` report line (`.github/PULL_REQUEST_TEMPLATE.md`);
  - reviewer false-positive suppression keyed by file pattern and category.

## ruflo (https://github.com/ruvnet/ruflo), MIT, (c) 2024-2026 ruvnet
- `scripts/secret-scan.ps1`: patterns from the security-auditor and pii-detector agents.
- `~/.claude/hooks/careful.ps1` secret-printing rule: from ADR-378.
- `~/.claude/hooks/team-resume.ps1`: the restore-on-SessionStart shape from Context Autopilot.
- Fail-closed hooks and the hook regression suite (`~/.claude/hooks/tests/`): from ADR-127, ADR-102 and ADR-G013.
- Memory writes limited to each persona's own folder: from ADR-G007.
- Review checklist:
  - "wired and enforced", sibling divergence and observable fallbacks (dream-cycle gists);
  - test honesty and failing-set baselines;
  - prototype pollution, spread-order overwrites, credential fallback chains, NL-to-SQL, TypeScript casts on tool arguments and child-process env (security-architect, protocol/evidence.md, ADR-029, security-audit);
  - Actions injection;
  - unbounded in-memory collections (ADR-G026).
- The retro's process-version stamp and KPI line (added 2026-09-24): from ADR-G005.
- `mcp-checklist.md` (added 2026-09-24): from ADR-166 (the HTTP MCP bridge remote-code-execution disclosure), ADR-012, ADR-388, ADR-320 and ADR-339.
- `ai-feature-standards.md`:
  - eval integrity: exploit audit (ADR-167, gaia-validate), frozen blind-labelled sets (router benchmark), variance (benchmarks), grader validation (ADR-081/169/171), measured-win gate (ADR-391);
  - deterministic tool authorization (ADR-380) and random-nonce fences (x-gateway);
  - reserve-then-commit budgets (ADR-164.1), cache-hit proof, and no-progress detection (ADR-G024);
  - RAG measurement and deletion sync (BEIR-MATRIX, ADR-0002), tool reversibility classes (ADR-G021), and memory provenance (ADR-323/354).

## claude-skills (https://github.com/alirezarezvani/claude-skills), MIT, (c) 2025 Alireza Rezvani
- `~/.claude/skills/playwright-testing/`: adapted from `engineering-team/playwright-pro`. Its `references/` files are copied unchanged from `skills/pw/reference/`, `skills/fix/flaky-taxonomy.md` and `skills/pw-review/anti-patterns.md`.
- Ideas added 2026-09-24:
  - measurable non-functional ACs and a failure AC per external dependency (spec-driven-workflow, cs-backend-engineer, cs-frontend-engineer);
  - the Handoff and resume path (tc-tracker, /tc);
  - refuting findings before routing (workflow-builder skeptic vote);
  - named loop terminal states (loop-library);
  - eval integrity: locked evaluator (experiment-runner, research-digest), grader agreement and noise (ai_product_evals), one change per iteration (cs-agent-grader);
  - scope drift (karpathy-reviewer), leftover scaffolding patterns (code-to-prd), dependency and env parity (spec-to-repo);
  - memory pruning and contradiction replacement (memory-analyst, cs-wiki-linter);
  - forgetting rules (cs-memory-engineer).
- Idea added 2026-09-24 (after the first smoke run): `ship-checklist.md`, with its check list and severity roll-up from `engineering/skills/ship-gate` (the checks are rewritten as Git Bash greps).

---

MIT License (identical terms for each copyright holder above)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
