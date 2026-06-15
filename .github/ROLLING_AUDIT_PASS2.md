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
- Checked so far:
  - `forge`: fail
  - `wizardry-desktop`: fail
  - `chatroom`: fail
  - `bellheim`: fail
  - `binder`: no frontend-derived backend path found in focused scan
  - `dictator`: native-generated backend path variance, not this frontend category
  - `counterspell`: fail
  - `fauxzilla`: no frontend-derived backend execution found in focused scan
  - `matchbook`: fail
  - `book-club`: no frontend-derived backend execution found in focused scan
  - `organizer`: no frontend-derived backend execution found in focused scan
  - `simplerchat`: fail
  - `applegate`: no frontend-derived backend execution found in focused scan
  - `eye`: fail
  - `mecha`: fail
  - `pieplate`: fail
  - `serenity`: no frontend-derived backend execution found in focused scan; separate shell-fragment bridge finding already recorded
  - `stellar`: no frontend-derived backend execution found in focused scan
  - `boycott`: fail already recorded in round-1 report
  - `pleroma`: fail already recorded in round-1 report

### `cargo-runtime-layer-present`
- Late criterion source:
  - `pleroma`
- Standard:
  - Shipped app runtime paths should not compile Cargo-managed helpers on demand.
- Needs re-check:
  - all repos with `Cargo.toml`, generated native helpers, or runtime toolchain probing
- Checked so far:
  - built-in `forge`, `wizardry-desktop`, and `chatroom`: no Cargo-managed shipped runtime layer found
  - `bellheim`, `binder`, `dictator`, `counterspell`, and `fauxzilla`: no Cargo-managed shipped runtime layer found in focused scan
  - `matchbook`, `book-club`, `organizer`, and `simplerchat`: no Cargo-managed shipped runtime layer found in focused scan
  - `applegate`, `eye`, `mecha`, `pieplate`, `serenity`, `stellar`, and `boycott`: no Cargo-managed shipped runtime layer found in focused scan
  - `pleroma`: fail already recorded; direct Cargo-managed runtime helper build remains the known violation

### `app-local-theme-system-documented`
- Late criterion source:
  - `matchbook`
  - `pleroma`
  - `hegelizer`
- Standard candidate:
  - Apps either use shared Wizardry themes correctly or explicitly declare an app-local theme system and its behavior contract.
- Needs re-check:
  - every app with a theme picker, hardcoded palette list, or `data-theme`/theme class contract
- Checked so far:
  - `forge`: pass; shared Wizardry themes are backend-discovered, sorted, and keyboard-cyclable
  - `wizardry-desktop`: fail; shared-theme backend discovery exists, but frontend fallback catalog is hardcoded, unsorted, and closed-picker cycling is missing
  - `bellheim`: fail; shared-theme backend discovery and closed-picker cycling exist, but frontend still carries a hardcoded fallback catalog
  - `binder`: fail for generated native target variance; macOS generated app discovers shared themes, but Linux generated/template code still appends a static theme list
  - `book-club`: no app theme picker surfaced in focused scan
  - `boycott`: fail; frontend owns an undeclared hardcoded app theme list and ordering is not alphabetic
  - `counterspell`: no app theme picker surfaced in focused scan
  - `dictator`: no app theme picker surfaced in focused scan
  - `eye`: no app theme picker surfaced in focused scan
  - `fauxzilla`: no Wizardry app theme picker surfaced in focused scan
  - `hegelizer`: fixed monochrome palette; acceptable only if documented as an app-local fixed-palette exception
  - `matchbook`: app-local theme system; not counted as shared-theme failure, but requires explicit local exception documentation
  - `mecha`: fail; shared-theme backend discovery exists, but frontend fallback catalog is hardcoded and not alphabetized
  - `organizer`: no app theme picker surfaced in focused scan
  - `pieplate`: fixed/public website visual theme rather than Wizardry theme picker in focused scan
  - `pleroma`: app-local theme preset system with closed-picker arrow cycling; not counted as shared-theme failure, but requires explicit local exception documentation
  - `serenity`: fail; claims Wizardry app themes but starts from a hardcoded frontend catalog and browser-owned theme bootstrap
  - `simplerchat`: fail; backend discovery exists and closed-picker cycling works, but frontend fallback catalog remains hardcoded and `psionic` is pinned before alphabetic order
  - `stellar`: no Wizardry theme picker surfaced; has app-local bubble color preferences and mobile native platform theme constants outside the shared-theme picker contract

### `repo-local-ai-exception-ledger`
- Late criterion source:
  - `serenity`
  - `stellar`
  - `boycott`
  - `pleroma`
- Standard:
  - A repo-local AI-facing document must list local language, storage, theme, runtime, and test exceptions.
- Required shape:
  - import the canonical upstream standards by path
  - name every approved or pending language boundary
  - name the durable storage root and any deviation from `~/<appname>`
  - state whether user-facing editable files use YAML plus Markdown-oriented text, JSON, key-value text, browser storage, or another format
  - classify theme behavior as shared Wizardry themes, app-local theme system, fixed palette, or no theme system
  - name backend/native/runtime bridge boundaries, including who owns backend path resolution
  - name test entrypoints under `.tests/` and any known gaps
  - name release/build/generated-output roots and say where disposable cruft belongs
- Needs re-check:
  - every repo marked `repo-ai-standards-missing`
  - every repo whose local docs only point upstream without enumerating local exceptions
- Checked so far:
  - `applegate`: fail; no local AI-facing exception ledger beyond audit report
  - `bellheim`: fail; no local AI-facing exception ledger beyond audit report
  - `binder`: fail; no local AI-facing exception ledger beyond audit report
  - `book-club`: fail; `.github/AI_DOCS.md` redirects upstream but does not enumerate local generated-native or Python helper boundaries
  - `boycott`: fail; no local AI-facing exception ledger beyond audit report
  - `counterspell`: fail; `.github/README.md` is a thin pointer and does not enumerate Python or Swift exceptions
  - `dictator`: fail; no local AI-facing exception ledger beyond audit report
  - `eye`: fail; no local AI-facing exception ledger beyond audit report
  - `fauxzilla`: fail; no local AI-facing exception ledger beyond audit report
  - `hegelizer`: fail; no local AI-facing exception ledger beyond audit report
  - `matchbook`: fail; no local AI-facing exception ledger beyond audit report
  - `mecha`: fail; no local AI-facing exception ledger beyond audit report
  - `organizer`: fail; no local AI-facing exception ledger beyond audit report
  - `pieplate`: fail; no local AI-facing exception ledger beyond audit report
  - `pleroma`: fail; no local AI-facing exception ledger beyond audit report
  - `serenity`: fail; `.github/CODEX.md` is feature-specific and omits storage/language/theme/runtime/test exceptions
  - `simplerchat`: fail; no local AI-facing exception ledger beyond audit report
  - `stellar`: fail; no local AI-facing exception ledger beyond audit report
  - `theurgy`: partial pass for project-local AI docs, but generated app defaults still need the same ledger shape
  - `wizardry-apps`: partial pass for repo-local AI docs; the built-in `tools/check-gh-issue.py` language exception should be moved from implicit inventory to an explicit exception ledger

### `backend-contract-tests-missing`
- Late criterion source:
  - `serenity`
  - `boycott`
- Standard:
  - Every shipped app needs backend contract coverage under `.tests/`.
- Needs re-check:
  - every repo whose round-1 report predates this explicit category
- Checked so far:
  - `applegate`: backend coverage present under `.tests/scripts/test-applegate-backend.sh`
  - `bellheim`: backend coverage present under `.tests/apps/test-bellheim-backend.sh`
  - `binder`: backend coverage present under `.tests/native/test-backend-contract.sh`
  - `book-club`: native/calls/relay/security coverage present under `.tests/`
  - `boycott`: partial; canonical backend contract coverage now exists under `.tests/`, but UI/static coverage and other repo findings remain
  - `counterspell`: shell and CGI contract coverage present under `.tests/`
  - `dictator`: partial; voice regression surface now exposed under `.tests/voice/run.sh`, but broader release-side normalization still remains
  - `eye`: shell/runtime coverage present under `.tests/test-eye.sh`
  - `fauxzilla`: broad API/runtime coverage present under `.tests/`
  - `hegelizer`: partial; canonical `.tests/` entrypoints now exist, but the smoke harness is still red and GUI/static contract depth remains thin
  - `matchbook`: backend coverage present under `.tests/apps/test-matchbook-backend.sh`
  - `mecha`: backend/static contract coverage present under `.tests/test-mecha-contracts.sh`
  - `organizer`: backend contract coverage present under `.tests/backend-contract.sh`
  - `pieplate`: backend coverage present under `.tests/test-pieplate.sh`
  - `pleroma`: partial; canonical `.tests/` entrypoints now exist, but broader runtime-boundary and path-ownership findings remain
  - `serenity`: partial; canonical `.tests/` contract entrypoints now exist, but the current backend and theme contract checks are intentionally red until the underlying violations are removed
  - `simplerchat`: backend coverage present under `.tests/backend/`
  - `stellar`: backend coverage present under `.tests/native/test-backend-contract.sh`

### `ui-static-tests-missing`
- Late criterion source:
  - built-in `chatroom`
  - later native app audits
- Standard:
  - Every shipped GUI app needs UI/static contract coverage under `.tests/`.
- Needs re-check:
  - every repo that has backend tests but no GUI/static tests
- Checked so far:
  - `applegate`: fail; backend and guardian tests exist, but no dedicated native GUI/static contract under `.tests/`
  - `bellheim`: UI/static coverage present under `.tests/apps/test-bellheim-ui-contract.sh` plus Safari/file-boot smoke tests
  - `binder`: generated native IR/render/native package coverage present under `.tests/native/`
  - `book-club`: GUI/native coverage present under `.tests/gui/` and `.tests/native/`
  - `boycott`: fail; no `.tests/` tree
  - `counterspell`: shell contract includes app-surface assertions under `.tests/`
  - `dictator`: fail; no `.tests/` GUI/static contract
  - `eye`: fail; `.tests/test-eye.sh` covers shell/runtime behavior only
  - `fauxzilla`: extension/UI behavior coverage present under `.tests/`
  - `hegelizer`: fail; UI/runtime smoke tests live outside `.tests/`
  - `matchbook`: UI/static coverage present under `.tests/apps/test-matchbook-ui-contract.sh` and `.tests/apps/test-matchbook-frontend.mjs`
  - `mecha`: static/UI inventory coverage present under `.tests/test-mecha-contracts.sh`
  - `organizer`: native IR validation and render/compile readiness coverage present under `.tests/release-ready.sh`
  - `pieplate`: UI/static coverage present under `.tests/test-pieplate.sh`, but the suite is red under the existing `validation-suite-red` finding
  - `pleroma`: fail; Safari smoke test lives under `app/tests/`, not `.tests/`
  - `serenity`: fail; no `.tests/` tree
  - `simplerchat`: frontend/static coverage present under `.tests/frontend/test-frontend-contract.sh`
  - `stellar`: native IR/render/mobile coverage present under `.tests/native/`

### `variance.reasoned`
- Late criterion source:
  - user direction after first pass
- Standard candidate:
  - Any meaningful app-to-app difference must be decisioned into a standard, an approved exception, or a pending decision record.
- Needs re-check:
  - all repos and all generated templates
- Status:
  - variance ledger is populated and all current variance items now have `standard-proposed` status
  - pre-fix-it review queue is recorded in `.github/ROLLING_AUDIT_PASS2_DECISION_QUEUE.md`

### `repo-cruft-and-build-artifact-discipline`
- Late criterion source:
  - user direction during pass 2
- Standard candidate:
  - Apps should not create build artifacts, package outputs, caches, compiled helper outputs, scratch workspaces, runtime logs, or other disposable cruft inside source repos unless the files are deliberate fixtures.
  - Use temp, XDG cache/state, or another explicit external build root for disposable outputs.
- Status:
  - audited in this pass at source-checkout level
  - canonical comprehensive `.gitignore` seed is now in `phronesis`: `/Users/andersaamodt/git/phronesis/standards/repo-hygiene/wizardry-general.gitignore`
- Needs re-check:
  - all app repos
  - generated templates and Forge build/release flows
- Checked so far:
  - `wizardry-apps`: tracked `spells/web/build` is an executable spell, not a build directory; ignored `.log` and `apps/forge/.log` are local cruft symptoms
  - `applegate`: ignored `.log` and `app-blueprint/.log` present; no tracked suspicious build artifact found in focused scan
  - `bellheim`: ignored `.log` present; no tracked suspicious build artifact found in focused scan
  - `binder`: ignored `.log` present; no tracked suspicious build artifact found in focused scan
  - `book-club`: ignored `.log` present; no tracked suspicious build artifact found in focused scan
  - `boycott`: fail; tracked empty `.log` file
  - `counterspell`: ignored `.log` present; no tracked suspicious build artifact found in focused scan
  - `dictator`: ignored `.log` present; no tracked suspicious build artifact found in focused scan
  - `eye`: ignored `.log` and `app/.log` present; no tracked suspicious build artifact found in focused scan
  - `fauxzilla`: ignored `.log` and `extension-src/.log` present; no tracked suspicious build artifact found in focused scan
  - `hegelizer`: ignored `.log` present; no tracked suspicious build artifact found in focused scan
  - `matchbook`: ignored `.log`, `app/.log`, and `node_modules/` present; dependency cache in checkout needs cleanup/source attribution
  - `mecha`: fail; tracked empty `.log`; ignored `app/.log` also present
  - `organizer`: ignored `.log` present; no tracked suspicious build artifact found in focused scan
  - `pieplate`: fail; tracked empty `.log` and `app/.log`
  - `pleroma`: fail; tracked empty `.log` and `app/.log`; ignored `.build/` and `dist/` present
  - `serenity`: fail; tracked empty `.log`; ignored `app/.log` also present
  - `simplerchat`: ignored `.log` present; no tracked suspicious build artifact found in focused scan
  - `stellar`: ignored `.log`, `generated/macos/.log`, and `stellar-mobile/.log` present; no tracked suspicious build artifact found in focused scan
  - `theurgy`: ignored `.log` present; no tracked suspicious build artifact found in focused scan
- Pass-2 distinction:
  - tracked `.log` placeholders are direct repo-source violations
  - ignored local `.log` files are checkout hygiene evidence; fix-it should identify and stop the writer if they are generated by normal tooling
  - ignored `node_modules/`, `.build/`, and `dist/` are disposable output currently present in checkouts; fix-it should move or clean their producer paths when source-owned

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
- `ROLLING_AUDIT_PASS2_DECISION_QUEUE.md`
- `ROLLING_AUDIT_VARIANCE_LEDGER.yaml`
- updates to `ROLLING_AUDIT_PROPOSED_STANDARDS.md`
- updates to per-app `ROLLING_AUDIT.md` reports only when a late criterion is newly applied
- updates to shared category ledger when a late criterion finds new affected apps
