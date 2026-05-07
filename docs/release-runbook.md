# Release Runbook

## 1. Preflight

- Ensure `runtime/config/apps.manifest.json` and `runtime/config/templates.manifest.json` are valid.
- Ensure CI green on main branch.
- Confirm signing secrets exist in GitHub environment.

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
- macOS signed + notarized artifacts attached.
- iOS uploaded to TestFlight.
- Android uploaded to Play internal track.
- Hosted web deploy runs only when deploy secrets are configured.

Desktop publish blockers:
- macOS notarization must pass (`sign_notarize_macos` job).
- Linux AppImage smoke checks must pass in desktop build workflow.

## 5. Promotion

- Use `promote-stores.yml` for production promotion.
- Promotion is separate from tag build and requires explicit run.
- Android promotion is automated from internal -> production per app allowlist.
- iOS promotion is automated via App Store Connect API per app allowlist:
  - attaches selected TestFlight build to App Store version
  - submits for review when version state is `PREPARE_FOR_SUBMISSION`
  - optional release trigger when state is `PENDING_DEVELOPER_RELEASE`
- Promotion workflow inputs:
  - `ios_build` (optional build number)
  - `ios_version` (optional marketing version)
  - `ios_submit_for_review` (boolean)
  - `ios_release_after_approval` (boolean)
  - `android_version_codes` (optional comma-separated version codes)

## 6. Verification

- Verify macOS notarization ticket and app launch.
- Verify TestFlight build visibility.
- Verify Play internal artifact visibility.
- Verify hosted web smoke endpoint if deployed.
