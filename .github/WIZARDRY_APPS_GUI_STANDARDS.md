# Wizardry Apps GUI Standards (AI-Facing)

## Scope
- This file defines GUI implementation standards for Wizardry desktop and hosted app surfaces.
- Use this with `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_ETHOS.md`.

## Core GUI Posture
- GUIs are operational consoles, not decorative wrappers detached from backend truth.
- A GUI action should map to one explicit backend action whenever possible.
- Keep flows legible: users should understand what action just ran and what changed.
- Keep startup resilient: detect bridge readiness and retry gracefully before failing hard.
- Build GUIs with care and polish; avoid rushed or placeholder-feeling interfaces.
- Never ship half-ass GUI work; finish layout, spacing, and state feedback details.
- Always use app theme colors/tokens instead of ad-hoc hardcoded color choices.

## Command and Bridge Rules
- Bridge calls use explicit argv arrays passed to `wizardry.rpc('bridge.exec', { argv })`.
- Commands are selected from code-defined allowlists, not free-form user text.
- Avoid building shell fragments from user input; prefer positional args.
- Keep backend entrypoints in `scripts/*-backend.sh` and expose stable action names.
- Return machine-readable output for structured UI paths and plain text for logs.

## Storage Rules
- Desktop persistence goes through backend `get-ui-prefs` and `set-ui-pref` style actions.
- Persisted values live in plaintext key-value files under XDG config/state roots.
- Browser `localStorage` is not a desktop durability layer.
- In hosted-web-first apps, `localStorage` use can be acceptable when documented.
- Cache values in memory first, then sync to backend on change.

## Workflow Design Rules
- Replace “go do X and come back” with in-app guided workflows.
- Multi-step flows should expose current step, next step, and completion criteria.
- If an external action is required, pair instruction with immediate verification control.
- Gate sensitive actions behind explicit confirmation in the same interface.
- Surface undo/revert actions when behavior is irreversible or high-impact.

## Startup Boot Pattern
- Desktop apps should avoid showing intermediate paints during startup.
- Use a native host boot splash when first paint quality matters, centered on the app icon.
- Match host window/root background to the active app theme background during boot.
- Resolve boot palette from backend config/plaintext files, not browser `localStorage`.
- Keep WebView background transparent while boot splash is active to avoid white/theme flashes.
- Remove splash only after web UI signals readiness via a bridge hook (`__wizardry_host_boot_ready`).

## Feedback and Error Handling
- Show command status, outcome, and stderr/stdout context in-app.
- Keep status text factual and non-imperative.
- Prefer progress + result messaging over silent background work.
- Use short toasts for confirmation and durable panels for actionable errors.
- Keep logs inspectable and copyable from the GUI.

## Discoverability and Navigation
- Keep primary actions visible without deep nesting.
- Group actions by user intent, not by internal implementation layers.
- Keep settings easy to find and clearly separate global vs project state.
- Use consistent labels for repeated concepts across apps.
- Prefer one-screen comprehension over hidden routes and modal mazes.

## Admin List Pages
- Prefer row-based management tables over card grids for dense admin lists (users, drafts, posts, queue).
- Use full-width rows with alternating subtle background tint for scanability.
- Keep each row concise, ideally one-line with compact pills for status/source metadata.
- Put destructive or advanced actions behind a compact overflow menu to reduce visual noise.
- Keep list pages live-updating when visible, but pause refresh while menus/actions/drag operations are active.

## Port and Runtime Safety
- Never hardcode a fixed localhost port for embedded site URLs.
- Resolve runtime port from canonical config files like `site.conf`.
- Handle port conflicts by selecting safe alternatives through backend actions.
- Show the resolved runtime endpoint in the UI when it matters.

## File and Path Conventions
- Keep app entrypoint at `.apps/<slug>/index.html`.
- Keep app backend at `.apps/<slug>/scripts/<slug>-backend.sh` when backend logic exists.
- Keep app-scoped docs in `.apps/<slug>/README.md` for runtime paths and operator notes.
- Keep naming consistent with hyphenated app slugs.

## Accessibility and Input Ergonomics
- Use semantic controls and keyboard-operable interactions.
- Keep focus states visible and modal escape paths obvious.
- Avoid click-only critical actions; support keyboard submission where practical.
- Avoid defaulting buttons and short text-entry inputs to `width: 100%`; size them to content or a bounded width unless full-width is required by layout.
- Keep motion subtle and meaningful, never required for comprehension.

## Button Patterns
- Use an unobtrusive icon button pattern for low-emphasis in-field actions like copy/reveal helpers.
- Unobtrusive icon buttons render with no border and no background at rest.
- On hover/focus, unobtrusive icon buttons gain a compact opaque background and small rounded corners.
- Keep unobtrusive icon buttons keyboard-focusable with a visible focus state.
- Position in-field unobtrusive icon buttons inside the input wrapper with absolute positioning and preserve input text padding so content never overlaps the icon.

## AI Agent Delivery Rules
- Prefer surgical edits that preserve each app’s existing visual language.
- Extend shared patterns already present in Forge/Priorities/Virtual Redditor first.
- When introducing a new pattern, document it in this file within the same change.
- Avoid speculative frameworks or architectural rewrites without explicit user request.
