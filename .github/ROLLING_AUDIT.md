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
- Record recurring violations under stable category names so later reports can be grouped by problem class instead of only by app.
- Prefer category-first aggregation for round summaries: severity first, then recurrence count, then affected apps.

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
- Most Wizardry apps should store their primary durable app data under `~/<appname>`.
- An app may use other standard config or state folders when there is a concrete project-specific reason, but that exception must be explicit in repo-facing documentation and easy for the next auditor to find.
- Shared storage roots between a native app and another app/runtime must be explicitly justified; they are not the default.
- All durable app data should live in plain-text files unless a different format is clearly necessary.
- For durable files users are likely to inspect or edit directly, prefer YAML plus Markdown-oriented text conventions over JSON.
- JSON is acceptable for app-facing machine state, caches, transport payloads, or other files whose primary consumer is the app rather than the user.
- Durable app state must not depend on browser-owned storage.
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
- Apps that use Wizardry themes must discover available themes from the real Wizardry theme set rather than from a hardcoded app-local list.
- Theme picker lists should be alphabetized consistently.
- When a closed theme picker has focus, up/down arrow keys should cycle themes correctly without requiring the menu to open first.
- Theme application should be deep and complete across the app shell, not partial decoration layered on top of un-themed surfaces.
- Built-in apps should integrate settings into the primary app shell; loading a separate settings document in an iframe counts as drift unless the app is explicitly designed as a document multiplexer.
- Use semantic controls and roles instead of inline `onclick` anchors or other placeholder-era interaction patterns.
- Avoid `alert()`-driven fallback UX and imperative “go run this in a terminal” messaging when the app can present durable inline state and guided next actions.

### 6. Native And Host Boundary Discipline
- Native host code belongs in `apps/.host` or generated native output trees, not mixed into ordinary app UI logic.
- Host-specific behavior such as boot splash, drag regions, file-drop bridges, or menu behavior should remain host-owned and verifiable in the host layer.
- Cross-platform app shells should not reimplement native/runtime concerns ad hoc inside each app.

### 7. Testing And Release Readiness
- Tests belong under `.tests/` in a Wizardry app repo.
- Every shipped app needs backend contract coverage.
- Every shipped GUI app also needs a UI/static contract or regression surface, not only backend shell tests.
- High-risk app flows need adversarial coverage, especially bridge actions, path handling, persistence, run/build/install flows, and drag/drop.
- Release/readiness claims require matching tests or explicit documented gaps.

### 8. Documentation And Auditability
- AI-facing standards belong in `.github/`.
- If an exception is real, document it where the next auditor will actually look.
- Audit notes should cite the canonical section names instead of restating full policy text.

## Criteria Learned In Round 1
- Shared cross-app namespace roots are still drift even in standard platform folders like Application Support, not only in XDG paths.
- For native apps, IR/schema validation alone does not satisfy the GUI contract requirement; the shipped native shell still needs `.tests/` UI/static regression coverage.
- A shipped app with no backend contract coverage under `.tests/` fails the testing axis even if manual or UI-facing behavior exists.
- Repo-local AI docs must enumerate repo-specific exception boundaries; pointing only to upstream canonical docs is not enough when the repo retains real local exceptions.
- Passive status and refresh paths must not write prefs or other durable app state.
- Built-in app settings should be part of the main app shell, not a second HTML document mounted in an iframe.
- Built-in app fallback UX should avoid `alert()` and imperative “Please start...” messaging in favor of inline guided status.
- Frontends should not scrape `/cgi/system-info` or similar generic diagnostics for core endpoint or identity state when a backend action should provide that contract.
- Frontends should not derive backend executable paths from `window.location`, served document paths, or similar frontend-owned filesystem guesses; the host or backend contract should own backend resolution.
- Every shipped GUI app should have both backend tests and UI/static contract tests.
- Rolling audit results must include an explicit non-shell language inventory with justification.
- Most Wizardry apps should default to `~/<appname>` for durable app data; alternate standard folders and shared storage roots need explicit justification.
- Durable app data should stay plain-text by default, with YAML-plus-Markdown preferred for user-facing editable files and JSON reserved for app-facing machine state.
- Wizardry app tests belong under `.tests/`.
- If a native port reuses another app's runtime or storage roots, that exception must be documented in repo-local AI-facing docs, not only in the user README.
- Apps that use Wizardry themes must source the actual available theme set, keep picker behavior keyboard-correct, keep the list alphabetized, and apply theming deeply rather than cosmetically.
- Shipped app runtime paths should not compile Cargo-managed helpers on demand; if a Rust helper is retained at all, it belongs in an explicitly approved packaged host or Theurgy boundary rather than ordinary repo-owned backend execution.
