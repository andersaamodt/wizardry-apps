# Wizardry Apps AI Docs Map

## Read Order
- Read `/Users/andersaamodt/git/wizardry-apps/README.md` for repo stance and boundaries.
- Read `/Users/andersaamodt/.wizardry/.github/PUSH_READY_CHECKLIST.md` for canonical repo-hygiene, artifact, and publish-surface rules.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_ETHOS.md` for policy and tone.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_LICENSING.md` before changing licensing, scaffolding, starter templates, emitted project files, or Forge project-generation behavior.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_GUI_STANDARDS.md` for mandatory GUI patterns and behavior contracts.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/RELEASE_POLISH.md` when doing 1.0 polish, onboarding/readiness work, update surfaces, packaging, or Nostr-specific release hardening.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/GUI_AUDIT.md` when doing cross-app GUI sweeps so audits stay source-linked and non-redundant.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/adversarial-testing.md` when doing adversarial testing, security-minded bug hunts, release hardening, or GUI edge-case sweeps.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/GUI_LESSONS.md` for known host/WebView pitfalls and regression lessons.
- For new cross-platform app shells, reference `/Users/andersaamodt/git/wizardry-apps/templates/forge/web/reference-app/` first; for native-style desktop app shells, reference `/Users/andersaamodt/git/wizardry-apps/templates/forge/native-desktop/reference-app/` first. Keep the relevant reference updated when Wizardry standards evolve; the native reference should show platform-owned controls plus live backend snapshot hydration, especially JSON-Glib-backed GTK row/detail rebuilding on Linux.
- Keep one user-facing repo README at `/Users/andersaamodt/git/wizardry-apps/README.md`; do not add app-local or template-local README files.
- Put app-specific implementation notes in `.github/` when they are AI-facing, or fold user-facing summaries into the root README.

## Canonicality
- Wizardry core ethos in `~/.wizardry/README.md` is upstream-canonical.
- Wizardry core push-readiness and repo-hygiene rules in `~/.wizardry/.github/PUSH_READY_CHECKLIST.md` are upstream-canonical.
- This repo may specialize rules for GUI/runtime concerns without violating upstream ethos.
- If specialization conflicts with upstream, prefer upstream unless user instruction overrides.

## Technical Repo Map
- `spells/web` and `spells/.arcana/web-wizardry` are migrated from `~/.wizardry`.
- `spells/.arcana/wizardry-apps` owns the top-level app pipeline arcana and menus.
- `templates/web` templates are migrated from `~/.wizardry/web`.
- `apps` desktop app surfaces are migrated from `~/.wizardry/apps`.
- `apps/.host` owns shared macOS, Linux, iOS, Android, and bridge host code.
- Android app assets are staged into disposable projects with `tools/release/prepare-android-host.sh`; do not commit staged Android assets under `apps/.host`.
- `apps/forge` owns the App Forge desktop control plane.
- `assets/stock/` is a flat convenience shelf of reusable non-app-specific icons/SVGs; canonical runtime assets stay under `apps/<slug>/assets`.
- `runtime/config/` defines production release allowlists and Forge template configuration.
- `runtime/schemas/` contracts define RPC, events, metadata, and native desktop IR formats.
- `runtime/core/` owns wizardry-core runtime contracts and implementation.
- `runtime/adapters/` contains shell and HTTP/CGI reference adapters.
- CI workflows in `.github/workflows/` implement lint, test, build, and release gates.

## Local Validation Commands
- Validate manifests with `sh tools/validate-manifest.sh`.
- Run core tests with `sh runtime/core/tests/test_core.sh`.
- Run adapter tests with `.tests/adapters/test-*.sh`.
- Run wizardry-apps arcana tests with `.tests/.arcana/wizardry-apps/test-*.sh`.
- Run flagship desktop app tests with `.tests/apps/test-*.sh`.
- Run release helper tests with `.tests/release/test-*.sh`.

## Arcana And Sync Notes
- Open the top-level apps arcana with `spells/.arcana/wizardry-apps/wizardry-apps`.
- Use `spells/.arcana/wizardry-apps/wizardry-apps web-admin` for web app administration.
- Use `spells/.arcana/wizardry-apps/wizardry-apps desktop-admin` for desktop app administration.
- Use `spells/.arcana/wizardry-apps/wizardry-apps mobile-admin` for mobile app administration.
- Use `tools/sync-from-wizardry.sh` for all upstream imports from `~/.wizardry`.
- No other import path is considered canonical.
- The sync preserves local `apps/.host` ownership for native desktop and mobile hosts.

## Authoring Style For AI Docs
- Keep docs as flat bullet lists.
- Keep bullets to short one-liners when possible.
- Keep guidance concrete, testable, and path-specific.
- Add new policy where agents will actually look first.
