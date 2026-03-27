# Wizardry Desktop 1.0 Checklist

- [x] Main left-right desktop layout is stable, compact, and split-pane based.
- [x] Left rail uses listbox semantics and inset selected-row highlights.
- [x] Settings and theme controls match Wizardry Apps rail conventions.
- [x] Cast page shows all spell categories plus memorized spells with readable scroll areas.
- [x] Menus page indexes full menu inventory from backend metadata, not hand-maintained partial lists.
- [x] Sourced-only menu operations expose guided run behavior plus open-in-terminal behavior.
- [x] Casting Watch is a Wizardry Desktop feature surface (not a wizardry main-menu entry).
- [x] Activity drawer has independent scrollable sections for cast events and app commands.
- [x] Centralized `wizardry-themes` integration is active, instant-apply, and persisted via backend prefs.
- [x] Command composer defaults closed on startup and only opens via explicit user action.
- [x] Command/arg composer uses token pills, block suggestions, and keyboard-friendly edit/remove flows.
- [x] Command/arg composer supports quoted arguments (space-preserving tokens) and contextual next-token suggestions.
- [x] All GUI-triggered execution paths remain backend action + argv based (no free-form shell composition).
- [x] Backend and UI contract tests cover startup, menu metadata/actions, and command-composer contracts.
- [x] Safari automation QA pass recorded for startup state, sizing, scroll behavior, and composer usability.
