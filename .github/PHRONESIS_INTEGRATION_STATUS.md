# Phronesis Integration Status

## Purpose
- Prove what pass-2 work is already captured well enough to integrate.
- Separate migrated ecosystem policy from repo-local evidence that should stay in implementation repos.
- Prevent the fix-it phase from starting against an ambiguous standards baseline.

## Pass-2 Completion Requirements

### 1. `phronesis` preparation exists and is structurally real
- Status: pass
- Evidence:
  - repo seeded at `/Users/andersaamodt/git/phronesis`
  - pushed remote at `git@github.com:andersaamodt/phronesis.git`
  - canonical policy seed files now present:
    - `README.md`
    - `standards/repo-hygiene/README.md`
    - `standards/repo-hygiene/wizardry-general.gitignore`
    - `policies/policy-matrix-schema.yaml`
    - `templates/repo-ai-docs.md`
    - `decisions/README.md`
    - `decisions/0000-template.md`
    - `audits/README.md`
    - `exceptions/README.md`
    - `lessons/README.md`
    - `tools/README.md`

### 2. variance decisions and proposals are fully captured before fix-it
- Status: pass
- Evidence:
  - normalized variance items live in `.github/ROLLING_AUDIT_VARIANCE_LEDGER.yaml`
  - promotion-ready and user-decision items live in `.github/ROLLING_AUDIT_PASS2_DECISION_QUEUE.md`
  - promoted seed decision index exists in `/Users/andersaamodt/git/phronesis/decisions/README.md`
- Current rule:
  - no meaningful variance should remain only in narrative audit prose

### 3. late first-pass rubric additions were back-applied to earlier audited apps
- Status: pass
- Evidence:
  - `.github/ROLLING_AUDIT_PASS2.md` records back-application results for:
    - `frontend-derived-backend-path`
    - `cargo-runtime-layer-present`
    - `app-local-theme-system-documented`
    - `repo-local-ai-exception-ledger`
    - `backend-contract-tests-missing`
    - `ui-static-tests-missing`
    - `variance.reasoned`
    - `repo-cruft-and-build-artifact-discipline`

### 4. recurring problems are normalized into category-first remediation surfaces
- Status: pass
- Evidence:
  - `.github/ROLLING_AUDIT_LEDGER.yaml` holds recurring category IDs
  - `.github/ROLLING_AUDIT_CATEGORY_REPORT.md` sorts recurring problems by severity and recurrence
  - `.github/ROLLING_AUDIT_COMPLIANCE_FRAMEWORK.md` defines the category/policy/finding/status model

### 5. integration boundaries are explicit enough to avoid duplicate canonical docs
- Status: pass with pending migration work
- Evidence:
  - `.github/PHRONESIS_EXTRACTION_PLAN.md` defines what should migrate and what should remain local
  - the table below records current migration state rather than leaving it implicit

## Extraction Status

| Source artifact | Intended home | Current status | Notes |
| --- | --- | --- | --- |
| `.github/PHRONESIS_POLICY_MATRIX_SCHEMA.yaml` | `phronesis/policies/policy-matrix-schema.yaml` | copied | Local file should become a compatibility pointer or be removed after downstream references are updated. |
| `.github/ROLLING_AUDIT_COMPLIANCE_FRAMEWORK.md` | `phronesis/audits/` | pending migration | Already stable enough to promote; still local today. |
| `.github/ROLLING_AUDIT_PROPOSED_STANDARDS.md` | `phronesis/standards/` and `phronesis/decisions/` | pending review | Contains both likely-canonical rules and still-unapproved items. |
| `.github/ROLLING_AUDIT_PASS2_DECISION_QUEUE.md` | `phronesis/decisions/README.md` plus future ADRs | partially copied | Ready-to-promote and open-review sets are mirrored conceptually, but not yet as individual decision records. |
| `.github/ROLLING_AUDIT_VARIANCE_LEDGER.yaml` | `phronesis/policies/` or `phronesis/audits/` | local by design for now | Still a working accumulation surface during audit; later it may split into canonical variants plus repo-local evidence. |
| `.github/ROLLING_AUDIT_LEDGER.yaml` | split: canonical category schema in `phronesis`, evidence remains local | pending migration | Current file mixes reusable category IDs with affected-app evidence. |
| `.github/ROLLING_AUDIT.md` | split: generic method in `phronesis`, wizardry-apps scope stays local | pending migration | Method is extractable; built-in app scope and local evidence rules stay here. |
| `.github/WIZARDRY_APPS_GUI_STANDARDS.md` | split candidate | pending review | Only ecosystem-wide GUI contracts should move. Forge and host implementation detail stays local. |
| `.github/WIZARDRY_APPS_ETHOS.md` | split candidate | pending review | Only cross-repo principles should move. |
| `.github/adversarial-testing.md` | split candidate | pending review | Universal adversarial rules may migrate; bridge/host examples remain local. |

## Ready For Integration Now
- `variance.reasoned` as a founding phronesis principle.
- `storage.app-home-default`.
- `storage.plain-text`.
- `format.user-yaml-md`.
- `tests.dot-tests`.
- `docs.exception-ledger-shape`.
- `themes.shared-catalog-authority`.
- `themes.native-shared-catalog-parity`.
- `bridge.backend-resolution-owned`.
- `bridge.no-shell-fragments`.
- `runtime.no-cargo-on-demand`.
- `repo.no-disposable-cruft`.
- canonical policy matrix schema.
- canonical repo-local AI-doc template.
- canonical repo-hygiene seed and comprehensive `.gitignore`.

## Still Waiting For User Decision Before Canonical Promotion
- `language.exception-ledger`: whether retained Python defaults to removal or to documented reduction.
- `themes.app-local`: whether Forge-generated apps must default to shared wizardry themes unless explicitly opted out.
- `native.host-boundary`: whether packaged backend-path knowledge is always acceptable inside the generated host boundary.
- `repo.ignore-canonicality`: whether repos must import the canonical phronesis `.gitignore` verbatim or may keep documented specializations.

## What Should Stay Local Even After Integration
- app-by-app affected lists and evidence paths
- built-in `wizardry-apps` app audit results
- repo-specific commands, topology, and implementation maps
- repo-specific exception instances rather than exception schema

## Pre-Fix-It Gate
- Do not begin broad remediation until accepted standards are promoted into `phronesis` or explicitly confirmed to remain local.
- Do not treat duplicated local prose as canonical once the phronesis version exists.
- Prefer fixing one approved policy class across all apps at a time rather than resuming app-by-app remediation.
