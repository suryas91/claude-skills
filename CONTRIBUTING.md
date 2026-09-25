# Changing the setup

The live copy of everything is in `~/.claude`. This repo is the shareable copy. The usual loop:

1. Edit the persona, skill, checklist, script or hook in `~/.claude`.
2. If you changed a hook or a script, run the hook tests, which should end with `FAILURES: 0`:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\hooks\tests\test-hooks.ps1"
   ```
3. Copy the changed file into the same path in this repo:

   | From `~/.claude/` | To this repo |
   |---|---|
   | `agents/` | `agents/` |
   | `skills/team-build/`, `skills/freeze/`, `skills/playwright-testing/` | `skills/` |
   | `hooks/` | `hooks/` |

4. If the change affects what the docs say, update `docs/` too.
5. Commit.

## Checking a change in a real run

Every `/team-build` retro starts with a `Process:` line: a hash of the persona, skill and checklist files. After changing any of them, run a small `/team-build` Change and compare its retro with earlier runs on the old hash. [Lessons learned](docs/lessons-learned.md) shows how the current rules were justified this way.

## Diagrams

- The docs pages use inline Mermaid, which GitHub draws itself in light and dark mode.
- Only the README overview and the flows summary are PNG files, each with a light and a dark version.

The sources are in `docs/images/src/`. See [docs/images/README.md](docs/images/README.md) for how to re-render them.

## Skills from the lock file

- **Updating:** `restore.ps1`, run without `-SkipDownloads`, reinstalls every skill in `skills-lock.json` from its source.
- **Adding or removing a skill:** edit `skills-lock.json`. Each entry names the GitHub repo and the path of the skill's `SKILL.md`.
- **The renamed skill:** `design-system-nextlevelbuilder` is installed under that name because its original name, `design-system`, is already taken by a skill from `affaan-m/ecc`. The installer clones it and renames it automatically.
