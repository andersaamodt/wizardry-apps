# Rolling Audit Pass 2

## Purpose
- Re-audit the first-pass scope with the full rubric accumulated during round 1.
- Prepare the `phronesis` extraction by separating ecosystem standards from repo-local implementation details.
- Identify unreasoned app-to-app variance and convert it into proposed standards, approved exceptions, or pending decisions.

## Status
- Started: 2026-06-13
- Phase: audit and standards preparation only
- Fix-it phase: not started

## Pass 2 Rules
- Do not remediate app code during this pass unless the user explicitly switches to fix-it work.
- Treat every meaningful difference between apps as requiring a standard, approved exception, or pending decision.
- Prefer policy-level findings over implementation anecdotes.
- Back-apply late round-1 criteria to earlier audited apps before declaring a category complete.
- Record possible `phronesis` extraction candidates immediately, even if promotion waits for user approval.

## Back-Application Checklist

### `frontend-derived-backend-path`
- Late criterion source:
  - `boycott`
  - `pleroma`
- Standard:
  - Frontend code must not derive backend executable paths from `window.location`, document paths, or relative path guesses.
- Needs re-check:
  - `applegate`
  - `bellheim`
  - `binder`
  - `book-club`
  - `counterspell`
  - `dictator`
  - `eye`
  - `fauxzilla`
  - `forge`
  - `hegelizer`
  - `matchbook`
  - `mecha`
  - `organizer`
  - `pieplate`
  - `serenity`
  - `simplerchat`
  - `stellar`
  - `wizardry-desktop`
  - `chatroom`

### `cargo-runtime-layer-present`
- Late criterion source:
  - `pleroma`
- Standard:
  - Shipped app runtime paths should not compile Cargo-managed helpers on demand.
- Needs re-check:
  - all repos with `Cargo.toml`, generated native helpers, or runtime toolchain probing

### `app-local-theme-system-documented`
- Late criterion source:
  - `matchbook`
  - `pleroma`
  - `hegelizer`
- Standard candidate:
  - Apps either use shared Wizardry themes correctly or explicitly declare an app-local theme system and its behavior contract.
- Needs re-check:
  - every app with a theme picker, hardcoded palette list, or `data-theme`/theme class contract

### `repo-local-ai-exception-ledger`
- Late criterion source:
  - `serenity`
  - `stellar`
  - `boycott`
  - `pleroma`
- Standard:
  - A repo-local AI-facing document must list local language, storage, theme, runtime, and test exceptions.
- Needs re-check:
  - every repo marked `repo-ai-standards-missing`
  - every repo whose local docs only point upstream without enumerating local exceptions

### `backend-contract-tests-missing`
- Late criterion source:
  - `serenity`
  - `boycott`
- Standard:
  - Every shipped app needs backend contract coverage under `.tests/`.
- Needs re-check:
  - every repo whose round-1 report predates this explicit category

### `ui-static-tests-missing`
- Late criterion source:
  - built-in `chatroom`
  - later native app audits
- Standard:
  - Every shipped GUI app needs UI/static contract coverage under `.tests/`.
- Needs re-check:
  - every repo that has backend tests but no GUI/static tests

### `variance.reasoned`
- Late criterion source:
  - user direction after first pass
- Standard candidate:
  - Any meaningful app-to-app difference must be decisioned into a standard, an approved exception, or a pending decision record.
- Needs re-check:
  - all repos and all generated templates

## Initial Round 2 Audit Order
1. Built-in Wizardry Apps surfaces:
   - `forge`
   - `wizardry-desktop`
   - `chatroom`
2. Earlier app audits that predate the late bridge/runtime criteria:
   - `bellheim`
   - `binder`
   - `dictator`
   - `counterspell`
   - `fauxzilla`
3. Clean or reference-like apps to classify as standard examples:
   - `matchbook`
   - `book-club`
   - `organizer`
   - `simplerchat`
4. Apps with broad existing violation clusters:
   - `pieplate`
   - `serenity`
   - `pleroma`
   - `boycott`

## Pass 2 Outputs
- `PHRONESIS_EXTRACTION_PLAN.md`
- `ROLLING_AUDIT_VARIANCE_LEDGER.yaml`
- updates to `ROLLING_AUDIT_PROPOSED_STANDARDS.md`
- updates to per-app `ROLLING_AUDIT.md` reports only when a late criterion is newly applied
- updates to shared category ledger when a late criterion finds new affected apps
