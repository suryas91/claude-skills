# claude-skills

The list of Claude Code skills I have installed, so I can reinstall them on any machine.

- `skills-lock.json`: every skill, the GitHub repo it comes from, and its path in that repo.
- `restore.ps1`: installs all of them into `~/.claude/skills`, so they load in every Claude Code session.

## Restore on a new machine

You need Git and Node.js. In PowerShell:

```powershell
gh repo clone suryas91/claude-skills
cd claude-skills
.\restore.ps1
```

The script prints a check at the end, and any skill that failed to install is listed there. Start a new Claude Code session afterwards to load the skills.

`design-system-nextlevelbuilder` is installed under that name because its original name, `design-system`, is already taken by a skill from `affaan-m/ecc`. The script renames it automatically.

## Update installed skills

```powershell
npx skills update -g
```

This doesn't update `design-system-nextlevelbuilder`. Rerun `.\restore.ps1` to refresh it.
