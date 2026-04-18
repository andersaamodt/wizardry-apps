# stock

`stock/` is a flat convenience shelf of copied reusable non-app-specific Wizardry app assets.

- It is not a runtime source of truth.
- Canonical asset sources remain under `apps/<slug>/assets`.
- This folder stays flat on purpose; no app-specific subfolders live here.
- App icons and platform icon packs are intentionally excluded.
- Current copied files are `settings-gear.svg`, `target-android.svg`, `target-hosted-web.svg`, `target-ios.svg`, `target-linux.svg`, and `terminal-icon.png`.
- Those files currently come from `apps/forge/assets/`.
- `wizardry-desktop` is not represented here because its repo-local assets are app-specific icon material.
- `chatroom` is not represented here because it currently has no repo-local asset directory.
