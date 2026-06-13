# Rolling Audit Proposed Standards

## Purpose
- Collect standards discovered during the rolling audit that should likely be promoted into canonical Wizardry-family guidance before the fix-it phase.
- Keep this list separate from already-canonical policy so we can review, approve, and then integrate the good ones intentionally.
- Prefer short, implementation-neutral rules that can later be enforced through docs, templates, shared code, or tests.

## Current Proposals

### Storage And State
- Most Wizardry apps should store their primary durable app data under `~/<appname>`, with alternate standard-folder layouts treated as explicit exceptions rather than defaults.
- If an app does use standard folders such as XDG config/state or macOS Application Support, prefer app-owned roots like `${XDG_CONFIG_HOME:-$HOME/.config}/<appname>` or `Application Support/<appname>` rather than shared cross-app namespace paths such as `wizardry-apps/<appname>`.
- Durable app data should stay plain-text by default.
- YAML plus Markdown-oriented text should be the preferred format family for user-facing durable files and human-edited project contracts.
- JSON is acceptable for app-facing machine state, typed envelopes, caches, and ABI contracts whose primary consumer is the app rather than the user.
- Browser extension storage should not be the only durable home for user secrets, pending sync queues, identity state, or other canonical app data; if browser-owned storage is used, keep it cache-like or mirror canonical state into an app-owned plain-text contract.
- Browser or WebView local storage may be used only as a short-lived bootstrap cache when a canonical file-backed preference contract remains authoritative and can fully restore state.
- Browser or WebView local storage should not hold durable authentication secrets, pairing secrets, or account-recovery material as the canonical contract.
- Repo checkouts should never become app-instance state directories. User settings, runtime logs, temp homes, browser profiles, caches, and similar operator-local cruft should live outside the checkout.
- Build artifacts, generated release products, scratch workspaces, package-manager caches, compiled helper outputs, and other disposable cruft should not be created inside app source repos unless they are deliberate checked-in fixtures; use temp, XDG cache/state, or another explicit external build root.
- Generated project defaults should not normalize repo-local runtime-state directories inside new source trees.
- Generated staging trees for native or web build pipelines should remain disposable and rerender-safe even after normal local tool artifacts appear inside them.

### Tests And Auditability
- Wizardry-family test entrypoints should live under `.tests/`.
- Tests under `app/tests/`, `tools/release/`, or ad hoc root `tests/` can be migrated as useful evidence, but they should not count as compliant shipped-app test entrypoints until exposed under `.tests/`.
- Shipped apps need backend contract coverage under `.tests/`; UI-only or manual validation is not enough.
- For native apps, IR/schema validation alone should not count as sufficient GUI coverage; add a `.tests/` UI/static regression surface for the shipped native shell or generated output.
- Existing audit surfaces should be treated as active contracts and must be refreshed when they become stale; stale audit tables are a standards violation, not harmless historical clutter.
- Approved exceptions should be documented in repo-local AI-facing docs where the next auditor will actually look.
- Repo-local AI docs should name the repo’s own storage and language exceptions explicitly, not only redirect readers to upstream canonical docs.
- Repo-local AI docs should enumerate local storage, language, theme, runtime, test, release, and generated-output boundaries in one predictable exception ledger shape.
- The repo-local exception ledger shape should include upstream import paths, approved or pending language boundaries, durable storage root, user-facing file formats, theme-system classification, bridge/backend/native ownership, `.tests/` entrypoints and gaps, release/build/generated-output roots, and disposable-cruft policy.
- A repo-local AI doc that only redirects to upstream canonical docs is insufficient when the repo has local generated-native, Python, Rust, Swift, Node, storage, theme, build-output, or bridge exceptions.
- A feature-specific `CODEX.md` can coexist with the ledger, but it should not be the only AI-facing standards surface unless it also covers the full local exception contract.
- AI-facing standards docs should not contain contradictory approved patterns; one canonical pattern should win.
- Checked-in config examples and copyable setup templates should match current runtime defaults exactly; stale legacy-path examples are a standards violation.

### Language And Boundary Discipline
- Wizardry is POSIX `sh`-first; Python and Rust are opt-in exceptions, not ambient permission.
- When a native port or higher-runtime app retains Python, Rust, Swift, Node, or other non-shell surfaces, each retained boundary should be explicitly justified.
- If a native port reuses another app's runtime or storage roots, that should be documented as an explicit exception rather than presented as ordinary layout.
- GNU-specific tool behavior should not be relied on silently in shell-first repos; if a GNU dependency is real, document it and test it, otherwise replace it with a POSIX-safe path.
- Frontends should never derive backend executable paths from `window.location`, served-document paths, or other frontend-owned filesystem guesses; backend resolution belongs to the host or backend contract.
- Native or generated app shells may resolve packaged backend resources only inside the approved host/native boundary; development fallback paths and environment overrides should be documented and tested as native-boundary exceptions.
- Shipped app runtime paths should not compile Cargo-managed helpers on demand; retained Rust helpers should live behind an explicitly approved packaged host or Theurgy boundary instead of ordinary repo-owned backend execution.

### Themes And GUI
- If an app intentionally uses an app-local theme system instead of the shared Wizardry themes, document that choice explicitly so audits know whether to apply the shared-theme contract or an app-local design contract.
- Forge-generated Wizardry apps should default to shared Wizardry themes unless the app declares an explicit app-local theme identity.
- App-local theme systems should still define their own keyboard, ordering, persistence, and full-depth application contract.
- Apps that use Wizardry themes should discover the real shared Wizardry theme set rather than keep app-local hardcoded theme catalogs.
- Generated native targets that expose Wizardry themes should consume the same discovered shared theme catalog on every platform; static generated platform option lists are drift even if another platform target already discovers themes correctly.
- Theme lists should be alphabetized consistently at the contract source.
- When a focused theme picker is closed, up/down arrow keys should still cycle themes correctly.
- Theme application should be deep and complete across the whole app shell rather than partial decoration over un-themed surfaces.
- Apps with no theme picker or a fixed palette should document that as an intentional app-local visual contract, not leave auditors to infer whether shared themes were forgotten.
- Built-in app settings should live in the main shell by default rather than a second document or iframe.
- Passive reads and status refreshes should never mutate durable app state.
- Fallback UX should prefer guided inline state over `alert()` or send-away instructions.
- Theme ordering should be fully alphabetic at the authoritative contract source; “default theme first” special-casing is a standards drift, not a feature.

### Runtime Health And Updates
- Apps that expose self-update should render published release notes in-app before the user applies an update.
- Apps with optional external transports or relays should expose a guided live sanity-check flow that verifies a real end-to-end send/receive path against the canonical filesystem corpus, not only configuration presence.

### Framework And Process
- Meaningful unreasoned app-to-app variance should be treated as standards debt.
- Every significant app difference should become a canonical standard, an approved exception class, or a pending decision record.
- Recurring audit problems should be tracked under stable category IDs so cross-app remediation can happen problem-by-problem instead of app-by-app.
- New standards should be pushed into the earliest enforceable layer available: canonical docs first, then templates, shared hosts/backends, generators, and tests.
- Ecosystem-wide standards, exception schemas, audit method, decision records, and policy IDs should be extracted into a `phronesis` repository so implementation repos can stay focused.
- A machine-readable app policy matrix should track each app's status for every policy ID, including passes, failures, approved exceptions, and evidence links.
- The app policy matrix should use stable status values (`pass`, `fail`, `exception-approved`, `pending-decision`, `not-applicable`, `unknown`, `not-audited`) so generators, audits, and fix-it planning can share one compliance vocabulary.

## Promotion Rule
- Before the fix-it phase, review this list and decide which items should become canonical Wizardry standards.
- After approval, integrate accepted rules into the relevant Wizardry-family docs and example/reference apps so new projects start closer to audit-pass posture.
