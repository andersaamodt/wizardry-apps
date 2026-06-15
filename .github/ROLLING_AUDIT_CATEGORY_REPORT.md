# Rolling Audit Category Report

## Status
- Snapshot date: 2026-06-13
- Scope: current audited Wizardry-family repos and built-in `wizardry-apps` surfaces already covered by the rolling audit
- Purpose: keep a category-first remediation map so the fix-it phase can proceed problem-by-problem instead of app-by-app
- Source of truth:
  - `.github/ROLLING_AUDIT_LEDGER.yaml`
  - repo-local `ROLLING_AUDIT.md` reports
  - `.github/ROLLING_AUDIT_RESULTS.md` for built-in `wizardry-apps` app surfaces
- First-pass coverage is complete for the currently tracked Wizardry-family scope.

## Highest-Priority Categories

### 1. `python-exception-undocumented`
- Severity: high
- Recurrence: 10 repos
- Affected:
  - `binder`
  - `book-club`
  - `counterspell`
  - `dictator`
  - `fauxzilla`
  - `organizer`
  - `pieplate`
  - `serenity`
  - `simplerchat`
  - `stellar`
- Why it ranks first:
  - This is the broadest high-severity recurring language-discipline problem found so far.
  - It cuts across native ports, shell-first apps, extension-plus-hub architecture, and mixed hosted/desktop repos.
- Batch fix direction:
  - decide repo-by-repo whether Python is being removed or explicitly retained
  - where retained, add a repo-local exception ledger in `.github/`
  - where not retained, plan replacement in shell, Rust, or other explicitly approved boundaries

### 2. `repo-local-exception-ledger-incomplete`
- Severity: medium
- Recurrence: 18 app repos
- Affected:
  - `applegate`
  - `bellheim`
  - `binder`
  - `book-club`
  - `boycott`
  - `counterspell`
  - `dictator`
  - `eye`
  - `fauxzilla`
  - `hegelizer`
  - `matchbook`
  - `mecha`
  - `organizer`
  - `pieplate`
  - `pleroma`
  - `serenity`
  - `simplerchat`
  - `stellar`
- Why it ranks near the top:
  - It is now the broadest recurring governance failure found in the app repos.
  - It also blocks clean remediation of language, storage, theme, build-output, and bridge exceptions because the accepted boundaries are not recorded where agents look first.
- Batch fix direction:
  - create the `phronesis` repo-local exception-ledger template first
  - then add or expand each app’s local AI docs from that template
  - require explicit entries for language, storage root, durable format, theme system, bridge/runtime ownership, `.tests/` coverage, release/build/generated-output roots, and repo-cruft policy

### 3. `repo-ai-standards-missing`
- Severity: medium
- Recurrence: 15 repos
- Affected:
  - `boycott`
  - `applegate`
  - `binder`
  - `dictator`
  - `eye`
  - `fauxzilla`
  - `hegelizer`
  - `matchbook`
  - `mecha`
  - `organizer`
  - `pleroma`
  - `pieplate`
  - `serenity`
  - `simplerchat`
  - `stellar`
- Why it ranks near the top:
  - This is currently the broadest recurring documentation/governance gap.
  - It directly slows every future audit and makes exception handling too implicit.
- Batch fix direction:
  - add a minimal repo-local `.github` standards note template
  - require each repo to list storage exceptions, language boundaries, and any accepted architecture-specific variance

### 4. `validation-suite-red`
- Severity: high
- Recurrence: 4 repos
- Affected:
  - `hegelizer`
  - `pieplate`
  - `stellar`
  - `theurgy`
- Why it ranks high:
  - A red claimed validation suite blocks confidence in the contract layer directly.
- Batch fix direction:
  - restore each repo’s canonical validation suite to green before treating the contract surface as stable

### 5. `storage-default-home-missing`
- Severity: high
- Recurrence: 7 repos
- Affected:
  - `boycott`
  - `dictator`
  - `hegelizer`
  - `mecha`
  - `pleroma`
  - `pieplate`
  - `stellar`
- Why it ranks high:
  - This is a direct miss against the default Wizardry durable-state posture.
- Batch fix direction:
  - migrate primary durable state to `~/<appname>` where appropriate
  - otherwise promote a narrow documented exception instead of treating the current layout as ordinary

### 6. `browser-owned-durable-state`
- Severity: high
- Recurrence: 4 repos
- Affected:
  - `boycott`
  - `fauxzilla`
  - `pieplate`
  - `serenity`
- Why it ranks high:
  - This combines high-severity storage drift with user-secret and identity-state risk.
- Batch fix direction:
  - narrow browser-owned storage to cache/bootstrap use and move canonical durable state and secrets into app-owned explicit contracts

### 7. `ui-static-tests-missing`
- Severity: high
- Recurrence: 4 repos
- Affected:
  - `applegate`
  - `chatroom`
  - `dictator`
  - `eye`
- Why it ranks high:
  - These are shipped GUI surfaces without matching UI/static contract protection.
- Batch fix direction:
  - add lightweight DOM/static/bridge tests first
  - only then rely on backend tests as sufficient for release confidence

### 8. `backend-contract-tests-missing`
- Severity: high
- Recurrence: 0 repos
- Affected:
  - none
- Why it ranks high:
  - These repos either had no `.tests/` tree or kept relevant backend/smoke tests outside the required `.tests/` surface.
  - Without backend contract tests under `.tests/`, bridge and runtime changes cannot be audited consistently.
- Batch fix direction:
  - keep converting partial/red repos into green, higher-depth contract coverage
  - retain `.tests/` as the canonical entrypoint surface for all future fixes

## High-Severity Single-Repo Categories

### 9. `generated-state-in-checkout`
- Affected:
  - `theurgy`
- Fix direction:
  - generated defaults must stop normalizing runtime state into source trees

### 10. `standards-guidance-contradictory`
- Affected:
  - `wizardry`
- Fix direction:
  - choose one canonical shell pattern and delete the conflicting one from AI-facing docs

### 11. `settings-shell-split`
- Affected:
  - `chatroom`
- Fix direction:
  - move settings into the main shell

### 12. `read-path-mutates-state`
- Affected:
  - `chatroom`
- Fix direction:
  - separate read/hydration from persistence

## Medium-Severity Recurring Categories

### 13. `language-exception-undocumented`
- Severity: medium
- Recurrence: 10 repos
- Affected:
  - `bellheim`
  - `book-club`
  - `counterspell`
  - `fauxzilla`
  - `matchbook`
  - `organizer`
  - `pleroma`
  - `pieplate`
  - `stellar`
  - `simplerchat`
- Batch fix direction:
  - enumerate all non-shell boundaries in local standards notes

### 14. `storage-exception-undocumented`
- Severity: medium
- Recurrence: 7 repos
- Affected:
  - `boycott`
  - `binder`
  - `dictator`
  - `hegelizer`
  - `mecha`
  - `pleroma`
  - `pieplate`
- Batch fix direction:
  - document real storage exceptions where auditors look first

### 15. `shared-xdg-app-namespace`
- Severity: medium
- Recurrence: 8 repos
- Affected:
  - `boycott`
  - `book-club`
  - `counterspell`
  - `hegelizer`
  - `mecha`
  - `pleroma`
  - `pieplate`
  - `stellar`
- Batch fix direction:
  - if XDG roots remain, move them to app-owned names rather than `wizardry-apps/...` or `wizardry/...`

### 16. `tracked-repo-cruft-placeholder`
- Severity: medium
- Recurrence: 5 repos
- Affected:
  - `boycott`
  - `mecha`
  - `pieplate`
  - `pleroma`
  - `serenity`
- Batch fix direction:
  - remove tracked empty `.log` placeholders
  - use the phronesis canonical `.gitignore` and create runtime/log paths outside source checkouts

### 17. `disposable-output-in-checkout`
- Severity: medium
- Recurrence: 2 repos
- Affected:
  - `matchbook`
  - `pleroma`
- Batch fix direction:
  - move dependency caches and build/dist outputs to temp, cache, or explicit external build roots
  - clean existing ignored output directories before release

### 18. `theme-catalog-hardcoded`
- Severity: medium
- Recurrence: 6 app surfaces
- Affected:
  - `boycott`
  - `bellheim`
  - `mecha`
  - `serenity`
  - `simplerchat`
  - `wizardry-desktop`
- Batch fix direction:
  - remove app-local theme catalogs and derive from the authoritative shared theme set

### 19. `user-facing-config-not-yaml-md`
- Severity: medium
- Recurrence: 8 repos
- Affected:
  - `boycott`
  - `applegate`
  - `bellheim`
  - `counterspell`
  - `fauxzilla`
  - `matchbook`
  - `pleroma`
  - `pieplate`
- Batch fix direction:
  - convert user-facing durable config toward YAML-plus-Markdown or explicitly justify non-YAML text

## Medium-Severity Single-Repo Categories

### 20. `human-contract-format-not-yaml-md`
- Affected:
  - `theurgy`

### 21. `generated-native-theme-catalog-hardcoded`
- Affected:
  - `binder`
- Fix direction:
  - make every generated native platform target consume the same discovered shared Wizardry theme catalog instead of embedding static platform-specific theme option lists

### 22. `tests-not-under-dot-tests`
- Affected:
  - `dictator`

### 23. `config-example-stale`
- Affected:
  - `fauxzilla`

### 24. `frontend-machine-state-scraping`
- Affected:
  - `chatroom`

### 25. `inline-guided-fallback-missing`
- Affected:
  - `chatroom`

### 26. `audit-surface-stale`
- Affected:
  - `wizardry`

### 27. `gnu-tool-dependency-undocumented`
- Affected:
  - `wizardry`

### 28. `theme-picker-keyboard-broken`
- Affected:
  - `wizardry-desktop`

### 29. `frontend-derived-backend-path`
- Severity: medium
- Recurrence: 12 app surfaces
- Affected:
  - `bellheim`
  - `boycott`
  - `chatroom`
  - `counterspell`
  - `eye`
  - `forge`
  - `matchbook`
  - `mecha`
  - `pieplate`
  - `pleroma`
  - `simplerchat`
  - `wizardry-desktop`
- Fix direction:
  - move backend path resolution into the host or backend contract and expose explicit actions only

### 30. `generated-staging-not-disposable`
- Affected:
  - `organizer`
- Fix direction:
  - keep generated native staging trees disposable and rerender-safe even after ordinary local build artifacts appear

### 31. `cargo-runtime-layer-present`
- Severity: high
- Recurrence: 1 repo
- Affected:
  - `pleroma`
- Batch fix direction:
  - remove Cargo from ordinary shipped runtime paths or move the helper into an explicitly approved host or Theurgy boundary

### 32. `bridge-shell-fragment-execution`
- Severity: high
- Recurrence: 3 app surfaces
- Affected:
  - `chatroom`
  - `serenity`
  - `wizardry-desktop`
- Batch fix direction:
  - move execution into explicit backend actions and remove frontend-owned shell fragments or `sh -c`-style bridge payloads

## Low-Severity Recurring Categories

### 33. `theme-picker-not-alphabetized`
- Severity: low
- Recurrence: 4 app surfaces
- Affected:
  - `boycott`
  - `mecha`
  - `simplerchat`
  - `wizardry-desktop`
- Batch fix direction:
  - sort theme names at the authoritative source and stop keeping unsorted fallbacks

## Not Yet Triggered In Current Audits
- `plain-text-durable-state-violated`
- `theme-application-incomplete`
- These remain live rubric categories but do not yet have a populated affected-app set in the ledger.

## Current Batch Order Recommendation
1. `python-exception-undocumented`
2. `repo-local-exception-ledger-incomplete`
3. `repo-ai-standards-missing`
4. `validation-suite-red`
5. `storage-default-home-missing`
6. `browser-owned-durable-state`
7. `language-exception-undocumented`
8. `storage-exception-undocumented`
9. `shared-xdg-app-namespace`
10. `tracked-repo-cruft-placeholder`
11. `ui-static-tests-missing`
12. `backend-contract-tests-missing`
13. `user-facing-config-not-yaml-md`
14. `theme-catalog-hardcoded`
15. `disposable-output-in-checkout`
16. `tests-not-under-dot-tests`
17. high-severity single-repo categories after the broad recurring classes are under control

## Notes For The Fix-It Phase
- Some categories overlap deliberately. For example:
  - `storage-default-home-missing`
  - `storage-exception-undocumented`
  - `shared-xdg-app-namespace`
  - `browser-owned-durable-state`
- Fixes should collapse redundant symptoms by solving the highest-order policy problem first.
- The repo-local AI-facing standards note template will likely unlock multiple category reductions at once.
