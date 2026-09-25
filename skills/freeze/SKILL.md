---
name: freeze
description: Lock edits in the current project to one or more folders (for example while debugging), lift the lock, or show it. User-invoked only.
argument-hint: "<folder>... | off | (empty for status)"
disable-model-invocation: true
---

# Freeze

Idea from gstack's /freeze, /unfreeze and /guard (MIT, (c) 2026 Garry Tan, https://github.com/garrytan/gstack).

The user wants to change the edit freeze for this project. Arguments: `$ARGUMENTS`

Run the helper with the Bash tool, passing the project root (the directory this session was started in, as an absolute path):

- **Folders given** (for example `src/auth tests/auth`): `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude/skills/freeze/freeze.ps1" -Project "<project root>" "src/auth" "tests/auth"`. Folders add to an existing freeze.
- **`off`**: the same command with `-Off` instead of the folders
- **Empty**: the same command with neither, which shows the current freeze

Show the user the helper's output. While a freeze is set, `~/.claude/hooks/ownership-guard.ps1` blocks Edit, Write and NotebookEdit outside those folders, for this session and every subagent, including `/team-build` personas. Memory folders and the session scratchpad stay writable. The hook can't see edits made through shell commands, so while frozen, don't change files outside the frozen folders by any other means either. If a needed change falls outside them, say so and ask the user to widen or lift the freeze.

The freeze persists across sessions until the user runs `/freeze off`.
