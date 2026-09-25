# Glossary

| Term | Meaning |
|---|---|
| **AC (acceptance criterion)** | One observable, testable statement of done, numbered `AC-1`, `AC-2`, and so on, each with a **verify-by**. The architect writes them. The verifier judges PASS or FAIL against them. |
| **Verify-by** | The exact command, test or manual step that proves an AC, for example `verify by: npm test -- search.test.js`. |
| **Coordinator** | The main Claude Code session while it runs `/team-build`. It delegates, checks and asks, and never writes application code. |
| **Persona** | One of the nine specialist subagents in `agents/` (architect, verifier and so on). |
| **Slug** | The short name for a piece of work, used in the branch name (`team/<slug>`) and the work file name (`docs/work/<slug>.md`). |
| **Work file** | `docs/work/<slug>.md`: the plan, decisions, evidence, cost and current state of a run. See [The work file](work-file.md). |
| **Handoff** | The work-file section that says where the run is now and what comes next. It's rewritten at every checkpoint, so a new session can resume from it. |
| **Tally** | The work-file section listing every failed check and fix round, with its cause |
| **Gate (0, 1, 2)** | A point where the team stops and asks you. Gate 0: pick an approach. Gate 1: approve the plan. Gate 2: approve shipping. See [Flows and gates](flows.md#the-gates). |
| **Direction** | The architect's first stage for medium and large Features, and spec builds: premises and 2–3 approaches for you to choose from at Gate 0. It ends with **Call: clear** (an obvious winner) or **Call: close** (a real trade-off, so a four-voice "council" gives a second opinion). |
| **Small / medium / large** | The size of the work. Small work uses one builder and has no direction stage. See [How it works](how-it-works.md#sizing-small-medium-and-large). |
| **Baseline** | The test results at the start commit, before any change. Tests that already fail are listed by name and never blamed on the run. |
| **Quick check** | The coordinator's check after every persona: the right files changed, the build passes, the secret scan is clean. Then a checkpoint commit. |
| **Full check / final check** | The verifier's independent checks: of the plan, of the builders' work, and, before Gate 2, of everything. |
| **Fingerprint** | A hash of the project's files (not the work file or memory). A verdict is only valid while the fingerprint is unchanged. See [Safety and evidence](safety-and-evidence.md#fingerprints). |
| **Lens** | A focus area for a code reviewer: security, testing, performance, api-contract, data-migration or red-team. Large or risky changes get several reviewers in parallel, one lens each. |
| **Core pass** | The part of the review checklist that runs on every review, whatever the lens |
| **Red-team** | The last reviewer on a large change. It gets the files and properties the others checked, but not their conclusions, and looks for what they missed. |
| **Refute task** | A reviewer run whose job is to *disprove* a serious finding from the code or a test before anyone fixes it. Findings that survive are **UPHELD**; the rest are **REFUTED** and listed at Gate 2. |
| **Spot-check** | A focused re-review of just the fixes after a review fix round |
| **BLOCKER / MAJOR / MINOR** | Review severities: must fix before merge / should fix now / fix when convenient (or list at Gate 2) |
| **Fix round** | One attempt to fix a failed check or an upheld finding. At most 2 per problem, and then the team asks you. |
| **UNVERIFIED** | Something the team couldn't demonstrate itself, such as DNS, a dashboard setting or live model quality. It's listed at Gate 2 for your yes or no. |
| **Characterization tests** | Tests that pin down how code behaves *today*, added before a refactor so any change in behavior is caught |
| **Verify gate** | A hook that stops the coordinator from ending its turn while the unit tests fail. It's armed only after the builders' full check. |
| **Ownership** | Which files each persona may edit in the current step, written to `.claude/team/ownership.json` and enforced by a hook |
| **Eval / fixture mode / live** | For AI features: a set of test cases scored by graders. **Fixture mode** replays recorded model replies (free and deterministic, so every case must pass). **Live** calls the real model (paid, and needs your approval above the cost threshold). |
| **Process hash** | A hash of the persona, skill and checklist files, recorded in each retro so runs on different versions can be compared |
