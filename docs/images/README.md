# Images

**Diagrams.** The docs pages draw their diagrams with inline [Mermaid](https://mermaid.js.org) blocks, which GitHub renders itself and switches between light and dark mode. To change one of those, edit the block in the page.

**PNG files.** Only two diagrams are PNGs, each in a light and a dark version, because they're shown with `<picture>` so they look right in both GitHub themes:

| Files | Used in | Source |
|---|---|---|
| `overview.png`, `overview-dark.png` | README | `src/overview.mmd` |
| `flows.png`, `flows-dark.png` | docs/flows.md | `src/flows.mmd` |

**Screenshots:**

| File | What it shows |
|---|---|
| `team-built-page.png` | The web page the team built in test run 6, running with no API key set |
| `work-file.png` | The top of test run 4's work file, rendered the way GitHub renders Markdown |

## Re-rendering a PNG

Render the light and dark versions at twice the size, so they stay sharp on high-resolution screens:

```
npx -y @mermaid-js/mermaid-cli -i docs/images/src/overview.mmd -o docs/images/overview.png -b white -s 2
npx -y @mermaid-js/mermaid-cli -i docs/images/src/overview.mmd -o docs/images/overview-dark.png -t dark -b "#0d1117" -s 2
```

Keep diagrams narrow, about 1,000 px wide or less. GitHub shows images at most about 880 px wide, and a wider diagram's text gets too small to read.

**Colors used in every diagram:**
- gates: `fill:#fef3c7,stroke:#d97706,color:#78350f`
- hooks and guards: `fill:#fee2e2,stroke:#dc2626,color:#7f1d1d`
- files and state on disk: `fill:#f1f5f9,stroke:#64748b,color:#0f172a`

The fills have dark text, so they stay readable in dark mode too.
