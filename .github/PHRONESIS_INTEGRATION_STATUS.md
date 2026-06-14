# Phronesis Integration Status

## Status
- Pass-2 standards migration: complete.
- Fix-it phase: not started here.
- Canonical standards home: `/Users/andersaamodt/git/phronesis`

## Completed Migration
- Policy matrix schema moved to `phronesis/policies/policy-matrix-schema.yaml`.
- Audit method and compliance framework moved to `phronesis/audits/`.
- Approved standards moved to `phronesis/standards/`.
- Accepted decisions moved to `phronesis/decisions/README.md`.
- Repo-local AI-doc template moved to `phronesis/templates/repo-ai-docs.md`.
- Canonical comprehensive `.gitignore` moved to `phronesis/standards/repo-hygiene/wizardry-general.gitignore`.

## Local Files After Migration
- `.github/ROLLING_AUDIT_LEDGER.yaml`: local affected-app category evidence.
- `.github/ROLLING_AUDIT_VARIANCE_LEDGER.yaml`: local variance evidence from the rolling audit.
- `.github/ROLLING_AUDIT_CATEGORY_REPORT.md`: local category-first remediation report.
- `.github/ROLLING_AUDIT_PASS2.md`: local pass-2 back-application evidence.
- `.github/ROLLING_AUDIT_RESULTS.md`: local built-in app audit results.

## Pre-Fix-It Gate
- Use phronesis as the standards baseline.
- Keep app-specific evidence in implementation repos.
- Fix one approved policy class across all affected apps where practical.
