# Rolling Audit Compliance Framework

## Purpose
- Provide one reusable policy-and-evidence framework for Wizardry-family app audits.
- Make audit results aggregatable by violation category first, not only by app.
- Support later cross-app remediation where one problem class is fixed consistently everywhere.

## Core Model
- `policy`: a named Wizardry standard or expectation.
- `category`: a recurring violation class tied to one or more policies.
- `finding`: one app-specific instance of a category violation with evidence.
- `status`: `pass`, `fail`, `exception-approved`, `not-applicable`, or `unknown`.
- `scope`: the repo, app, or shared host/runtime surface being audited.

## Stable Category Rules
- Every recurring problem should get a short stable category id.
- Category ids should be implementation-neutral and reusable across repos.
- Prefer ids that describe the broken contract, not the accidental implementation.

## Suggested Category Shape
- `id`: stable slug such as `theme-catalog-hardcoded`
- `title`: short human label
- `policy_axes`: one or more audit axes from `ROLLING_AUDIT.md`
- `default_severity`: `low`, `medium`, or `high`
- `why_it_matters`: one paragraph
- `fix_strategy`: the cross-app remediation approach to prefer later

## Recording Rules
- Per-app audit notes should still explain the local evidence and outcome.
- The shared ledger should record each finding under its category id.
- If multiple apps show the same bug class, append apps to the same category instead of inventing near-duplicate labels.
- If a repo has an approved exception, record it as `exception-approved` rather than pretending it passes the base rule.

## Reporting Rules
- Round summaries should sort categories by:
  1. highest severity present
  2. number of affected apps
  3. whether the category points to a shared framework/template defect
- Category summaries should list:
  - affected apps
  - canonical evidence files
  - shared fix direction
  - whether a template, host, generator, or standards doc can eliminate the issue class centrally

## Recommended Output Layers
- Per-app report:
  - local pass/fail
  - evidence
  - suggested local changes
- Shared ledger:
  - normalized category ids
  - affected apps
  - severity
  - fix strategy
- Final round report:
  - grouped by category
  - sorted by severity and recurrence
  - explicit cross-app remediation order

## Enforcement Approach
- Favor standards that can be enforced by:
  - templates
  - shared host/runtime code
  - backend contracts
  - test harnesses
  - generated policy matrices
- If a rule can only be checked by prose review, treat that as a temporary state and look for a future contract or harness that can enforce it earlier.

## Policy Matrix Direction
- Over time, maintain a machine-readable matrix of:
  - apps
  - policy categories
  - current status
  - approved exceptions
  - evidence links
- Use that matrix to plan re-audits, track regressions, and identify which standards should move into templates or shared infrastructure.

## Initial Category Seeds
- `storage-default-home-missing`
- `storage-exception-undocumented`
- `plain-text-durable-state-violated`
- `tests-not-under-dot-tests`
- `python-exception-undocumented`
- `theme-catalog-hardcoded`
- `theme-picker-keyboard-broken`
- `theme-picker-not-alphabetized`
- `theme-application-incomplete`
- `user-facing-config-not-yaml-md`
- `human-contract-format-not-yaml-md`
- `language-exception-undocumented`
- `generated-state-in-checkout`
- `settings-shell-split`
- `bridge-shell-fragment-execution`
- `frontend-machine-state-scraping`
- `inline-guided-fallback-missing`
- `read-path-mutates-state`
- `ui-static-tests-missing`
- `repo-ai-standards-missing`
- `validation-suite-red`

## Next Step
- Use `.github/ROLLING_AUDIT_LEDGER.yaml` as the normalized accumulation surface for future app audits.
