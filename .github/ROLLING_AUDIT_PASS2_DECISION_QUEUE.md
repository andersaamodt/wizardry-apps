# Rolling Audit Pass 2 Decision Queue

## Purpose
- Collect standards and exception classes that should be reviewed before the fix-it phase.
- Keep decision work separate from remediation work.
- Feed accepted decisions into `phronesis`, Wizardry-family docs, templates, generators, and tests.

## Status
- Date: 2026-06-13
- Phase: pre-fix-it review queue
- Source:
  - `.github/ROLLING_AUDIT_VARIANCE_LEDGER.yaml`
  - `.github/ROLLING_AUDIT_PROPOSED_STANDARDS.md`
  - `/Users/andersaamodt/git/phronesis/`

## Ready To Promote

### `variance.reasoned`
- Proposed standard: meaningful unreasoned app-to-app variance is standards debt.
- Decision: approve as a founding `phronesis` principle.
- Enforcement target: policy matrix plus rolling audit method.

### `storage.app-home-default`
- Proposed standard: primary durable app state defaults to `~/<appname>`.
- Exception class: dot-app roots and standard-folder roots are allowed only when documented and app-owned.
- Reject as default: shared namespaces such as `wizardry-apps/<appname>` and domain roots unless explicitly approved.

### `storage.plain-text` and `format.user-yaml-md`
- Proposed standard: durable app data is plain text by default.
- Preferred user-facing format: YAML plus Markdown-oriented text.
- Allowed machine-facing format: JSON for app-facing state, typed envelopes, caches, and ABI contracts.

### `tests.dot-tests`
- Proposed standard: runnable test entrypoints live under `.tests/`.
- Exception class: none for Wizardry apps; other paths may hold fixtures/helpers only.

### `docs.exception-ledger-shape`
- Proposed standard: every app with local exceptions has a repo-local AI-facing exception ledger.
- Required headings: language, storage, durable formats, themes, runtime/bridge ownership, tests, release/build/generated output, approved exceptions, pending decisions.

### `themes.shared-catalog-authority`
- Proposed standard: apps using wizardry themes discover the real shared theme catalog.
- Exception class: app-local theme systems and fixed palettes are allowed only when documented as app identity and held to their own keyboard, ordering, persistence, and depth contract.

### `themes.native-shared-catalog-parity`
- Proposed standard: generated native targets exposing shared wizardry themes must use the same discovered catalog across platform outputs.
- Reject as default: one platform discovering themes while another embeds a static generated option list.

### `bridge.backend-resolution-owned`
- Proposed standard: frontend code must not infer backend executable paths from document locations.
- Required direction: host/backend owns path resolution; frontend calls actions.

### `bridge.no-shell-fragments`
- Proposed standard: frontends never send shell fragments or `sh -c` bridge payloads.
- Required direction: bridge actions are named and argv-bounded.

### `runtime.no-cargo-on-demand`
- Proposed standard: shipped runtime paths do not compile Cargo-managed helpers on demand.
- Exception class: Rust helpers belong behind packaged host or theurgy boundaries.

### `repo.no-disposable-cruft`
- Proposed standard: source repos do not receive tracked placeholders, logs, caches, build products, package outputs, dependency caches, or app-instance state.
- Canonical ideal document: `/Users/andersaamodt/git/phronesis/standards/repo-hygiene/wizardry-general.gitignore`.

## Resolved In User Review

### `language.exception-ledger`
- Decision:
  - current audit fix-it policy: existing Python runtime surfaces are removal-default unless explicitly re-approved
  - forward-looking standard: Python is acceptable but non-preferred relative to POSIX `sh`
  - Rust is the preferred non-shell language when a non-shell language is necessary
  - C and C++ are acceptable when necessary for low-level, performance-critical, or ecosystem-constrained work
- Additional rule:
  - non-shell boundaries still belong in the repo-local exception ledger

### `themes.app-local`
- Decision:
  - wizardry apps that use shared themes follow the standardized wizardry theming contract
  - app-local themes and fixed palettes are allowed when explicitly documented as app identity
  - Forge-generated apps are not required to default to shared themes automatically

### `native.host-boundary`
- Decision:
  - generated native hosts may know packaged backend and resource paths inside the host-owned native boundary
  - frontend and web surfaces may not infer those paths
  - development fallbacks and environment overrides must be documented and tested

### `repo.ignore-canonicality`
- Decision:
  - phronesis owns the canonical ideal document
  - repos import the canonical phronesis `.gitignore` verbatim unless an explicit exemption is documented

## Fix-It Batch Order After Approval
1. Add or expand repo-local exception ledgers from the phronesis template.
2. Remove unauthorized or unapproved Python runtime boundaries.
3. Normalize storage roots and document approved exceptions.
4. Move tests into `.tests/` and fill backend/UI coverage gaps.
5. Remove hardcoded/shared-theme drift and generated-native theme catalog drift.
6. Move backend path resolution and bridge execution behind host/backend contracts.
7. Remove tracked `.log` placeholders and stop checkout-local disposable output generation.
