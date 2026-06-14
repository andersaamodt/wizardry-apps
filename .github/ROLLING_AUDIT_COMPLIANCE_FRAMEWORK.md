# Rolling Audit Compliance Framework

Canonical compliance framework:

- `/Users/andersaamodt/git/phronesis/audits/compliance-framework.md`
- `/Users/andersaamodt/git/phronesis/audits/category-ledger-schema.yaml`
- `/Users/andersaamodt/git/phronesis/policies/policy-matrix-schema.yaml`

## Local Role
- This repo keeps app-specific evidence, affected-app lists, and wizardry-apps implementation notes.
- Do not add new ecosystem-wide policy here.
- Add reusable audit method, status values, category shape, or policy matrix changes to `phronesis` first.
- Keep `.github/ROLLING_AUDIT_LEDGER.yaml` as the local affected-app ledger for wizardry-apps audit evidence.
- Keep `.github/ROLLING_AUDIT_CATEGORY_REPORT.md` as the local severity-and-recurrence report for current audited apps.

## Local Evidence Surfaces
- `.github/ROLLING_AUDIT_LEDGER.yaml`
- `.github/ROLLING_AUDIT_VARIANCE_LEDGER.yaml`
- `.github/ROLLING_AUDIT_CATEGORY_REPORT.md`
- `.github/ROLLING_AUDIT_PASS2.md`
- `.github/ROLLING_AUDIT_RESULTS.md`
