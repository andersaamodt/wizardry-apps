# Wizardry Desktop

Wizardry Desktop is a built-in desktop app for browsing Wizardry through visual panels instead of the interactive terminal menu loop.

It focuses on:
- translating the `main-menu` structure into persistent pages
- exposing spellbook, arcana, system, and MUD workflows through GUI controls
- keeping a live right-side activity drawer that shows backend terminal output for every GUI action

## Backend

The GUI calls:

- `apps/wizardry-desktop/scripts/wizardry-desktop-backend.sh`

The backend:
- resolves Wizardry from `WIZARDRY_DIR` or `~/.wizardry`
- bootstraps spell and arcana directories onto `PATH`
- persists desktop prefs in `~/.config/wizardry-apps/wizardry-desktop-ui.conf`
- keeps all durable state file-backed

## Desktop Prefs

Preferences are stored in:

- `~/.config/wizardry-apps/wizardry-desktop-ui.conf`

Current keys:
- `theme`
- `active_page`
- `work_dir`
- `mud_room_path`

## Notes

- Theme assets are bundled from `web/.themes` via the shared Forge theme set copied into `apps/wizardry-desktop/themes/`.
- Generic spell runs execute from the saved `work_dir`.
- MUD room-sensitive actions execute from the saved `mud_room_path`.
