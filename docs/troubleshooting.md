# Troubleshooting

## The installer fails, or the hook tests don't pass

- **"…settings.json is not valid JSON…".** Your existing `~/.claude/settings.json` has a syntax error, or two keys that differ only in case. The installer leaves the file untouched. Fix it and run the installer again.
- **"Warning: could not install the Playwright MCP server / the Impeccable plugin".** Everything else is installed. Add them by hand:
  ```powershell
  npx -y @anthropic-ai/claude-code mcp add playwright -s user -- cmd /c npx -y "@playwright/mcp@latest"
  npx -y @anthropic-ai/claude-code plugin marketplace add pbakaus/impeccable
  npx -y @anthropic-ai/claude-code plugin install impeccable@impeccable --scope user
  ```
- **Skills are listed as missing.** A download failed, usually because of the network. Run the installer again. It downloads and reinstalls every skill in the lock file, which also restores the missing ones.
- **The hook tests don't end with `FAILURES: 0`.** Look at the `FAIL` lines above the summary, and open an issue with them. The hooks may not behave correctly until it's fixed. Run the installer from a normal folder, such as the cloned repo, not from inside another tool's temporary folder.

## `/team-build` doesn't appear, or the personas aren't found

- Start a **new** Claude Code session after installing. Skills, personas and hooks load when a session starts.
- Check that the files are there: `~/.claude/skills/team-build/SKILL.md`, and 9 files in `~/.claude/agents/`.
- After a `git pull` of this repo, copy the updated files in:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -SkipDownloads
  ```

## A hook blocks something it shouldn't

- **An edit is blocked with `[ownership] ...`.** A `/team-build` run is limiting which files that persona may edit, or an interrupted run left `.claude/team/ownership.json` behind.
  - During a run, the file belongs to another persona, and the coordinator should hand the change to that persona.
  - With no run in progress, run `/team-build` in the project to resume or abandon the old run, or delete `.claude/team/ownership.json`.
- **An edit is blocked with `[freeze] ...`.** A `/freeze` is active for this project. Run `/freeze` to see it, and `/freeze off` to lift it.
- **A shell command is blocked with `[careful] ...`.** See [what careful blocks](safety-and-evidence.md#careful-before-every-shell-command). Killing programs by name is always blocked; stop the specific process instead, with `Stop-Process -Id <pid>`.
- **No hook runs at all.** The hooks run with `powershell.exe -ExecutionPolicy Bypass`. Check that Windows PowerShell exists, and that the paths under `hooks` in `~/.claude/settings.json` point into `~/.claude/hooks/`. Re-running the installer adds any hook that's missing.
- **To turn a hook off,** see [Turning a hook off](safety-and-evidence.md#turning-a-hook-off).

After changing a hook, run the tests. They should end with `FAILURES: 0`:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\hooks\tests\test-hooks.ps1"
```

## The session won't end its turn

The "tests must pass" gate is on, and the unit tests are failing. The coordinator should hand the failure to the persona that owns the code, not stop.
- **It doesn't loop forever:** after 3 blocks in a row it lets the turn end.
- **To pause it:**
  ```powershell
  powershell -NoProfile -File "$HOME/.claude/skills/team-build/scripts/arm-gate.ps1" -Project "C:\path\to\project" -Disarm
  ```
- **To remove it:** the same command with `-Remove`.

The gate only runs a command that `arm-gate.ps1` approved for that project, so a gate file that came with a cloned repo is ignored.

## A run was interrupted (crash, closed window, compaction)

Start a new session in the project and run `/team-build`. It finds the unfinished run, shows you where it stopped, and asks whether to **resume** or **abandon** it. Everything needed to resume is in `docs/work/<slug>.md` and git.

Abandoning:
- stops anything the run started;
- removes the team's state files and the tests-must-pass gate;
- marks the work file `abandoned`.

The branch and its commits stay.

## A commit is blocked by the secret scan

The scan prints `file:line  kind`, never the secret itself.
- **A real secret:** remove it and **replace it** (revoke the key and issue a new one). A secret that was ever committed stays in git history.
- **A fake key in a test:** build it from pieces at runtime instead of writing it out, for example `'sk-ant-' + ('A' * 40)` in PowerShell.
- **A false positive the team can't avoid:** it has to be written down before the commit. The coordinator adds a line to the work file's Tally saying which file and line it is, and why it isn't a real secret.

## Git isn't found in PowerShell

A VS Code window started before Git was installed doesn't see it. Restart VS Code. Meanwhile, the coordinator can run git through Git Bash; the skill already allows for this.

## `~/.claude/...` paths fail with `-File`

Windows PowerShell's `-File` doesn't understand `~`. Write the path as `"$HOME/.claude/..."`, as everything in this repo does.

## The run is slow or expensive

- **Check the size.** Small work uses one builder, skips the direction stage, and usually gets one reviewer. It gets several reviewers when the change is large or touches auth, payments, migrations or AI tool use.
- **Check the Cost table** in the work file to see which step used the most. In the test runs, about half the tokens went to review and verification, which is also where the problems were caught.
- **Split big requests.** One test run asked for a "small" first slice of a spec and still got 38 acceptance criteria. The architect is now limited to about 15 for small work. Breaking a large request into several runs is still the most reliable way to keep each one small.

For paid AI evals, see [the gates](flows.md#the-gates).

## A persona changed files it doesn't own through the shell

The ownership hook sees only file edits, not shell commands. So after each persona, the coordinator compares what actually changed with what that persona owns, and undoes or reroutes anything outside it. If you see this in a work file's Tally, that's the check doing its job.

## Removing the setup

See [Undo](../README.md#undo) in the README.
