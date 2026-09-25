# claude-skills

A Claude Code setup that turns one session into a small software team. You type `/team-build <what you want>`, and the main session coordinates nine specialist subagents: an architect, a designer, three builders, a test engineer, a code reviewer, a verifier and a devops engineer. Each step is checked against written acceptance criteria. The team stops for your approval before it builds, and again before anything ships.

**Platform:** Windows only for now. The hooks and scripts are PowerShell.

![Overview: you talk to the coordinator, which runs the personas, the checks and the gates](docs/images/overview.png)

It also includes the ~360 third-party skills the personas draw on, four safety hooks, and an installer that sets everything up on a new machine.

## What you get

| Part | What it does | Where |
|---|---|---|
| **`/team-build`** | The coordinator: classifies the work, runs the right flow, hands work between personas, runs checks, keeps a work file, and asks you at the gates. | `skills/team-build/SKILL.md` |
| **9 personas** | Claude Code subagents, each with its own job, files, skills and report format. | `agents/` |
| **Checklists** | The review checklist, AI-feature standards, MCP and ship checklists, and the QA taxonomy that the personas read. | `skills/team-build/references/` |
| **Scripts** | Secret scan, evidence fingerprint and verify-gate control, used by the coordinator and the checkers. | `skills/team-build/scripts/` |
| **4 hooks** | Enforce the rules that instructions alone can't: file ownership, dangerous commands, "don't stop while tests fail", and resuming an interrupted run. | `hooks/` |
| **Custom skills** | `/freeze` (lock edits to a folder) and `playwright-testing`. | `skills/freeze/`, `skills/playwright-testing/` |
| **Third-party skills** | Every other skill, pinned by source in a lock file and installed by the script. | `skills-lock.json` |
| **Installer** | Installs everything and merges the settings. Safe to re-run. | `restore.ps1` |

## Quick start

**Requirements:** Windows, [Claude Code](https://docs.claude.com/en/docs/claude-code), Git (with Git Bash) and Node.js. Windows PowerShell 5.1, which ships with Windows, is enough.

**Back up `~/.claude` first** if you already use Claude Code. The installer changes global settings and replaces files with the same names; see [What the installer changes](#what-the-installer-changes).

```powershell
git clone https://github.com/suryas91/claude-skills
cd claude-skills
powershell -NoProfile -ExecutionPolicy Bypass -File .\restore.ps1
```

`-ExecutionPolicy Bypass` is needed because Windows blocks local scripts by default.

Start a new Claude Code session, open any project with Git, and run:

```
/team-build add a dark-mode toggle to the settings page
```

The team:
1. classifies the work;
2. writes a plan with acceptance criteria;
3. **stops for your approval** (Gate 1; skipped only for small bug fixes);
4. builds, tests, reviews and verifies;
5. **stops again** (Gate 2) before any deploy or push.

Everything happens on a `team/<slug>` branch, where `<slug>` is a short name for the work (for example `team/dark-mode-toggle`). The plan, decisions, evidence and costs are kept in `docs/work/<slug>.md` in your project. [Files a run creates in your project](docs/how-it-works.md#files-a-run-creates-in-your-project) lists everything a run touches. New to the terms? See the [glossary](docs/glossary.md).

**Stopping a run:** press `Esc` to interrupt at any time. Nothing is pushed or deployed without your yes. Later, run `/team-build` again in the project: it finds the unfinished run and asks whether to **resume** or **abandon** it. Abandoning stops the processes the run started and removes its state files. Your branch and commits stay; delete the `team/<slug>` branch if you don't want them.

`restore.ps1 -SkipDownloads` only updates the team files, hooks and settings. It needs no network, which makes it the quick way to pick up changes after a `git pull`.

## What the installer changes

Everything goes into your user-level `~/.claude`, so it applies to **every** Claude Code session and project:

| Change | Details |
|---|---|
| Third-party skills | About 360 skills installed into `~/.claude/skills` from the sources in `skills-lock.json` |
| Personas and custom skills | `~/.claude/agents/<name>.md` for the 9 personas, and `~/.claude/skills/{team-build,freeze,playwright-testing}`. **Files with the same names are overwritten**, and those three skill folders are replaced. |
| Hooks | 4 PowerShell hooks in `~/.claude/hooks`, wired into `settings.json`. An entry is added only if no hook already runs that script. |
| `settings.json` | Merged, never overwritten. Every lock skill is set to name-only in the main skill list, which saves about 26k tokens per session. Six `orch-*` skills that conflict with `/team-build` are turned off. `permissions.defaultMode` becomes `auto`, **but only if you haven't set one**. |
| MCP and plugins | The Playwright MCP server (browser control) and the Impeccable design plugin, both at user scope |

**The hooks run in every project, not just during team runs.**
- `careful.ps1` checks every shell command: it blocks a few dangerous ones and asks before other destructive ones.
- The other three hooks do nothing unless a `/team-build` run or a `/freeze` is active.
- To turn a hook off, remove its entry under `hooks` in `~/.claude/settings.json`.

See [Safety and evidence](docs/safety-and-evidence.md#the-four-hooks) for what each one does.

## The five kinds of work

| Work type | Example | What's different |
|---|---|---|
| **Feature** | `/team-build add a chat assistant` | For medium and large work the architect first proposes 2–3 approaches, and you pick one (Gate 0). |
| **Change** | `/team-build make search also match tags` | Tests are updated to the new behaviour *first*, and shown to fail, before the code changes. |
| **Bug fix** | `/team-build bug: pasted text shows too few words` | test-engineer reproduces the bug as a failing test and confirms the root cause before anyone fixes it. |
| **Refactor** | `/team-build split server.js into modules` | The same tests must pass before and after, and none may be removed or weakened. |
| **Spec build** | `/team-build build the MVP in docs/prd.md` | The architect plans thin slices from the spec. Slice 1 is built and shown to you before the rest. |

## Documentation

| Page | Read it to learn |
|---|---|
| [How it works](docs/how-it-works.md) | The moving parts (coordinator, personas, hooks, scripts, state files) and how a run fits together |
| [Flows and gates](docs/flows.md) | Each flow step by step, the three user gates, the checks, the review step and fix-round limits |
| [The personas](docs/personas.md) | What each persona does, which files it may touch, its skills, and what its report contains |
| [Safety and evidence](docs/safety-and-evidence.md) | Why a "PASS" can be trusted: baselines, fingerprints, the secret scan, the verify gate, and the four hooks |
| [The work file](docs/work-file.md) | The anatomy of `docs/work/<slug>.md`, with a real example |
| [Lessons learned](docs/lessons-learned.md) | What eight test runs found, and how the setup changed because of it |
| [Troubleshooting](docs/troubleshooting.md) | Common problems and fixes |
| [Glossary](docs/glossary.md) | AC, gate, lens, fingerprint, slug, handoff and the other terms used in these docs |

## Using one persona on its own

The personas are ordinary Claude Code subagents, so you can call one without the full flow. For example, "have the code-reviewer look at my changes", or `@agent-verifier check that the login fix works`. Outside a `/team-build` run they aren't restricted to particular files, unless a `/freeze` is active or an interrupted run left `.claude/team/ownership.json` behind.

## Cost and speed

A run uses several subagents, so it costs far more tokens than doing the work in one session. Measured on the test project:
- **Small change or bug fix:** 6–15 persona calls, 0.4–1.4M subagent tokens, 10–60 minutes of agent time.
- **Spec-build slice** (web page + AI summary + MCP tool): 33 calls, about 4.4M tokens.

The tokens count against your Claude plan's usage limits, or your API bill if you use an API key. The team is worth it when being right matters more than being quick. Every step's cost is recorded in the work file's Cost table, so you can see where the tokens went.

## Keeping it current

- **Update third-party skills:** `npx skills update -g`. This doesn't update `design-system-nextlevelbuilder`; rerun `.\restore.ps1` for that.
- **After editing a persona, the skill, a checklist or a hook in `~/.claude`:**
  1. Copy the file back into this repo.
  2. Run the hook tests: `powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\hooks\tests\test-hooks.ps1"`.
  3. Commit.
- **Comparing versions:** each run's retro records a process hash of the persona, skill and checklist files, so runs on different versions can be compared.

## Impeccable (design plugin)

A design plugin from [pbakaus/impeccable](https://github.com/pbakaus/impeccable), installed through Claude Code's plugin system rather than the lock file.
- **Skill:** `/impeccable audit`, `critique`, `polish`, `typeset`, `layout` or `colorize`. It's a backup skill for the ui-designer.
- **Design hook:** runs after edits to UI files and at the end of each turn. It asks Claude to fix or justify each finding (contrast, overused fonts, AI-template patterns), and skips non-UI files.
- **Engine:** downloaded on first use into `~/.impeccable/bin/` and checksum-verified.
- **Turning it off:** `/impeccable hooks off` for one project, `IMPECCABLE_HOOK_DISABLED=1` everywhere, or `claude plugin uninstall impeccable@impeccable` to remove it.

`design-system-nextlevelbuilder` is installed under that name because its original name, `design-system`, is already taken by a skill from `affaan-m/ecc`. The installer renames it automatically.

## Credits

The checklists, hooks and several process ideas are adapted from [gstack](https://github.com/garrytan/gstack), [ruflo](https://github.com/ruvnet/ruflo) and [claude-skills (alirezarezvani)](https://github.com/alirezarezvani/claude-skills), all MIT-licensed. [`skills/team-build/references/NOTICE.md`](skills/team-build/references/NOTICE.md) says exactly what came from where.
