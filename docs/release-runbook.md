# Release Runbook

## 1. Preflight

- Ensure `runtime/config/apps.manifest.json` and `runtime/config/templates.manifest.json` are valid.
- Ensure CI green on main branch.
- Confirm Theurgy is installed or installable from the release environment.
- Confirm app publish secrets exist only in the protected release environment.

## 2. Tag Build

- Push annotated tag: `vX.Y.Z`.
- Wait for `release.yml` to complete build + validation jobs.
- Mobile build artifacts are produced per production app:
  - `dist/android/wizardry-<slug>-release.aab`
  - `dist/ios/wizardry-<slug>-ios.ipa`

## 3. Approval Gate

- Approve protected environment in GitHub Actions.
- Publishing steps start only after approval.

## 4. Publication

- GitHub release artifacts uploaded.
- macOS signing/notarization, TestFlight upload, Play upload, and store promotion run through Theurgy-owned release scripts.
- Hosted web deploy runs only when deploy secrets are configured.

Desktop publish blockers:
- Theurgy macOS publish verification must pass.
- Linux AppImage smoke checks must pass in desktop build workflow.

## 5. Promotion

- Use `promote-stores.yml` for production promotion.
- Promotion is separate from tag build and requires explicit run.
- Android promotion is automated from internal -> production per app allowlist.
- iOS promotion is delegated to Theurgy because App Store Connect review gates and special publish keys are platform-policing machinery.
- Promotion workflow inputs:
  - `ios_build` (optional build number)
  - `ios_version` (optional marketing version)
  - `ios_submit_for_review` (boolean)
  - `ios_release_after_approval` (boolean)
  - `android_version_codes` (optional comma-separated version codes)

## 6. Verification

- Verify Theurgy reports successful macOS app verification and launch readiness.
- Verify Theurgy reports TestFlight build visibility.
- Verify Theurgy reports Play internal artifact visibility.
- Verify hosted web smoke endpoint if deployed.
