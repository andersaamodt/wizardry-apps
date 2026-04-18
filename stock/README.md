# stock

`stock/` is a convenience shelf of copied reusable Wizardry app assets.

- It is not a runtime source of truth.
- Canonical asset sources remain under `apps/<slug>/assets`.
- Each app subfolder mirrors that app's `assets/` tree after the `assets/` segment.
- `forge/` contains 67 copied assets, including UI glyphs, target icons, and platform icon packs.
- `wizardry-desktop/` contains 62 copied assets, including app icons, splash/source masters, and platform icon packs.
- `chatroom` is not represented here because it currently has no repo-local asset directory.
- `icons/meta/icon-settings.conf` is intentionally excluded because it stores machine-specific absolute paths, not reusable art.
- `Contents.json` is kept inside copied iOS icon sets because it belongs with those icon packs.
