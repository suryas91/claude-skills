# Images

| File | What it shows | Source |
|---|---|---|
| `overview.png` | The team at a glance (used in the main README) | `src/overview.mmd` |
| `architecture.png` | Coordinator, personas, hooks, scripts and state files | `src/architecture.mmd` (also inline in `how-it-works.md`) |
| `run-sequence.png` | One small Change run, end to end | `src/run-sequence.mmd` (also inline in `how-it-works.md`) |
| `flows.png` | The five flows side by side | `src/flows.mmd` |
| `review-step.png` | Lenses, red-team, merge, refute | `src/review-step.mmd` (also inline in `flows.md`) |
| `team.png` | Plan, Build, Check, Ship | `src/team.mmd` (also inline in `personas.md`) |
| `hooks.png` | Where each hook runs | `src/hooks.mmd` (also inline in `safety-and-evidence.md`) |
| `team-built-page.png` | Screenshot of the page the team built in test run 6, with no API key set | the test project |
| `work-file.png` | Screenshot of a real work file, rendered the way GitHub renders Markdown | the test project |

The diagram sources are [Mermaid](https://mermaid.js.org). GitHub renders the inline copies in the docs directly. The PNGs are for places that don't render Mermaid, and for the README.

**Re-rendering after you edit a diagram:**
1. Edit the `.mmd` file.
2. If the docs page has an inline copy, update it too.
3. Render the PNG, for example with the Mermaid CLI:

```
npx -y @mermaid-js/mermaid-cli -i docs/images/src/flows.mmd -o docs/images/flows.png -b white -s 2
```

You can also paste the source into the [Mermaid live editor](https://mermaid.live) and export a PNG.

A `;` inside a sequence-diagram message ends the statement early and breaks the diagram. Use a comma or parentheses instead.
