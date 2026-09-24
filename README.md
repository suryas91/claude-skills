# claude-skills

My Claude Code setup: the skills I have installed, a team of 9 personas that use them, and a `/team-build` command that runs the team on features, changes, bug fixes, refactors and spec builds.

- `skills-lock.json`: every installed skill, the GitHub repo it comes from, and its path in that repo.
- `agents/`: the 9 personas (Claude Code subagents).
- `skills/team-build/`: the `/team-build` command that coordinates the personas.
- `restore.ps1`: installs everything on a new machine.

## The personas

| Persona | Job | Edits code? |
|---|---|---|
| architect | Plan: requirements, acceptance criteria, contracts, file ownership | Only the work file |
| ui-designer | Visual direction, design tokens, states, motion | Yes |
| frontend-dev | React, Next.js, Vite UI | Yes |
| backend-dev | APIs, databases, migrations (FastAPI, Node) | Yes |
| ai-agent-engineer | Claude API, prompts, tools, agent loops, MCP, cost control | Yes |
| test-engineer | Unit, component, API, Playwright and AI regression tests; debugging | Tests only |
| code-reviewer | Correctness, security, simplicity, accessibility, performance | No |
| verifier | Independent PASS/FAIL against acceptance criteria, with evidence | No |
| devops | CI/CD, containers, deployment, monitoring | Yes |

Each persona loads its core skills when it starts and can load backup skills when needed. code-reviewer and verifier keep per-project notes in `.claude/agent-memory/`.

## Using the team

In any project:

```
/team-build add a chat assistant to the dashboard
```

The main session coordinates. It sets up Git and the project's CLAUDE.md commands, works out what kind of work it is, and runs the matching flow:

| Work type | Example | Flow |
|---|---|---|
| Feature | `/team-build add a chat assistant` | architect -> builders in parallel -> test-engineer -> code-reviewer -> verifier |
| Change | `/team-build make search also match tags` | architect updates the plan -> test-engineer updates tests first -> builders -> review -> verifier |
| Bug fix | `/team-build bug: pasted text shows too few words` | test-engineer reproduces it with a failing test -> builder fixes the root cause -> review -> verifier |
| Refactor | `/team-build split server.js into modules` | verifier records a test baseline -> builders restructure -> review confirms no behavior change -> same tests pass |
| Spec build | `/team-build build the MVP in docs/prd.md` | architect plans thin slices from the spec -> first slice built and checked before the rest |

There's a verification check at each handoff. It stops for your approval after the plan and before any deploy. Plans, decisions and handoff logs are kept in `docs/work/<slug>.md` in the project, and all commits go on a `team/<slug>` branch.

You can also call one persona directly: "have the code-reviewer look at my changes", or `@agent-code-reviewer`.

## Restore on a new machine

You need Git and Node.js. In PowerShell:

```powershell
gh repo clone suryas91/claude-skills
cd claude-skills
.\restore.ps1
```

The script:
1. Installs every skill in `skills-lock.json` into `~/.claude/skills`.
2. Installs the personas into `~/.claude/agents` and `/team-build` into `~/.claude/skills`.
3. Sets every skill to name-only in the main skill list (`skillOverrides` in `~/.claude/settings.json`). This cuts the list from about 28k tokens to about 2k. Personas still load their skills in full. Existing settings are kept.
4. Adds the Playwright MCP server so personas can control a browser.
5. Makes auto mode the default permission mode (unless one is already set).
6. Installs the [Impeccable](https://impeccable.style) design plugin (see below).
7. Lists any skill that failed to install.

Start a new Claude Code session afterwards.

`design-system-nextlevelbuilder` is installed under that name because its original name, `design-system`, is already taken by a skill from `affaan-m/ecc`. The script renames it automatically.

## Impeccable

A design plugin from [pbakaus/impeccable](https://github.com/pbakaus/impeccable), installed through Claude Code's plugin system (not the skills lock file).

- **Skill:** `/impeccable <command>`, for example `audit`, `critique`, `polish`, `typeset`, `layout` or `colorize`. It's a backup skill for the ui-designer.
- **Design hook:** runs automatically after edits to UI files and at the end of each turn, in every project, and asks Claude to fix or justify each finding (contrast, overused fonts, AI-template patterns). It skips non-UI files and takes under 0.2 seconds.
- **Engine:** the first run downloads a checksum-verified engine program into `~/.impeccable/bin/` from the project's GitHub releases.
- **Turning the hook off:** for one project, run `/impeccable hooks off` there. Everywhere: set the environment variable `IMPECCABLE_HOOK_DISABLED=1`. To remove the plugin, run `claude plugin uninstall impeccable@impeccable`.

## Keeping it current

- Update skills: `npx skills update -g`. This doesn't update `design-system-nextlevelbuilder`; rerun `.\restore.ps1` for that.
- After changing a persona or `/team-build`, copy it from `~/.claude/agents` or `~/.claude/skills/team-build` into this repo and commit.
- Every month or two, check which personas and skills actually get used, and trim or tighten the rest.
