# Contributing

## Making a change

1. Fork the repo and create a branch.
2. Edit the files in this repo: personas in `agents/`, the skill and its checklists in `skills/team-build/`, hooks in `hooks/`, or the docs in `docs/`.
3. Install your version, which copies it into your `~/.claude`:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\restore.ps1 -SkipDownloads
   ```
4. If you changed a hook or a script, check that the hook tests end with `FAILURES: 0`. The installer runs them, or you can run them yourself:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\hooks\tests\test-hooks.ps1"
   ```
5. If you changed a persona, the skill or a checklist, try it: run a small `/team-build` Change in a throwaway project.
6. Open a pull request. Say what you changed and why, and include the test output. For process changes, include the retro's `Process:` and `KPI:` lines from your trial run.

## Why process changes need a trial run

Every `/team-build` retro starts with a `Process:` line: a hash of the persona, skill and checklist files. Runs on different versions can be compared through it. [Lessons learned](docs/lessons-learned.md) shows how the current rules were justified this way, and the same evidence is the bar for changing them.

## Diagrams

- **Docs pages:** they use inline Mermaid, which GitHub draws itself in light and dark mode. Edit the block in the page.
- **PNGs:** the README's overview and flows images are the only PNGs. [docs/images/README.md](docs/images/README.md) explains how to re-render them, and which colors to use.

## Skills from the lock file

- **Adding or removing a skill:** edit `skills-lock.json`. Each entry names the GitHub repo and the path of the skill's `SKILL.md`.
- **Updating:** `restore.ps1`, run without `-SkipDownloads`, reinstalls every listed skill from its source.
- **The renamed skill:** `design-system-nextlevelbuilder` is installed under that name because its original name, `design-system`, is already taken by a skill from `affaan-m/ecc`. The installer clones it and renames it automatically.

## For the maintainer

The maintainer edits the live copy in `~/.claude` first, then copies changes into this repo:

| From `~/.claude/` | To this repo |
|---|---|
| `agents/` | `agents/` |
| `skills/team-build/`, `skills/freeze/`, `skills/playwright-testing/` | `skills/` |
| `hooks/` | `hooks/` |

Either way, the two copies should match before a commit.
