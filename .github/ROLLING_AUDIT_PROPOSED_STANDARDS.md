# Rolling Audit Proposed Standards

## Purpose
- Collect standards discovered during the rolling audit that should likely be promoted into canonical Wizardry-family guidance before the fix-it phase.
- Keep this list separate from already-canonical policy so we can review, approve, and then integrate the good ones intentionally.
- Prefer short, implementation-neutral rules that can later be enforced through docs, templates, shared code, or tests.

## Current Proposals

### Storage And State
- Most Wizardry apps should store their primary durable app data under `~/<appname>`, with alternate standard-folder layouts treated as explicit exceptions rather than defaults.
- If an app does use standard folders such as XDG config/state, prefer app-owned roots like `${XDG_CONFIG_HOME:-$HOME/.config}/<appname>` rather than shared cross-app namespace paths such as `wizardry-apps/<appname>`.
- Durable app data should stay plain-text by default.
- YAML plus Markdown-oriented text should be the preferred format family for user-facing durable files and human-edited project contracts.
- JSON is acceptable for app-facing machine state, typed envelopes, caches, and ABI contracts whose primary consumer is the app rather than the user.
- Browser extension storage should not be the only durable home for user secrets, pending sync queues, identity state, or other canonical app data; if browser-owned storage is used, keep it cache-like or mirror canonical state into an app-owned plain-text contract.
- Browser or WebView local storage may be used only as a short-lived bootstrap cache when a canonical file-backed preference contract remains authoritative and can fully restore state.
- Repo checkouts should never become app-instance state directories. User settings, runtime logs, temp homes, browser profiles, caches, and similar operator-local cruft should live outside the checkout.
- Generated project defaults should not normalize repo-local runtime-state directories inside new source trees.

### Tests And Auditability
- Wizardry-family test entrypoints should live under `.tests/`.
- Existing audit surfaces should be treated as active contracts and must be refreshed when they become stale; stale audit tables are a standards violation, not harmless historical clutter.
- Approved exceptions should be documented in repo-local AI-facing docs where the next auditor will actually look.
- AI-facing standards docs should not contain contradictory approved patterns; one canonical pattern should win.
- Checked-in config examples and copyable setup templates should match current runtime defaults exactly; stale legacy-path examples are a standards violation.

### Language And Boundary Discipline
- Wizardry is POSIX `sh`-first; Python and Rust are opt-in exceptions, not ambient permission.
- When a native port or higher-runtime app retains Python, Rust, Swift, Node, or other non-shell surfaces, each retained boundary should be explicitly justified.
- If a native port reuses another app's runtime or storage roots, that should be documented as an explicit exception rather than presented as ordinary layout.
- GNU-specific tool behavior should not be relied on silently in shell-first repos; if a GNU dependency is real, document it and test it, otherwise replace it with a POSIX-safe path.

### Themes And GUI
- Apps that use Wizardry themes should discover the real shared Wizardry theme set rather than keep app-local hardcoded theme catalogs.
- Theme lists should be alphabetized consistently at the contract source.
- When a focused theme picker is closed, up/down arrow keys should still cycle themes correctly.
- Theme application should be deep and complete across the whole app shell rather than partial decoration over un-themed surfaces.
- Built-in app settings should live in the main shell by default rather than a second document or iframe.
- Passive reads and status refreshes should never mutate durable app state.
- Fallback UX should prefer guided inline state over `alert()` or send-away instructions.
- Theme ordering should be fully alphabetic at the authoritative contract source; “default theme first” special-casing is a standards drift, not a feature.

### Runtime Health And Updates
- Apps that expose self-update should render published release notes in-app before the user applies an update.
- Apps with optional external transports or relays should expose a guided live sanity-check flow that verifies a real end-to-end send/receive path against the canonical filesystem corpus, not only configuration presence.

### Framework And Process
- Recurring audit problems should be tracked under stable category IDs so cross-app remediation can happen problem-by-problem instead of app-by-app.
- New standards should be pushed into the earliest enforceable layer available: canonical docs first, then templates, shared hosts/backends, generators, and tests.

## Promotion Rule
- Before the fix-it phase, review this list and decide which items should become canonical Wizardry standards.
- After approval, integrate accepted rules into the relevant Wizardry-family docs and example/reference apps so new projects start closer to audit-pass posture.
