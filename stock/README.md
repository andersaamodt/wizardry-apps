# stock

`stock/` is a flat convenience shelf of copied and extracted reusable non-app-specific Wizardry app icons and SVGs.

- It is not a runtime source of truth.
- Canonical asset sources remain under `apps/<slug>/assets`.
- This folder stays flat on purpose; no app-specific subfolders live here.
- App icons and platform icon packs are intentionally excluded.
- The folder includes both copied asset files and SVGs extracted from inline app markup or CSS data URLs.
- Current files:
- `settings-gear.svg` from `apps/forge/assets/settings-gear.svg` and matching Wizardry Desktop inline settings gear
- `target-android.svg` from `apps/forge/assets/target-android.svg`
- `target-hosted-web.svg` from `apps/forge/assets/target-hosted-web.svg`
- `target-ios.svg` from `apps/forge/assets/target-ios.svg`
- `target-linux.svg` from `apps/forge/assets/target-linux.svg`
- `terminal-icon.png` from `apps/forge/assets/terminal-icon.png`
- `forge-organize.svg` extracted from the filter/organize icon in `apps/forge/index.html`
- `forge-copy-log.svg` extracted from the log copy button in `apps/forge/index.html`
- `forge-toast-copy.svg` extracted from the toast copy button in `apps/forge/index.html`
- `forge-tab-remove.svg` extracted from the minitab remove icon in `apps/forge/index.html`
- `wizardry-desktop-command-composer.svg` extracted from the composer button in `apps/wizardry-desktop/index.html`
- `wizardry-desktop-casting-watch.svg` extracted from the activity drawer button in `apps/wizardry-desktop/index.html`
- `web-demo-chat-members.svg` extracted from the members button in `web/demo/pages/chat.md`
- `web-demo-loading-spinner.svg` extracted from the SVG data URL in `web/demo/static/style.css`
- `wizardry-desktop` app icon files are excluded because they are app-brand icon material.
- `chatroom` is not represented here because it currently has no repo-local asset directory.
