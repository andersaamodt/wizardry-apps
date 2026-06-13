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
- Recurrence: 4 repos
- Affected:
  - `binder`
  - `counterspell`
  - `dictator`
  - `fauxzilla`
- Why it ranks first:
  - This is the broadest high-severity recurring language-discipline problem found so far.
  - It cuts across native ports, shell-first apps, and extension-plus-hub architecture.
- Batch fix direction:
  - decide repo-by-repo whether Python is being removed or explicitly retained
  - where retained, add a repo-local exception ledger in `.github/`
  - where not retained, plan replacement in shell, Rust, or other explicitly approved boundaries

### 2. `repo-ai-standards-missing`
- Severity: medium
- Recurrence: 5 repos
- Affected:
  - `binder`
  - `dictator`
  - `eye`
  - `fauxzilla`
  - `mecha`
- Why it ranks near the top:
  - This is currently the broadest recurring documentation/governance gap.
  - It directly slows every future audit and makes exception handling too implicit.
- Batch fix direction:
  - add a minimal repo-local `.github` standards note template
  - require each repo to list storage exceptions, language boundaries, and any accepted architecture-specific variance

### 3. `storage-default-home-missing`
- Severity: high
- Recurrence: 2 repos
- Affected:
  - `dictator`
  - `mecha`
- Why it ranks high:
  - This is a direct miss against the default Wizardry durable-state posture.
- Batch fix direction:
  - migrate primary durable state to `~/<appname>` where appropriate
  - otherwise promote a narrow documented exception instead of treating the current layout as ordinary

### 4. `ui-static-tests-missing`
- Severity: high
- Recurrence: 2 repos
- Affected:
  - `chatroom`
  - `eye`
- Why it ranks high:
  - These are shipped GUI surfaces without matching UI/static contract protection.
- Batch fix direction:
  - add lightweight DOM/static/bridge tests first
  - only then rely on backend tests as sufficient for release confidence

## High-Severity Single-Repo Categories

### 5. `generated-state-in-checkout`
- Severity: high
- Affected:
  - `theurgy`
- Fix direction:
  - generated defaults must stop normalizing runtime state into source trees

### 6. `standards-guidance-contradictory`
- Severity: high
- Affected:
  - `wizardry`
- Fix direction:
  - choose one canonical shell pattern and delete the conflicting one from AI-facing docs

### 7. `browser-owned-durable-state`
- Severity: high
- Affected:
  - `fauxzilla`
- Fix direction:
  - narrow extension storage to cache/bootstrap use
  - mirror canonical durable state into an app-owned plain-text contract

### 8. `settings-shell-split`
- Severity: high
- Affected:
  - `chatroom`
- Fix direction:
  - move settings into the main shell

### 9. `bridge-shell-fragment-execution`
- Severity: high
- Affected:
  - `chatroom`
- Fix direction:
  - replace `sh -c` bridge fallbacks with explicit backend actions

### 10. `read-path-mutates-state`
- Severity: high
- Affected:
  - `chatroom`
- Fix direction:
  - separate read/hydration from persistence

### 11. `validation-suite-red`
- Severity: high
- Affected:
  - `theurgy`
- Fix direction:
  - restore the canonical suite to green before treating the contract as stable

## Medium-Severity Recurring Categories

### 12. `storage-exception-undocumented`
- Severity: medium
- Recurrence: 3 repos
- Affected:
  - `binder`
  - `dictator`
  - `mecha`
- Batch fix direction:
  - document real storage exceptions where auditors look first

### 13. `user-facing-config-not-yaml-md`
- Severity: medium
- Recurrence: 3 repos
- Affected:
  - `bellheim`
  - `counterspell`
  - `fauxzilla`
- Batch fix direction:
  - convert user-facing durable config toward YAML-plus-Markdown or explicitly justify non-YAML text

### 14. `language-exception-undocumented`
- Severity: medium
- Recurrence: 3 repos
- Affected:
  - `bellheim`
  - `counterspell`
  - `fauxzilla`
- Batch fix direction:
  - enumerate all non-shell boundaries in local standards notes

### 15. `theme-catalog-hardcoded`
- Severity: medium
- Recurrence: 3 app surfaces
- Affected:
  - `bellheim`
  - `mecha`
  - `wizardry-desktop`
- Batch fix direction:
  - remove app-local theme catalogs and derive from the authoritative shared theme set

### 16. `shared-xdg-app-namespace`
- Severity: medium
- Recurrence: 2 repos
- Affected:
  - `counterspell`
  - `mecha`
- Batch fix direction:
  - if XDG roots remain, move them to app-owned names rather than `wizardry-apps/...` or `wizardry/...`

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

## Low-Severity Recurring Categories

### 25. `theme-picker-not-alphabetized`
- Severity: low
- Recurrence: 2 app surfaces
- Affected:
  - `mecha`
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
3. `storage-default-home-missing`
4. `storage-exception-undocumented`
5. `shared-xdg-app-namespace`
6. `theme-catalog-hardcoded`
7. `ui-static-tests-missing`
8. `user-facing-config-not-yaml-md`
9. `language-exception-undocumented`
10. high-severity single-repo categories after the broad recurring classes are under control

## Notes For The Fix-It Phase
- Some categories overlap deliberately. For example:
  - `storage-default-home-missing`
  - `storage-exception-undocumented`
  - `shared-xdg-app-namespace`
- Fixes should collapse redundant symptoms by solving the highest-order policy problem first.
- The repo-local AI-facing standards note template will likely unlock multiple category reductions at once.
