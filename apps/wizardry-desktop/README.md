# Wizardry Desktop

Wizardry Desktop is a built-in desktop control plane for wizardry spells and app actions.

## Surface Model

- Left rail is a full-height listbox for primary pages mirrored from wizardry `main-menu` (`Cast`, optional `Mud`, `Spellbook`, `Arcana`, `Computer`).
- Right pane renders page content and action output.
- Activity drawer (`Casting Watch`) is a right-side utility panel, not a primary nav page.
- Command Composer is a modal utility opened from the toolbar icon (`Compose command...`).
- Casting Watch is the right-side output drawer for casting/app activity and command output.

## Backend Contract

- UI calls `apps/wizardry-desktop/scripts/wizardry-desktop-backend.sh`.
- Commands stay argv-based (`window.wizardry.exec([...])`), not shell fragments.
- Menu inventory includes argument metadata (`none` / `optional` / `required`) used by both Menus page and Command Composer.
- Main menu inventory comes from backend `list-main-menu-entries`, so left-rail order follows wizardry main-menu semantics.
- Computer menu inventory comes from backend `list-system-menu-actions`, matching wizardry `system-menu` actions.
- Sourced-only menu rows expose `Open Terminal`, backed by `open-menu-terminal`.
- Desktop prefs persist through backend key-value storage under:
  - `${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/wizardry-desktop/config`
- Watch activity log persists under:
  - `${XDG_DATA_HOME:-$HOME/.local/share}/wizardry/wizardry-desktop/watch.log`
- Spellbook alias edits are written to wizardry files (`~/.spellbook/.synonyms`) via backend actions.

## Theme Contract

- Theme palette source is centralized under `web/.themes`.
- Backend `list-themes` and frontend `buildThemeStylesheetHref` resolve those shared theme files.
- Theme changes apply immediately and persist through backend prefs.

## QA Checklist

- Production completion checklist lives in `apps/wizardry-desktop/PRODUCTION_CHECKLIST.md`.
- Startup renders splash then main UI with Composer closed.
- Left rail listbox selection works by mouse and keyboard.
- Cast page shows spell categories and memorized spells with readable scroll regions.
- Computer page mirrors `system-menu` actions, including Terminal handoff for interactive menu actions.
- Command Composer argument assistant should suggest next tokens for any command shape, with menu-specific guidance and second-argument suggestions when required.
- Composer input supports quoted tokens for arguments that contain spaces.
- Activity drawer shows both `Active Casting` and `App Commands` with independent scroll.
- Shift/Cmd/Ctrl click on runnable buttons opens Composer pre-filled (instead of executing immediately).
- Theme picker applies instantly and survives restart.
