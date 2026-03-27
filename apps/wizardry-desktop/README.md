# Wizardry Desktop

Wizardry Desktop is a built-in desktop control plane for wizardry spells and app actions.

## Surface Model

- Left rail is a full-height listbox for primary pages (`Home`, `Menus`, `Cast`, `Spellbook`, `Arcana`, `Computer`, `Mud`).
- Right pane renders page content and action output.
- Activity drawer (`Casting Watch`) is a right-side utility panel, not a primary nav page.
- Command Composer is a modal utility opened from the toolbar icon (`Compose command...`).

## Backend Contract

- UI calls `apps/wizardry-desktop/scripts/wizardry-desktop-backend.sh`.
- Commands stay argv-based (`window.wizardry.exec([...])`), not shell fragments.
- Desktop prefs persist through backend key-value storage under:
  - `${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/wizardry-desktop/config`
- Watch activity log persists under:
  - `${XDG_DATA_HOME:-$HOME/.local/share}/wizardry/wizardry-desktop/watch.log`

## Theme Contract

- Theme palette source is centralized under `web/.themes`.
- Backend `list-themes` and frontend `buildThemeStylesheetHref` resolve those shared theme files.
- Theme changes apply immediately and persist through backend prefs.

## QA Checklist

- Startup renders splash then main UI with Composer closed.
- Left rail listbox selection works by mouse and keyboard.
- Cast page shows spell categories and memorized spells with readable scroll regions.
- Menus page indexes all menu scripts from `spells/menu` with help/run-safe actions.
- Activity drawer shows both `Active Casting` and `App Commands` with independent scroll.
- Shift/Cmd/Ctrl click on runnable buttons opens Composer pre-filled (instead of executing immediately).
- Theme picker applies instantly and survives restart.
