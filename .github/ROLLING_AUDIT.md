# Wizardry Apps Rolling Audit

## Purpose
- Define one canonical cross-app audit rubric for `wizardry-apps`.
- Start from existing Wizardry and Wizardry Apps standards, then record new audit criteria as they are discovered.
- Keep the audit broad enough to cover language, architecture, storage, execution, GUI, tests, and release posture, not just visual polish.

## Rolling Rule
- Audit apps in sequence and update this rubric as soon as a new recurring bug class or drift pattern is discovered.
- Apply new criteria to every remaining app in the current pass.
- On the next pass, re-audit earlier apps against the expanded rubric so all apps converge on the same bar.
- If a new criterion is only GUI-specific, also add it to `.github/GUI_AUDIT.md`.
- If a new criterion changes repo policy, also add it to the most obvious AI-facing source file in `.github/`.

## First-Pass Scope
- Built-in shipped app surfaces named by `.github/GUI_AUDIT.md`: `forge`, `wizardry-desktop`, and `chatroom`.
- Shared host/runtime/tooling surfaces are in scope only when they directly justify or violate an app audit finding.

## Canonical Inputs
- `README.md`
- `~/.wizardry/.github/PUSH_READY_CHECKLIST.md`
- `~/.wizardry/.github/AUDIT.md`
- `~/.wizardry/.github/PACT_LANGUAGE.md`
- `.github/AI_DOCS.md`
- `.github/WIZARDRY_APPS_ETHOS.md`
- `.github/WIZARDRY_APPS_GUI_STANDARDS.md`
- `.github/GUI_AUDIT.md`
- `.github/GUI_LESSONS.md`
- `.github/adversarial-testing.md`
- `.github/RELEASE_POLISH.md`

## Output Contract
- Produce per-app pass or fail notes with concrete evidence paths.
- Separate app-specific findings from repo-wide criteria discovered during the pass.
- Treat a missing test surface or undocumented language exception as an audit finding, not as a note to maybe revisit later.
- If a finding is safe to fix during the audit, fix it and update the standards in the same change.

## Audit Axes

### 1. Language And Boundary Discipline
- `wizardry-apps` is POSIX `sh`-first for orchestration, repo control, backends, tests, and release helpers.
- Rust is not allowed as a direct runtime layer here; no Cargo-managed runtime should appear in repo-owned app machinery.
- Swift, Objective-C, Kotlin, Java, and other platform-native languages are acceptable only in boundary-owned host wrappers, generated outputs, or clearly designated native template/reference surfaces.
- Python is an exception language, not ambient permission. Any retained Python file needs an explicit justification tied to a narrow tool or integration job.
- New non-shell implementation languages require explicit user approval before introduction.
- Theurgy is the approved boundary for substantial native-runtime or enterprise-runtime fan-out when shell stops being the right orchestration layer.
- Audit result must enumerate every non-shell language surface actually present and state why it is acceptable or why it is debt.

### 2. Wizardry Ethos And CLI Parity
- The GUI must stay a thin skin over transparent backend behavior.
- A GUI capability should map to an existing or newly added backend action, not a GUI-only side path.
- User-facing flows should remain menu-driven, file-first, minimal, and discoverable.
- Built-in apps should expose calm descriptive language and avoid decorative or generic-product framing that breaks Wizardry identity.

### 3. Storage And State Discipline
- All durable app data should live in plain-text files unless a different format is clearly necessary.
- For durable files users are likely to inspect or edit directly, prefer YAML plus Markdown-oriented text conventions over JSON.
- JSON is acceptable for app-facing machine state, caches, transport payloads, or other files whose primary consumer is the app rather than the user.
- Durable app state belongs in app-owned XDG config or state paths, not browser-owned storage.
- Passive reads, status refreshes, and startup hydration must not mutate durable state.
- Deployment-specific paths such as site names, served-site roots, or machine-local bundle locations must not become the canonical durable state home for desktop apps.
- Repo-local generated files, logs, and staging artifacts must stay out of tracked source unless they are deliberate fixtures.

### 4. Execution And Security Boundary
- Frontends must call hardcoded backend actions through explicit argv arrays.
- Frontends must not fall back to `sh -c`, free-form shell fragments, or path-scraping execution tricks when a backend action or host boundary should own the resolution.
- User input must not choose executable names or arbitrary argv tails.
- Endpoint, path, and metadata discovery should happen in backend actions, not through ad hoc frontend scraping of unrelated CGI/debug surfaces.
- Read and write validators must be consistent across create, edit, import, rename, run, build, release, and install paths.

### 5. GUI Contract
- Follow `.github/WIZARDRY_APPS_GUI_STANDARDS.md` and `.github/GUI_AUDIT.md`.
- Theme controls, keyboard support, fit-content controls, split-pane behavior, and settings/drawer patterns are mandatory where applicable.
- Built-in apps should integrate settings into the primary app shell; loading a separate settings document in an iframe counts as drift unless the app is explicitly designed as a document multiplexer.
- Use semantic controls and roles instead of inline `onclick` anchors or other placeholder-era interaction patterns.
- Avoid `alert()`-driven fallback UX and imperative “go run this in a terminal” messaging when the app can present durable inline state and guided next actions.

### 6. Native And Host Boundary Discipline
- Native host code belongs in `apps/.host` or generated native output trees, not mixed into ordinary app UI logic.
- Host-specific behavior such as boot splash, drag regions, file-drop bridges, or menu behavior should remain host-owned and verifiable in the host layer.
- Cross-platform app shells should not reimplement native/runtime concerns ad hoc inside each app.

### 7. Testing And Release Readiness
- Every shipped app needs backend contract coverage.
- Every shipped GUI app also needs a UI/static contract or regression surface, not only backend shell tests.
- High-risk app flows need adversarial coverage, especially bridge actions, path handling, persistence, run/build/install flows, and drag/drop.
- Release/readiness claims require matching tests or explicit documented gaps.

### 8. Documentation And Auditability
- AI-facing standards belong in `.github/`.
- If an exception is real, document it where the next auditor will actually look.
- Audit notes should cite the canonical section names instead of restating full policy text.

## Criteria Learned In Round 1
- Passive status and refresh paths must not write prefs or other durable app state.
- Built-in app settings should be part of the main app shell, not a second HTML document mounted in an iframe.
- Built-in app fallback UX should avoid `alert()` and imperative “Please start...” messaging in favor of inline guided status.
- Frontends should not scrape `/cgi/system-info` or similar generic diagnostics for core endpoint or identity state when a backend action should provide that contract.
- Every shipped GUI app should have both backend tests and UI/static contract tests.
- Rolling audit results must include an explicit non-shell language inventory with justification.
