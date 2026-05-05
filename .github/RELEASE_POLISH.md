# Wizardry App Release Polish (AI-Facing)

## Use This File When
- Use this file when taking a Wizardry app from "works" to "1.0 release-ready."
- Read this after ethos, push-readiness, and GUI standards; it is a polish checklist, not a replacement for those sources.
- Update this file when a recurring 1.0 lesson shows up across multiple apps.

## 1.0 Baseline For Any Wizardry App
- Ship a startup path that always exits splash/boot cleanly and explicitly signals host readiness.
- Add first-run guidance when the app has any non-obvious storage, identity, permission, or external-service setup.
- Keep setup requirements explicit: required vs optional must be obvious in both onboarding and settings.
- Add a readiness surface that reports `ready`, `missing`, or `degraded` for every critical dependency.
- Every degraded or disabled state must explain `why` and `what to do next`.
- Prefer one clear next action per blocked surface over passive warning copy.
- Add a guided sanity-check flow for the app's primary success path.
- Replace one-off alerts with a consistent toast/feedback system plus durable inline error copy.
- Make "why didn't this happen?" answerable from logs or visible state.
- Separate persistent status from transient confirmations.
- Keep controls dense and fit-to-content; do not widen buttons/selects/short inputs without a real reason.
- Use visual hierarchy, spacing, and typography instead of nested decorative rounded containers.
- Add empty states for all first-use collections and optional subsystems.
- Add compact advanced disclosures instead of cluttering the primary path.
- Add update detection for published releases only; do not nag on arbitrary git movement.
- Support one-click update only on install modes that can be updated safely in place.
- Detect unsupported install/update modes cleanly and give exact guidance instead of pretending to update.
- Add static UI contract tests for critical IDs, modes, and anti-regression checks.
- Add backend contract tests for persistence, capability probes, and error-path behavior.
- Keep tests POSIX-sh entrypoints under `.tests/` and keep test output outside the repo.
- Add packaging/release workflows before calling an app 1.0; release polish includes distribution, not just UI.

## Native Desktop 1.0 Minimum
- Native macOS apps must build with a warning-free `swift build` and launch as packaged `.app` bundles.
- Native macOS apps must use platform-owned titlebar/menu/window behavior, not WebView-style custom chrome.
- Native macOS apps must keep long backend/process work off the main actor.
- Native macOS apps must verify row hit targets, native search fields, native file panels, and in-place text editing in a running app.
- Native GTK apps must compile in CI with GTK development headers and keep generated source covered by render contracts.
- Native GTK apps must keep long backend/process work off the GTK main loop.
- Native GTK apps must use native search entries, listboxes, headerbar controls, file choosers, password entries, and application accelerators.
- Native GTK apps with backend/domain state must exercise structured snapshot hydration into native widgets; do not release a Linux port whose primary rows are static generated placeholders while macOS reads live model state.
- Native desktop release notes should state which platform runtimes were actually built and smoke-tested.

## Readiness Surface Minimum
- Include permissions, local storage/config roots, external services, hardware/runtime bridge, and updates when relevant.
- Show `last tested` and `last successful` timestamps where the dependency can drift over time.
- Treat fallback modes as `degraded`, not `ready`.
- Keep the readiness surface available after onboarding; it becomes the maintenance page.

## Onboarding Minimum
- Explain what the app is, what is stored locally, and where that data lives.
- Gate irreversible or high-risk setup behind a deliberate confirmation when appropriate.
- Require backup verification for generated secrets or identities.
- End onboarding with a real test of the primary workflow, not just a completion message.

## Update/Release Minimum
- Build only from tagged releases for user-facing update suggestions.
- Publish checksums for every release artifact.
- Smoke-test packaged artifacts, not just source checkouts.
- Keep release notes user-readable and scoped to what changed in the app.
- For macOS signing/notarization or equivalent platform trust steps, fail closed with explicit CI preflight checks.

## Nostr Wizardry App Minimum
- Accept the formats users actually paste: hex, `npub`, `nsec`, `lud16`, LNURL, and NWC/wallet endpoints where relevant.
- Normalize and label recognized Nostr/Lightning input immediately.
- Explain identity setup in plain language; do not assume prior Nostr or Lightning literacy.
- Keep social identity optional unless the app truly cannot function without it.
- Preserve usefulness when relays, profiles, or wallet services are degraded.
- Show last-known-good relay/profile/wallet state instead of collapsing to "offline."
- Seed a small relay set only when the app benefits from it, and keep relay editing explicit and inspectable.
- Make manual-entry-only social models explicit when discovery is intentionally unsupported.
- Log and expose the ring/action decision path: no match, status filtered, sender blocked, profile required, silence/local suppression, or service unavailable.
- Treat wallet routing and zap thresholds as user-visible policy, not hidden app logic.
- Add live-relay smoke tests against at least one public relay and one local Stonr relay when the app depends on relay behavior.
- Ship a Stonr app-support profile when the app relies on specific relay capabilities.
- Validate shipped Stonr support profiles with `stonr print-autoconfig --file ...` in the app repo test suite when Stonr is available.

## Remote/Hardware Wizardry App Minimum
- Keep the local app authoritative for user policy and compiled timing.
- Push final schedules to the remote execution host when timing accuracy depends on that host.
- Add secure-secret storage integration only when the host supports it; otherwise fall back to session-only input with explicit messaging.
- Test remote prerequisites before offering install/update actions.
- Install remote helpers idempotently and fail with guided remediation when the target host is unsuitable.
- Keep hardware failure fallback automatic and visible; never drop queued work because hardware failed.
