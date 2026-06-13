# Rolling Audit Category Report

## Status
- Snapshot date: 2026-06-13
- Scope: current audited Wizardry-family repos and built-in `wizardry-apps` surfaces already covered by the rolling audit
- Purpose: keep a category-first remediation map so the fix-it phase can proceed problem-by-problem instead of app-by-app
- Source of truth:
  - `.github/ROLLING_AUDIT_LEDGER.yaml`
  - repo-local `ROLLING_AUDIT.md` reports
  - `.github/ROLLING_AUDIT_RESULTS.md` for built-in `wizardry-apps` app surfaces
- This is an interim rolling snapshot, not the final complete-family report. Additional repos still need first-pass audit coverage.

## Highest-Priority Categories

### 1. `python-exception-undocumented`
- Severity: high
- Recurrence: 8 repos
- Affected:
  - `binder`
  - `book-club`
  - `counterspell`
  - `dictator`
  - `fauxzilla`
  - `organizer`
  - `pieplate`
  - `simplerchat`
- Why it ranks first:
  - This is the broadest high-severity recurring language-discipline problem found so far.
  - It cuts across native ports, shell-first apps, extension-plus-hub architecture, and mixed hosted/desktop repos.
- Batch fix direction:
  - decide repo-by-repo whether Python is being removed or explicitly retained
  - where retained, add a repo-local exception ledger in `.github/`
  - where not retained, plan replacement in shell, Rust, or other explicitly approved boundaries

### 2. `repo-ai-standards-missing`
- Severity: medium
- Recurrence: 11 repos
- Affected:
  - `applegate`
  - `binder`
  - `dictator`
  - `eye`
  - `fauxzilla`
  - `hegelizer`
  - `matchbook`
  - `mecha`
  - `organizer`
  - `pieplate`
  - `simplerchat`
- Why it ranks near the top:
  - This is currently the broadest recurring documentation/governance gap.
  - It directly slows every future audit and makes exception handling too implicit.
- Batch fix direction:
  - add a minimal repo-local `.github` standards note template
  - require each repo to list storage exceptions, language boundaries, and any accepted architecture-specific variance

### 3. `validation-suite-red`
- Severity: high
- Recurrence: 3 repos
- Affected:
  - `hegelizer`
  - `pieplate`
  - `theurgy`
- Why it ranks high:
  - A red claimed validation suite blocks confidence in the contract layer directly.
- Batch fix direction:
  - restore each repo’s canonical validation suite to green before treating the contract surface as stable

### 4. `storage-default-home-missing`
- Severity: high
- Recurrence: 3 repos
- Affected:
  - `dictator`
  - `mecha`
  - `pieplate`
- Why it ranks high:
  - This is a direct miss against the default Wizardry durable-state posture.
- Batch fix direction:
  - migrate primary durable state to `~/<appname>` where appropriate
  - otherwise promote a narrow documented exception instead of treating the current layout as ordinary

### 5. `browser-owned-durable-state`
- Severity: high
- Recurrence: 2 repos
- Affected:
  - `fauxzilla`
  - `pieplate`
- Why it ranks high:
  - This combines high-severity storage drift with user-secret and identity-state risk.
- Batch fix direction:
  - narrow browser-owned storage to cache/bootstrap use and move canonical durable state and secrets into app-owned explicit contracts

### 6. `ui-static-tests-missing`
- Severity: high
- Recurrence: 3 repos
- Affected:
  - `applegate`
  - `chatroom`
  - `eye`
- Why it ranks high:
  - These are shipped GUI surfaces without matching UI/static contract protection.
- Batch fix direction:
  - add lightweight DOM/static/bridge tests first
  - only then rely on backend tests as sufficient for release confidence

## High-Severity Single-Repo Categories

### 7. `generated-state-in-checkout`
- Affected:
  - `theurgy`
- Fix direction:
  - generated defaults must stop normalizing runtime state into source trees

### 8. `standards-guidance-contradictory`
- Affected:
  - `wizardry`
- Fix direction:
  - choose one canonical shell pattern and delete the conflicting one from AI-facing docs

### 9. `settings-shell-split`
- Affected:
  - `chatroom`
- Fix direction:
  - move settings into the main shell

### 10. `bridge-shell-fragment-execution`
- Affected:
  - `chatroom`
- Fix direction:
  - replace `sh -c` bridge fallbacks with explicit backend actions

### 11. `read-path-mutates-state`
- Affected:
  - `chatroom`
- Fix direction:
  - separate read/hydration from persistence

## Medium-Severity Recurring Categories

### 12. `language-exception-undocumented`
- Severity: medium
- Recurrence: 8 repos
- Affected:
  - `bellheim`
  - `book-club`
  - `counterspell`
  - `fauxzilla`
  - `matchbook`
  - `organizer`
  - `pieplate`
  - `simplerchat`
- Batch fix direction:
  - enumerate all non-shell boundaries in local standards notes

### 13. `storage-exception-undocumented`
- Severity: medium
- Recurrence: 5 repos
- Affected:
  - `binder`
  - `dictator`
  - `hegelizer`
  - `mecha`
  - `pieplate`
- Batch fix direction:
  - document real storage exceptions where auditors look first

### 14. `shared-xdg-app-namespace`
- Severity: medium
- Recurrence: 5 repos
- Affected:
  - `book-club`
  - `counterspell`
  - `hegelizer`
  - `mecha`
  - `pieplate`
- Batch fix direction:
  - if XDG roots remain, move them to app-owned names rather than `wizardry-apps/...` or `wizardry/...`

### 15. `theme-catalog-hardcoded`
- Severity: medium
- Recurrence: 4 app surfaces
- Affected:
  - `bellheim`
  - `mecha`
  - `simplerchat`
  - `wizardry-desktop`
- Batch fix direction:
  - remove app-local theme catalogs and derive from the authoritative shared theme set

### 16. `user-facing-config-not-yaml-md`
- Severity: medium
- Recurrence: 6 repos
- Affected:
  - `applegate`
  - `bellheim`
  - `counterspell`
  - `fauxzilla`
  - `matchbook`
  - `pieplate`
- Batch fix direction:
  - convert user-facing durable config toward YAML-plus-Markdown or explicitly justify non-YAML text

## Medium-Severity Single-Repo Categories

### 17. `human-contract-format-not-yaml-md`
- Affected:
  - `theurgy`

### 18. `tests-not-under-dot-tests`
- Affected:
  - `dictator`

### 19. `config-example-stale`
- Affected:
  - `fauxzilla`

### 20. `frontend-machine-state-scraping`
- Affected:
  - `chatroom`

### 21. `inline-guided-fallback-missing`
- Affected:
  - `chatroom`

### 22. `audit-surface-stale`
- Affected:
  - `wizardry`

### 23. `gnu-tool-dependency-undocumented`
- Affected:
  - `wizardry`

### 24. `theme-picker-keyboard-broken`
- Affected:
  - `wizardry-desktop`

### 25. `generated-staging-not-disposable`
- Affected:
  - `organizer`
- Fix direction:
  - keep generated native staging trees disposable and rerender-safe even after ordinary local build artifacts appear

## Low-Severity Recurring Categories

### 26. `theme-picker-not-alphabetized`
- Severity: low
- Recurrence: 3 app surfaces
- Affected:
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
2. `repo-ai-standards-missing`
3. `validation-suite-red`
4. `storage-default-home-missing`
5. `browser-owned-durable-state`
6. `language-exception-undocumented`
7. `storage-exception-undocumented`
8. `shared-xdg-app-namespace`
9. `theme-catalog-hardcoded`
10. `ui-static-tests-missing`
11. `user-facing-config-not-yaml-md`
12. high-severity single-repo categories after the broad recurring classes are under control

## Notes For The Fix-It Phase
- Some categories overlap deliberately. For example:
  - `storage-default-home-missing`
  - `storage-exception-undocumented`
  - `shared-xdg-app-namespace`
  - `browser-owned-durable-state`
- Fixes should collapse redundant symptoms by solving the highest-order policy problem first.
- The repo-local AI-facing standards note template will likely unlock multiple category reductions at once.
