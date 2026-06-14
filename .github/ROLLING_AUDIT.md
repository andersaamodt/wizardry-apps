# Wizardry Apps Rolling Audit

Canonical rolling-audit method and standards:

- `/Users/andersaamodt/git/phronesis/audits/rolling-audit.md`
- `/Users/andersaamodt/git/phronesis/audits/compliance-framework.md`
- `/Users/andersaamodt/git/phronesis/standards/`
- `/Users/andersaamodt/git/phronesis/policies/policy-matrix-schema.yaml`

## Local Scope
- Built-in shipped app surfaces named by `.github/GUI_AUDIT.md`: `forge`, `wizardry-desktop`, and `chatroom`.
- Shared host/runtime/tooling surfaces when they directly justify or violate an app audit finding.
- External wizardry-family app repos when this thread is doing cross-app audit or fix-it work.

## Local Inputs
- `README.md`
- `.github/AI_DOCS.md`
- `.github/WIZARDRY_APPS_ETHOS.md`
- `.github/WIZARDRY_APPS_GUI_STANDARDS.md`
- `.github/GUI_AUDIT.md`
- `.github/GUI_LESSONS.md`
- `.github/adversarial-testing.md`
- `.github/RELEASE_POLISH.md`
- `/Users/andersaamodt/.wizardry/.github/`
- `/Users/andersaamodt/git/phronesis/`

## Local Outputs
- `.github/ROLLING_AUDIT_LEDGER.yaml`: local affected-app category evidence.
- `.github/ROLLING_AUDIT_VARIANCE_LEDGER.yaml`: local variance evidence.
- `.github/ROLLING_AUDIT_CATEGORY_REPORT.md`: local category-first remediation report.
- `.github/ROLLING_AUDIT_RESULTS.md`: local built-in app audit results.
- `.github/ROLLING_AUDIT_PASS2.md`: historical pass-2 back-application evidence.

## Local Rule
- Do not restate ecosystem-wide standards here.
- Add new reusable standards, policy ids, category schema, and audit method to `phronesis`.
- Keep this file focused on wizardry-apps scope, evidence surfaces, and local read order.
