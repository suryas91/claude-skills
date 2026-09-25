# Exploratory QA: issue taxonomy and page checklist

Used by the verifier's exploratory pass in the final check. Adapted from gstack's `/qa` issue taxonomy (MIT, © 2026 Garry Tan, https://github.com/garrytan/gstack). See NOTICE.md.

The acceptance criteria prove the planned behavior works. The exploratory pass looks for what nobody planned for: use the app like a real user, on the pages and flows this change touched, and report what breaks.

## Severity

| Severity | Definition | Examples |
|---|---|---|
| **critical** | Blocks a core workflow, loses data or crashes the app | Submit shows an error page, data deleted without confirmation |
| **high** | A major feature is broken or unusable, with no workaround | Search returns wrong results, upload silently fails, auth redirect loop |
| **medium** | Works, but with noticeable problems; a workaround exists | Page loads in over 5s, layout broken on mobile only, validation missing but submit still works |
| **low** | Cosmetic or polish | Typo, 1px misalignment, inconsistent hover state |

Map severity to routing: critical and high are **FAIL** for the final check. Medium goes to the owner as a fix unless the user accepts it at Gate 2. Low is listed at Gate 2.

## Categories

1. **Visual/UI:** overlapping or clipped elements, horizontal scroll, broken images, z-index problems, dark-mode problems, animation glitches.
2. **Functional:** dead buttons, broken links, missing or bypassable form validation, wrong redirects, state lost on refresh or back, double-submit, stale data.
3. **UX:** no loading indicator, over 500ms with no feedback, vague errors ("Something went wrong"), no confirmation before destructive actions, dead ends.
4. **Content:** typos, placeholder text, truncated text without an ellipsis, wrong labels, missing or unhelpful empty states.
5. **Performance:** page load over 3s, layout shift after load, jank, over 50 requests on one page, huge images.
6. **Console/network:** uncaught JS errors, failed requests (4xx/5xx), CORS, mixed content, CSP violations, hydration warnings.
7. **Accessibility:** unlabeled inputs, missing alt text, keyboard traps, no visible focus, broken tab order, insufficient contrast.

## Per-page checklist

For each page or flow the change touched:
1. **Look:** take a screenshot at desktop width and scan for layout problems.
2. **Click everything interactive:** buttons, links, menus, toggles. Does each do what its label says?
3. **Forms:** submit empty, submit invalid data, very long text, special characters and emoji, and double-click submit.
4. **Navigation:** back button, refresh mid-flow, deep link straight to the page.
5. **States:** empty, loading, error (for example with the backend stopped or a request failing), full or overflowing.
6. **Console and network:** read the console messages and failed network requests after interacting.
7. **Responsive:** repeat steps 1-2 at phone width (390px) when the page is user-facing.
8. **Keyboard:** tab through the main flow; focus is visible and never trapped.
9. **AI features:** slow response, cancel mid-stream, model error, empty or very long output.

## Evidence per issue

```
QA-<n> [severity] [category] <page/flow> — <what happens>
  Repro: <steps>
  Expected: <what should happen>
  Evidence: <screenshot path, console line, or network status>
  Owner: <persona>
```

Save screenshots under `.playwright-mcp/` (already gitignored), never in the project source.

Stay local. Never sign out, switch accounts, submit to production services, send real emails or payments, or follow delete, cancel or unsubscribe links on non-local targets.
