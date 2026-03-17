# Wizardry Apps GUI Taxonomy

## Scope
- This file inventories GUI control families currently used in checked-in wizardry apps.
- Read this before creating or materially editing a GUI in this repo.
- Update this file in the same change when you add a new control family, materially revise one, or promote a better in-repo reference.
- Policy and behavior rules still live in `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_GUI_STANDARDS.md`; this file maps those rules to concrete control families and current best references.

## Source Coverage
- Reviewed surfaces: `/Users/andersaamodt/git/wizardry-apps/apps/forge/index.html`, `/Users/andersaamodt/git/wizardry-apps/apps/chatroom/index.html`, `/Users/andersaamodt/git/wizardry-apps/apps/chatroom/settings.html`, `/Users/andersaamodt/git/wizardry-apps/apps/menu-app/index.html`, and `/Users/andersaamodt/git/wizardry-apps/apps/wizardry-desktop/index.html` plus `/Users/andersaamodt/git/wizardry-apps/apps/wizardry-desktop/app.js`.
- `/Users/andersaamodt/git/wizardry-apps/apps/forge/` is the control-plane baseline and contains the best current versions of most controls.
- `/Users/andersaamodt/git/wizardry-apps/apps/wizardry-desktop/` is the best current reference for menu-derived panel navigation, a right-side activity drawer, and a compact settings modal.
- `/Users/andersaamodt/git/wizardry-apps/apps/chatroom/` and `/Users/andersaamodt/git/wizardry-apps/apps/menu-app/` are useful compatibility references, not visual or interaction baselines.

## Navigation And Layout Controls
- Top nav tabs: chatroom uses simple tab-like anchors to swap Chat and Settings views; if touched, move toward real button semantics and Forge-level keyboard/state handling.
- Selectable list rows: Forge catalog rows are the best reference for dense primary navigation; they are keyboard-selectable, preserve selection across refreshes, and ignore re-click on the active row.
- Listbox-style rail navigation: wizardry-desktop is the current reference for menu-family navigation that should read like a persistent command palette rather than a mutable catalog.
- Mini-tabs: Forge app-group tabs are the best reference for lightweight secondary grouping; they support create, rename, delete-empty, drag-to-assign, and persistent system `All`/`Other` views.
- Slide panel toggle: Forge settings panel is the best reference for contextual utilities; open it from a compact icon button and close it with the trigger, `Escape`, or outside click.
- Activity drawer toggle: wizardry-desktop is the best current reference for a right-side log drawer opened from a single unobtrusive toolbar button.
- Split-pane divider: Forge rail divider is the current reference for resizable left-right layouts; persist width and keep the host layout stable instead of collapsing to a single column.
- Disclosure sections: Forge `details/summary` pipeline sections are the best reference for multi-step workflows; keep sections local to the page and open by default when they hold core tasks.
- Nested disclosure: Forge inactive-targets disclosure is the current reference for hiding lower-priority detail inside an already visible workflow.
- Modal dialog: wizardry-desktop settings modal is the current reference for a compact contained dialog with explicit close control; do not use this as a substitute for routine side-panel settings when a drawer would suffice.

## Text Entry And Selection Controls
- Search field: Forge filter input is the current reference for short live-filter fields; keep it compact, immediate, and near the list it filters.
- Bounded text input with explicit action: Forge root path rows are the current reference for path settings that should not autosave every keystroke.
- Inline rename input: Forge project rename and mini-tab rename are the current reference for short inline edits; focus immediately, commit on blur/Enter, and cancel on `Escape`.
- Primary short-text input: Forge `Create App` title field is the current reference for one-field creation flows; pair it with live derived feedback like the path preview.
- Multi-field inline form: wizardry-desktop spellbook, services, and MUD rows are the current reference for short operational forms that mix several compact fields and one immediate action.
- File input: Forge icon picker is the current reference; hide the raw file input behind a labeled dropzone and keep keyboard access through the label.
- Radio group, simple stack: chatroom mode selection is the current reference for a simple two-choice settings row.
- Radio group, card picker: Forge project type cards are the best reference when the choice is important enough to deserve icon, title, and description.
- Checkbox toggle, simple setting: Forge organize menu checkboxes are the current reference for compact binary preferences inside menus.
- Checkbox toggle, operational row: Forge publish-target rows are the best reference when a checkbox enables a capability and adjacent status/actions depend on it.
- Checkbox toggle, confirmation gate: wizardry-desktop power-confirm row is the current reference for a boolean that must gate a destructive action.
- Checkbox toggle, inline option: wizardry-desktop portal `Use Tor` checkbox is the current reference for a compact inline boolean inside a larger form row.
- Select dropdown: Forge starter selects are the current reference for bounded enumerated choices; keep them content-sized instead of stretching full width.
- Select dropdown, entity picker: wizardry-desktop player and spellbook category selects are the current reference for choosing an existing runtime entity before acting.

## Action Buttons
- Primary workflow button: Forge `Build` and `Create Project` buttons are the best current references for polite primary actions.
- Secondary outlined action button: Forge `Save`, `Refresh Tool Status`, install, test, and stage buttons are the current reference for routine non-destructive actions.
- Icon-only unobtrusive button: Forge filter, settings, copy-log, terminal, and overflow buttons are the best current references for minor actions.
- Split button: Forge `Run` plus adjacent run-options toggle is the best current reference for a primary default action with secondary variants.
- Row-level quick action: Forge row play buttons are the current reference for the highest-value per-item action in dense catalogs.
- Row-level micro-actions: Forge target-row open/run/install/mobile buttons are the current reference for compact secondary actions attached to one enabled capability.
- Path chip button: Forge selected-path control is the best current reference for path utilities; use basename labeling, click-to-copy, double-click-to-open, ellipsis handling, and an adjacent terminal button when useful.
- Section utility buttons: Forge log copy/clear buttons are the current reference for small actions in a section header.
- Button grid actions: wizardry-desktop is the current reference for pages that expose many direct backend verbs in one grouped card.
- Simple CTA button: chatroom’s server error CTA is an acceptable simple fallback when a screen only needs one obvious next step.
- Legacy utility button cluster: menu-app and chatroom use straightforward button grids and copy/start/stop buttons; keep them only for simple surfaces, not dense control planes.

## Menus And Popovers
- Floating menu: Forge organize, theme, run, and row-overflow menus are the current reference for compact contextual command sets.
- Theme picker menu: Forge is the best reference; it keeps the active item visible, applies changes immediately, supports `ArrowUp`/`ArrowDown`, and closes cleanly back to the trigger.
- Overflow row menu: Forge catalog row menus are the best reference for low-frequency per-item actions like Open, Rename, Remove, Download, and Open Terminal.

## List, Row, And Collection Controls
- Dense management list: Forge catalog rows are the best current reference for wizardry admin/control-plane lists; use row surfaces, small badges, and compact row actions instead of card grids.
- Target capability list: Forge publish-target rows are the best current reference for a capability list that combines enablement, status, and row-local actions.
- Empty list state: Forge empty-catalog copy is the current reference for filter-aware empty states.

## Drag, Drop, Media, And Asset Controls
- App icon dropzone: Forge is the best current reference; combine a visible drop target, preview, clear button, hidden file input, and drag-over cue.
- Workspace import drop zone: Forge catalog list is the current reference for folder import; only show the drop cue for valid payloads and clear the cue on leave, drop, drag end, blur, and visibility loss.
- Thumbnail slot: Forge catalog thumbs are the current reference for optional app/project artwork; keep the thumb node stable and theme-backed to avoid white-flash artifacts.

## Status, Feedback, And Read-Only Surfaces
- Persistent status pill: Forge bridge and activity pills are the best current reference for always-visible runtime state.
- Badge and metadata pill: Forge type badge, suite badge, scope pill, and context dot are the current reference for compact classification metadata.
- Simple pill metadata: wizardry-desktop spell count, status, and memorized pills are the current reference for terse row metadata in menu-derived pages.
- Toast: Forge is the current reference for short-lived confirmations and lightweight failures; keep the message factual and reserve durable panels/logs for actionable detail.
- Command log: Forge is the best current reference for durable action output; keep it bounded, selectable, copyable, and separate from transient toasts.
- Activity drawer log: wizardry-desktop is the current reference when logs should stay visible beside the main workflow instead of inside the main document flow.
- Simple output pane: menu-app’s `<pre>` output is the minimal reference for a tiny single-surface tool.
- Read-only value block: chatroom settings code/value blocks are the current reference for copy-centric URLs, addresses, and status text.
- Empty/error panel: chatroom’s server-not-running panel is the current reference for a simple blocked-state surface with one recovery action.

## Embedded And Host-Coupled Surfaces
- Embedded iframe view: chatroom uses iframes for the chat surface and settings surface; treat this as a compatibility pattern for wrapping an existing site, not the default control-plane pattern.
- Host resize control: Forge’s rail divider is the current reference for a host-visible interactive separator.
- Boot splash: wizardry-desktop is the current reference for a checked-in splash surface that keeps the shell hidden until the first ready frame.
- Splash and startup handoff: follow `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_GUI_STANDARDS.md`; no checked-in app currently provides a clearer reference than the standards themselves.

## Best Current References By Family
- Dense control-plane list rows: Forge catalog rows.
- Menu-derived left rail navigation: wizardry-desktop nav rows.
- Right-side activity drawer: wizardry-desktop activity drawer.
- Minor icon buttons: Forge icon actions and footer/settings controls.
- Primary toolbar actions: Forge `Build`, `Run`, `Stage`.
- Split actions: Forge `Run` + options toggle.
- Path utilities: Forge selected-path chip + terminal button.
- Disclosure-driven workflows: Forge pipeline sections.
- File import/edit controls: Forge icon dropzone.
- Capability toggles with row actions: Forge target rows.
- Theme selection: Forge theme picker.
- Status plus output feedback: Forge bridge/activity pills + toast + log.
- Compact settings modal: wizardry-desktop settings modal.
- Simple wrapped web surface: chatroom tabs + iframe.
- Minimal starter app surface: menu-app button grid + output pane.

## Micro-Patterns To Reuse
- Keep most controls fit to content or bounded width; do not default buttons, selects, or short inputs to `width: 100%`.
- Use unobtrusive icon buttons for minor actions and outlined polite buttons for primary work.
- Put the highest-value per-item action directly on dense rows and move lower-frequency actions into an overflow menu.
- Prefer section-local disclosure over extra routes or modal detours for multi-step workflows.
- Separate persistent runtime state from transient completion feedback; pills/status bars are not toasts.
- Make copy-centric controls explicit with tooltip/aria labeling and stable click semantics.
- Preserve keyboard paths: `Enter`/`Space` for row selection, `Escape` for close/cancel, arrows for active pickers where appropriate.
- Keep drag/drop cues narrow and truthful; never advertise a drop action for invalid payloads.

## Maintenance Rules For LLMs
- Read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_GUI_STANDARDS.md` and this file before creating or materially editing a GUI.
- Reuse the closest matching control family from this taxonomy before inventing a new one.
- If a new GUI introduces a control family not listed here, add it here with its best reference in the same change.
- If a touched control becomes the new best in-repo version of its family, update that recommendation here in the same change.
- Do not let this file drift behind the checked-in apps; taxonomy updates are part of GUI maintenance, not optional follow-up work.
