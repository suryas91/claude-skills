---
name: playwright-testing
description: Playwright end-to-end testing rules for writing, reviewing and de-flaking browser tests - role-based locators, web-first assertions, isolated tests with fixtures and storageState, a flaky-test taxonomy and proof-of-fix, and review anti-patterns. Use when writing or reviewing Playwright tests, setting up Playwright, or fixing a failing or flaky e2e test.
---

# Playwright testing

Ported from claude-skills' playwright-pro (MIT, (c) 2025 Alireza Rezvani, https://github.com/alirezarezvani/claude-skills), adapted to this team's rules. The reference files in `references/` are copied from it unchanged. Where they disagree with the **Team overrides** below, the overrides win.

## Golden rules
1. **Locate by role first.** `getByRole()` over CSS or XPath: it survives markup changes and mirrors assistive technology. Full priority list below.
2. **Never `page.waitForTimeout()`, and never `waitForLoadState('networkidle')`.** Wait for something the user would see (`await expect(locator).toBeVisible()`), for a URL (`await expect(page).toHaveURL(...)`), or for a specific response (`page.waitForResponse('**/api/x')`, started before the action that triggers it).
3. **Use web-first assertions.** `await expect(locator)...` retries until timeout. `expect(await locator.textContent())` and `expect(await locator.isVisible())` check once and flake.
4. **Isolate every test.** No shared mutable state and no dependence on execution order (tests run in parallel). Create each test's data through the API or a fixture, and make identifiers unique.
5. **Put `baseURL` in the config** and use relative `page.goto('/login')`. Never hardcode a host.
6. **Use fixtures, not globals.** Share setup with `test.extend()`. Log in once with a setup project plus `storageState`, not through the UI in every test (see `references/fixtures.md`).
7. **One behaviour per test.** Several related assertions are fine. Name the test after the behaviour and the AC (`AC-3: shows an error when the email is invalid`).
8. **Mock only what you don't own.** Third-party APIs, payment gateways and email are mocked with `page.route()`. Your own app and API are never mocked in e2e tests.
9. **Test failure paths.** Every main journey has at least one error path, such as `page.route('**/api/x', r => r.fulfill({ status: 500 }))` showing the error state. Also cover empty states and permission-denied cases.
10. **Always await.** A missing `await` on a Playwright call causes random passes.

## Locator priority
Use the first one that works (details and a role cheat sheet in `references/locators.md`):
1. `getByRole('button', { name: 'Save' })`: buttons, links, headings, form controls, dialogs, tables
2. `getByLabel('Email address')`: labelled form fields
3. `getByText('Welcome back')`: non-interactive text
4. `getByPlaceholder()`, `getByAltText()`, `getByTitle()`
5. `getByTestId('checkout-summary')`: only when no semantic option exists
6. `page.locator(css)`: last resort. If you need it for an interactive control, the control is probably missing an accessible name, which is an accessibility bug to report.

Narrow with `.filter({ hasText })`, `.filter({ has })` and chaining (`getByRole('navigation').getByRole('link', { name: 'Settings' })`).

## Structure
- Use a page object for a page with 5 or more locators. Page objects expose intent (`login(email, password)`) and use the locators above.
- Keep test data in fixtures or factories, not magic strings spread across tests.
- Use at most 2 levels of `test.describe()`. Split tests over about 50 lines.
- Collect console errors: `page.on('console', m => m.type() === 'error' && errors.push(m.text()))`, then assert the list is empty for main journeys.
- Add `toHaveScreenshot()` only for visually critical components, at a pinned viewport.

## Config (starting point)
```ts
export default defineConfig({
  use: { baseURL: process.env.BASE_URL ?? 'http://localhost:3000', trace: 'on-first-retry', screenshot: 'only-on-failure' },
  retries: process.env.CI ? 1 : 0,        // see Team overrides
  forbidOnly: !!process.env.CI,           // a stray test.only fails CI
  webServer: { command: 'npm run start', url: 'http://localhost:3000', reuseExistingServer: !process.env.CI },
  projects: [{ name: 'setup', testMatch: /.*\.setup\.ts/ },
             { name: 'chromium', use: { storageState: '.auth/user.json' }, dependencies: ['setup'] }],
});
```
Add `.auth/` and `test-results/`, `playwright-report/` to `.gitignore`. Upload the report and traces as CI artifacts on failure.

## Flaky tests
Flaky tests are bugs. Diagnose them with `references/flaky-taxonomy.md`:
| Category | Signature | Typical fix |
|---|---|---|
| Timing/async | fails with `--repeat-each=20` locally | web-first assertions, wait for the specific response, add the missing await |
| Isolation | passes alone (`--workers=1 --grep`), fails in the suite | per-test data, clear storage, isolated contexts |
| Environment | fails in CI only | pinned viewport, UTC, fonts; mock external services |
| Infrastructure | random browser crashes, OOM | fewer workers, more memory |

Capture a trace with `--trace=on --retries=0`, fix the cause, then **prove the fix: `npx playwright test <file> --repeat-each=10` must pass 10/10**. Put that run's output in your report. One green run is not proof.

## Review checklist (for your own tests and for reviewing others')
**Critical:** `waitForTimeout` or `networkidle`, non-web-first assertions, hardcoded URLs, CSS or XPath where a role exists, a missing `await`, shared mutable state, order dependence, `test.only`, a mock of your own app.
**Warning:** tests over 50 lines, generic names, no error or empty-state case, `page.evaluate()` where a locator would do, `describe` nested deeper than 2, magic strings.
**Info:** a page with 5 or more locators and no page object, no console-error check on main journeys, no accessibility assertion on key controls.
Details and examples are in `references/anti-patterns.md` and `references/common-pitfalls.md`.

## Team overrides (these win over the references)
- **Retries don't make a test pass.** CI may use `retries: 1` only so a trace gets captured. A test that passes only on retry is reported as **FLAKY** with its attempt count and fixed as a bug. Never raise retries to get green. Where the references say "add retries: 2", ignore it.
- **Reviewers report fixes and don't apply them.** When reviewing someone else's tests (code-reviewer, verifier), list the fixes and don't edit. playwright-pro's "apply fixes" step doesn't apply here.
- **Prove that new tests can fail** (test-engineer rule): run each new test against the base commit in a temporary worktree and show it failing.
- **Stay in your own files.** Test files and test config only, per the ownership table.
