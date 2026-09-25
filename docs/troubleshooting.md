# Troubleshooting

### `/team-build` doesn't appear, or the personas aren't found
- Start a **new** Claude Code session after running `restore.ps1`. Skills, agents and hooks load at session start.
- Check that the files are there: `~/.claude/skills/team-build/SKILL.md`, and 9 files in `~/.claude/agents/`.
- If you only pulled this repo, run `.\restore.ps1 -SkipDownloads` to copy the updated files in.

### A hook blocks something it shouldn't
- **An edit is denied with `[ownership] ...`.** A `/team-build` run (or a leftover `.claude/team/ownership.json` from an interrupted run) is restricting that persona.
  - If a run is in progress, the file belongs to another persona. The coordinator should route the change to its owner.
  - If no run is in progress, start `/team-build` to resume or abandon the old run, or delete `.claude/team/ownership.json`.
- **An edit is denied with `[freeze] ...`.** A `/freeze` is active for this project. Run `/freeze` to see it, and `/freeze off` to lift it.
- **A shell command is denied with `[careful] ...`.** See the table in [Safety and evidence](safety-and-evidence.md#carefulps1-before-every-shell-command). Killing processes by name is always denied; stop the specific PID instead (`Stop-Process -Id <pid>`).
- **Every hook errors.** The hooks run with `powershell.exe -ExecutionPolicy Bypass`. Check that Windows PowerShell exists and that the paths in `~/.claude/settings.json` → `hooks` point at `~/.claude/hooks/`. Re-running `restore.ps1` adds any hook that's missing.

After changing a hook, always run the test suite:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\hooks\tests\test-hooks.ps1"
```

### The session won't end its turn ("verify gate")
The verify gate is armed and the unit tests fail. The coordinator should route the failure to the owning persona, not stop.
- It lets the turn end by itself after 3 consecutive blocks.
- To pause it deliberately: `powershell -NoProfile -File "$HOME/.claude/skills/team-build/scripts/arm-gate.ps1" -Project "<root>" -Disarm`.
- To remove it: the same command with `-Remove`.

The gate only runs a command that `arm-gate.ps1` trusted for this project. A gate file that came with a cloned repo is ignored.

### A run was interrupted (crash, closed window, compaction)
Start a new session in the project and run `/team-build`. Preflight finds the unfinished run and shows you its Handoff, then asks whether to **resume** or **abandon**. The `team-resume` hook also reminds the session at startup. Everything needed to resume is in `docs/work/<slug>.md` and git.

If you abandon, the coordinator:
- stops the recorded processes by PID;
- deletes the team state files;
- removes the gate;
- marks the work file `abandoned`.

### A commit is blocked by the secret scan
The scan prints `file:line  kind`, never the value.
- **A real secret:** remove it and **rotate it**. It stays in git history if it was ever committed.
- **A fake key in a test:** build the string at runtime instead of writing it literally. For example, join the parts, or repeat a character.
- **A false positive the team can't avoid:** it has to be recorded in the work file before committing.

### Git isn't found in PowerShell
A VS Code window started before Git was installed doesn't see it. Restart VS Code, or let the coordinator run git through the Bash tool (Git Bash), which the skill already does.

### `~/.claude/...` paths fail with `-File`
Windows PowerShell's `-File` doesn't expand `~`. The skill always writes script paths as `"$HOME/.claude/skills/team-build/scripts/<name>.ps1"`. Use the same form yourself.

### The run is slow or expensive
- **Check the size.** Small work skips the direction stage and uses one builder and one reviewer.
- **Check the Cost table** in the work file to see which step used the most. In the test runs, the review and verification steps were about half of the tokens, and they're also where the defects were caught.
- **Keep requests narrow.** "Keep it small" in the request helps the architect stay within the ~15-criteria budget.

### Paid model evals
Personas never run a live eval above the threshold in `CLAUDE.md` (default USD 2). They print the estimate and stop, and the coordinator asks you. Fixture-mode evals are free and run offline.

### A persona edited another persona's memory, or a file outside its ownership, through the shell
The ownership hook only sees the Edit and Write tools. The coordinator's quick check compares `git status` against ownership after every persona, and reverts or routes anything outside it. If you see this in a work file's Tally, that's the check doing its job.
