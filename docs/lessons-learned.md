# Lessons learned

Before this setup was shared, it was tested with eight `/team-build` runs on a small throwaway Node.js project: a notes API that grew a weather endpoint, a web page, an AI one-line summary and an MCP tool. Each run's retro recorded what failed, what it cost, and which check caught each problem. After each run, the setup was changed where the retro showed a real gap. This page explains why many of the rules exist.

## The runs

| # | What was asked | Calls | Tokens | Major |
|---:|---|---:|---:|---:|
| 1 | Weather endpoint (test data) · *Feature* | – | – | 2 |
| 2 | Weather from a live API · *Feature* | 27 | 2.76M | 1 |
| 3 | `/notes/:id` gives 500, not 404 · *Bug fix* | 6 | 0.40M | 0 |
| 4 | Missing city: 400 → 422 · *Change* | 8 | 0.44M | 0 |
| 5 | Notes routes into a module · *Refactor* | 13 | 0.76M | 0 |
| 6 | Page + AI summary + MCP tool · *Spec build* | 33 | 4.35M | 2 |
| 7 | AI output checker, part 1 · *Change* | 15 | 1.24M | 1 |
| 8 | AI output checker, part 2 · *Change* | 15 | 1.43M | 1 |

- **Sizes:** runs 1 and 2 were medium-sized. The rest were small; run 6 was a spec build kept small on purpose.
- **Major** counts the MAJOR review findings. None was rated BLOCKER.
- **Missing numbers:** run 1 predates the cost tracking.

**Nothing was found after the review, except once.** In run 2 the final check caught a process problem: a persona had copied the start of a fake API key into its notes, which broke one of the checks. One fix round resolved it. Every run passed its final check before Gate 2.

![The web page the team built in run 6, shown with no API key set](images/team-built-page.png)

*Run 6 built this page from a one-page spec. It shows the weather for a city, plus a one-sentence AI summary that is checked before it's shown. No API key was set for the screenshot, so it shows the page's "AI summary unavailable" state. The verifier checked keyboard use, focus, layout at 320 px, contrast (6.4:1 to 17:1) and page speed in a real browser.*

## What the checks caught

Some problems only one kind of check found:

| Problem | Found by | Missed by | Now handled by |
|---|---|---|---|
| A server crashed when the program reading its output closed early | the verifier, closing the output on purpose | the builder's own 79 checks | the builders' real-socket check; the red-team crash probe |
| An MCP server crashed after a *real* network call, twice (on two different exit paths) | the verifier, running it without the test network block | every test, because the tests blocked the network | the real-socket check; the test-engineer's rule for shutdown tests |
| One malformed request could crash the server | the red-team reviewer | 4 other review lenses | a failure-modes rule for request parsing; a red-team checklist item |
| Code checked a value, then read it again, so a malicious object could return something different the second time | three review lenses; red-team proved the crash | – | an architect failure-modes rule; a red-team checklist item |
| An error path returned without reading the response, leaving network connections open | performance and red-team | security rated it minor; testing missed it | a red-team checklist item |
| One client could fill a rate limiter and lock everyone else out | red-team, rating it serious | security and performance flagged it only as minor | a security-lens item |
| A redirect would forward the API key to another host | red-team, with a live redirect test | – | a security-lens item: refuse redirects on requests that carry a key |
| A fix had **no test that could fail** | the testing lens, by undoing the fix and seeing every test still pass | the fix's own tests | the testing lens's "revert the fix" rule |
| Invisible characters after a dot hid a link or a second sentence from an AI output checker | the review | the plan | the AI standards; the review checklist |
| A list of allowed characters left about 9,400 others that still hid a sentence | the review, testing every possible character | the plan's own examples | the architect's self-check: test the whole range of inputs |

The secret scan also stopped four commits; [Safety and evidence](safety-and-evidence.md#the-secret-scan) lists them.

## What changed, and why

Every change below came from a run. Each retro records a `Process:` hash, so runs before and after a change can be compared.

**Planning**
- **Timing numbers are measured before they become criteria** (after run 1). Run 1's plan failed its check twice:
  - a 20 ms response-time limit was set before anyone measured that each network request there took about 16 ms;
  - fixing that limit then broke the 5-second test-suite budget.

  No later run had a timing failure.
- **The architect writes small plans too** (after run 7). Plans the coordinator wrote itself failed their plan check in 3 of 3 runs, even with a checklist. The causes were criteria that contradicted each other, checks that ignored tests already failing, and text damaged by shell escaping. In the next run, the architect's small plan passed on the first try.
- **The plan self-check** (after runs 7 and 8):
  - try every example against all the rules together;
  - write special characters so escaping can't damage them, then scan for invisible ones (a `\b` had silently turned into a backspace character);
  - for filters, test the whole range of inputs, not just the examples.
- **A size budget** (after run 6). The first spec-build slice was meant to be small and still had 38 acceptance criteria, so small plans are now capped at about 15.

**Building**
- **A scope rule and a `Not tested:` line** for builders, so gaps are stated rather than implied.
- **The real-socket check** (after runs 2 and 6). Both crashes appeared only with a real network, and real input and output.

**Review**
- **The review is sized by source lines only** (after run 6). Test lines had pushed small changes into the full multi-reviewer review. In run 7 the new rule counted 15 source lines instead of about 110, and the single reviewer still found the one serious problem.
- **The "revert the fix" rule** (after run 6).
- **Checklist items** from each run's findings: rate-limiter keys, redirects on requests that carry a key, unread responses, AI evals on recorded replies must pass 100%, and probes for AI output checkers.

**Coordination**
- **Review findings are written down immediately** (after run 6). A context compaction lost the review verdicts, and the coordinator had to recover them from the conversation history.
- **The resume reminder also runs at session start,** so an interrupted run is offered for resume even in a brand-new session.

## What worked from the start

- **Independent verification.** The verifier re-ran everything itself, and in several runs caught problems the builders' own checks had missed.
- **The red-team reviewer.** In run 1 it was the only reviewer to find the crash on a malformed request. In run 6 it was the only one to rate the rate-limiter lockout as serious.
- **Baselines.** A test that was already failing ran through six of the runs (1, 2, 4, 6, 7 and 8). Each time it was reported as "1 pre-existing failure, unchanged", never blamed and never hidden. Run 3 fixed it on its own branch, and run 5 was built on that fix.
- **Fingerprints.** Every review and final check was tied to the exact code it examined.
- **The refute step.** It upheld all 7 serious findings it was given, so it raised no false alarms. That also means there's no evidence yet that it filters any out.

## Not yet tested

These runs didn't cover:
- **A real deploy.** Every run stopped at Gate 2 without deploying, so devops's deploy step and the verifier's deploy check have never run for real.
- **Gates answered live, after run 1.** In run 1 the repo owner answered Gates 0 and 1 live. From run 2 on, standing answers were given in advance ("approve the plan", "don't deploy") to keep the test runs moving. The owner still answered some design questions directly in run 6. Whether the gates need changes will show up in real use.
- **Live paid AI evals.** No API key was used, so AI features were only checked against recorded replies.
- **Projects with login.** The test project had no authentication, so auth-specific tests and reviews haven't been tried.
