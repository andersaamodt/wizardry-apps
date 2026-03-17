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
- Top nav tabs. Apps: Chatroom. Best: Chatroom by default because it is the only checked-in user of this pattern; if touched, move it toward real button semantics and Forge-level keyboard/state handling.
- Selectable list rows. Apps: Forge, Wizardry Desktop. Best: Forge catalog rows for dense primary navigation because they preserve selection across refreshes and ignore re-click on the active row.
- Listbox-style rail navigation. Apps: Wizardry Desktop. Best: Wizardry Desktop nav rows for menu-family navigation that should read like a persistent command palette rather than a mutable catalog.
- Mini-tabs. Apps: Forge. Best: Forge app-group tabs because they support create, rename, delete-empty, drag-to-assign, and persistent system `All`/`Other` views.
- Slide panel toggle. Apps: Forge. Best: Forge settings panel for contextual utilities; open it from a compact icon button and close it with the trigger, `Escape`, or outside click.
- Activity drawer toggle. Apps: Wizardry Desktop. Best: Wizardry Desktop activity drawer because it gives the log a stable right-side home without taking over the main document flow.
- Split-pane divider. Apps: Forge. Best: Forge rail divider for resizable left-right layouts; persist width and keep the host layout stable instead of collapsing to a single column.
- Disclosure sections. Apps: Forge. Best: Forge `details/summary` pipeline sections for multi-step workflows; keep sections local to the page and open by default when they hold core tasks.
- Nested disclosure. Apps: Forge. Best: Forge inactive-targets disclosure for hiding lower-priority detail inside an already visible workflow.
- Modal dialog. Apps: Wizardry Desktop. Best: Wizardry Desktop settings modal for a compact contained dialog with explicit close control; do not use this as a substitute for routine side-panel settings when a drawer would suffice.

## Text Entry And Selection Controls
- Search field. Apps: Forge. Best: Forge filter input for short live-filter fields; keep it compact, immediate, and near the list it filters.
- Bounded text input with explicit action. Apps: Forge, Wizardry Desktop. Best: Forge root path rows for path settings that should not autosave every keystroke.
- Inline rename input. Apps: Forge. Best: Forge project rename and mini-tab rename for short inline edits; focus immediately, commit on blur or `Enter`, and cancel on `Escape`.
- Primary short-text input. Apps: Forge, Wizardry Desktop, Chatroom. Best: Forge `Create App` title field because it pairs one short field with immediate derived feedback like the path preview.
- Multi-field inline form. Apps: Wizardry Desktop. Best: Wizardry Desktop spellbook, services, and MUD rows for short operational forms that mix several compact fields and one immediate action.
- File input. Apps: Forge. Best: Forge icon picker; hide the raw file input behind a labeled dropzone and keep keyboard access through the label.
- Radio group, simple stack. Apps: Chatroom. Best: Chatroom mode selection for a simple two-choice settings row.
- Radio group, card picker. Apps: Forge. Best: Forge project type cards when the choice is important enough to deserve icon, title, and description.
- Checkbox toggle, simple setting. Apps: Forge. Best: Forge organize menu checkboxes for compact binary preferences inside menus.
- Checkbox toggle, operational row. Apps: Forge. Best: Forge publish-target rows when a checkbox enables a capability and adjacent status/actions depend on it.
- Checkbox toggle, confirmation gate. Apps: Wizardry Desktop. Best: Wizardry Desktop power-confirm row for a boolean that must gate a destructive action.
- Checkbox toggle, inline option. Apps: Wizardry Desktop. Best: Wizardry Desktop portal `Use Tor` checkbox for a compact inline boolean inside a larger form row.
- Select dropdown. Apps: Forge, Wizardry Desktop. Best: Forge starter selects for bounded enumerated choices; keep them content-sized instead of stretching full width.
- Select dropdown, entity picker. Apps: Wizardry Desktop. Best: Wizardry Desktop player and spellbook category selects for choosing an existing runtime entity before acting.

## Action Buttons
- Primary workflow button. Apps: Forge, Wizardry Desktop. Best: Forge `Build` and `Create Project` buttons for polite primary actions with clear hierarchy.
- Secondary outlined action button. Apps: Forge, Wizardry Desktop, Chatroom, Menu App. Best: Forge `Save`, `Refresh Tool Status`, install, test, and stage buttons for routine non-destructive actions.
- Icon-only unobtrusive button. Apps: Forge, Wizardry Desktop. Best: Forge filter, settings, copy-log, terminal, and overflow buttons for minor actions.
- Split button. Apps: Forge. Best: Forge `Run` plus adjacent run-options toggle for a primary default action with secondary variants.
- Row-level quick action. Apps: Forge, Wizardry Desktop. Best: Forge row play buttons for the highest-value per-item action in dense catalogs.
- Row-level micro-actions. Apps: Forge, Wizardry Desktop. Best: Forge target-row open, run, install, and mobile buttons for compact secondary actions attached to one enabled capability.
- Path chip button. Apps: Forge. Best: Forge selected-path control; use basename labeling, click-to-copy, double-click-to-open, ellipsis handling, and an adjacent terminal button when useful.
- Section utility buttons. Apps: Forge, Wizardry Desktop, Chatroom. Best: Forge log copy and clear buttons for small actions in a section header.
- Button grid actions. Apps: Wizardry Desktop, Menu App. Best: Wizardry Desktop for pages that expose many direct backend verbs in one grouped card.
- Simple CTA button. Apps: Chatroom. Best: Chatroom server error CTA as a simple fallback when a screen only needs one obvious next step.
- Legacy utility button cluster. Apps: Menu App, Chatroom. Best: none; keep these only for simple surfaces, not dense control planes.

## Menus And Popovers
- Floating menu. Apps: Forge, Wizardry Desktop. Best: Forge organize, theme, run, and row-overflow menus for compact contextual command sets.
- Theme picker menu. Apps: Forge, Wizardry Desktop. Best: Forge because it keeps the active item visible, applies changes immediately, supports `ArrowUp` and `ArrowDown`, and closes cleanly back to the trigger.
- Overflow row menu. Apps: Forge. Best: Forge catalog row menus for low-frequency per-item actions like Open, Rename, Remove, Download, and Open Terminal.

## List, Row, And Collection Controls
- Dense management list. Apps: Forge, Wizardry Desktop. Best: Forge catalog rows for wizardry admin and control-plane lists; use row surfaces, small badges, and compact row actions instead of card grids.
- Target capability list. Apps: Forge. Best: Forge publish-target rows for a capability list that combines enablement, status, and row-local actions.
- Empty list state. Apps: Forge, Wizardry Desktop. Best: Forge empty-catalog copy for filter-aware empty states.

## Drag, Drop, Media, And Asset Controls
- App icon dropzone. Apps: Forge. Best: Forge; combine a visible drop target, preview, clear button, hidden file input, and drag-over cue.
- Workspace import drop zone. Apps: Forge. Best: Forge catalog list for folder import; only show the drop cue for valid payloads and clear the cue on leave, drop, drag end, blur, and visibility loss.
- Thumbnail slot. Apps: Forge. Best: Forge catalog thumbs for optional app and project artwork; keep the thumb node stable and theme-backed to avoid white-flash artifacts.

## Status, Feedback, And Read-Only Surfaces
- Persistent status pill. Apps: Forge, Wizardry Desktop. Best: Forge bridge and activity pills for always-visible runtime state.
- Badge and metadata pill. Apps: Forge, Wizardry Desktop. Best: Forge type badge, suite badge, scope pill, and context dot for compact classification metadata.
- Simple pill metadata. Apps: Wizardry Desktop. Best: Wizardry Desktop spell count, status, and memorized pills for terse row metadata in menu-derived pages.
- Toast. Apps: Forge, Wizardry Desktop. Best: Forge for short-lived confirmations and lightweight failures; keep the message factual and reserve durable panels or logs for actionable detail.
- Command log. Apps: Forge, Wizardry Desktop, Menu App. Best: Forge for durable action output; keep it bounded, selectable, copyable, and separate from transient toasts.
- Activity drawer log. Apps: Wizardry Desktop. Best: Wizardry Desktop when logs should stay visible beside the main workflow instead of inside the main document flow.
- Simple output pane. Apps: Menu App, Chatroom, Wizardry Desktop, Forge. Best: Menu App’s `<pre>` output as the minimal single-surface form of this pattern.
- Read-only value block. Apps: Chatroom, Wizardry Desktop, Forge. Best: Chatroom settings code and value blocks for copy-centric URLs, addresses, and status text.
- Empty or error panel. Apps: Chatroom, Wizardry Desktop, Forge. Best: Chatroom server-not-running panel for a simple blocked-state surface with one recovery action.

## Embedded And Host-Coupled Surfaces
- Embedded iframe view. Apps: Chatroom. Best: Chatroom by default because it is the only checked-in user; treat it as a compatibility pattern for wrapping an existing site, not the default control-plane pattern.
- Host resize control. Apps: Forge. Best: Forge rail divider for a host-visible interactive separator.
- Boot splash. Apps: Wizardry Desktop. Best: Wizardry Desktop for a checked-in splash surface that keeps the shell hidden until the first ready frame.
- Splash and startup handoff. Apps: Forge, Wizardry Desktop. Best: standards file first, then Wizardry Desktop as the closest checked-in concrete example.

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
