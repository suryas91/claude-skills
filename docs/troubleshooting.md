# Troubleshooting

## `/team-build` doesn't appear, or the personas aren't found

- Start a **new** Claude Code session after installing. Skills, personas and hooks load when a session starts.
- Check that the files are there: `~/.claude/skills/team-build/SKILL.md`, and 9 files in `~/.claude/agents/`.
- After a `git pull` of this repo, copy the updated files in:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File .\restore.ps1 -SkipDownloads
  ```

## A hook blocks something it shouldn't

- **An edit is blocked with `[ownership] ...`.** A `/team-build` run is limiting which files that persona may edit, or an interrupted run left `.claude/team/ownership.json` behind.
  - During a run, the file belongs to another persona, and the coordinator should hand the change to that persona.
  - If no run is in progress, run `/team-build` in the project to resume or abandon the old run, or delete `.claude/team/ownership.json`.
- **An edit is blocked with `[freeze] ...`.** A `/freeze` is active for this project. Run `/freeze` to see it, and `/freeze off` to lift it.
- **A shell command is blocked with `[careful] ...`.** See [what careful blocks](safety-and-evidence.md#careful-before-every-shell-command). Killing programs by name is always blocked; stop the specific process instead: `Stop-Process -Id <pid>`.
- **Every hook fails to run.** The hooks run with `powershell.exe -ExecutionPolicy Bypass`. Check that Windows PowerShell exists, and that the paths under `hooks` in `~/.claude/settings.json` point into `~/.claude/hooks/`. Re-running the installer adds any hook that's missing.
- **To turn a hook off,** see [Turning a hook off](safety-and-evidence.md#turning-a-hook-off).

After changing a hook, run the tests. They should end with `FAILURES: 0`:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\hooks\tests\test-hooks.ps1"
```

## The session won't end its turn

The "tests must pass" gate is on, and the unit tests are failing. The coordinator should hand the failure to the persona that owns the code, not stop.
- **It won't loop forever:** it lets the turn end by itself after 3 blocks in a row.
- **To pause it:**
  ```powershell
  powershell -NoProfile -File "$HOME/.claude/skills/team-build/scripts/arm-gate.ps1" -Project "C:\path\to\project" -Disarm
  ```
- **To remove it:** the same command with `-Remove`.

The gate only runs a command that `arm-gate.ps1` approved for that project, so a gate file that came with a cloned repo is ignored.

## A run was interrupted (crash, closed window, compaction)

Start a new session in the project and run `/team-build`. It finds the unfinished run, shows you where it stopped, and asks whether to **resume** or **abandon** it. Everything needed to resume is in `docs/work/<slug>.md` and git.

If you abandon, the coordinator:
- stops anything the run started;
- removes the team's state files;
- turns off the tests-must-pass gate;
- marks the work file `abandoned`.

The branch and its commits stay.

## A commit is blocked by the secret scan

The scan prints `file:line  kind`, never the secret itself.
- **A real secret:** remove it, and **replace it** (revoke the key and issue a new one). A secret that was ever committed stays in git history.
- **A fake key in a test:** build the text from pieces at runtime rather than writing it out. For example, `'sk-ant-' + ('A' * 40)` in PowerShell.
- **A false positive the team can't avoid:** it has to be written down before committing. The coordinator adds a line to the work file's Tally saying which file and line, and why it isn't a real secret, then commits.

## Git isn't found in PowerShell

A VS Code window started before Git was installed doesn't see it. Restart VS Code. In the meantime the coordinator can run git through Git Bash, which the skill already allows for.

## `~/.claude/...` paths fail with `-File`

Windows PowerShell's `-File` doesn't understand `~`. Write paths as `"$HOME/.claude/..."`, as everything in this repo does.

## The run is slow or expensive

- **Check the size.** Small work uses one builder, skips the direction stage, and usually gets one reviewer. It gets several reviewers when the change is large or touches auth, payments, migrations or AI tool use.
- **Check the Cost table** in the work file to see which step used the most. In the test runs, about half the tokens went to review and verification, which is also where the problems were caught.
- **Keep requests narrow.** Adding "keep it small" to the request helps the architect stay within its budget of about 15 criteria.

For paid AI evals, see [the gates](flows.md#the-gates).

## A persona changed files it doesn't own through the shell

The ownership hook only sees file edits, not shell commands. So after each persona, the coordinator compares what actually changed with what that persona owns, and undoes or reroutes anything outside it. If you see this in a work file's Tally, that's the check doing its job.
