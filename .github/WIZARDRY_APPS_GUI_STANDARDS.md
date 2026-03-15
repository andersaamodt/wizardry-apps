# Wizardry Apps GUI Standards (AI-Facing)

## Scope
- This file defines GUI implementation standards for Wizardry desktop and hosted app surfaces.
- Use this with `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_ETHOS.md`.

## Core GUI Posture
- GUIs are operational consoles, not decorative wrappers detached from backend truth.
- A GUI action should map to one explicit backend action whenever possible.
- Keep flows legible: users should understand what action just ran and what changed.
- Keep startup resilient: detect bridge readiness and retry gracefully before failing hard.
- Build GUIs with care and polish; avoid rushed or placeholder-feeling interfaces.
- Never ship half-ass GUI work; finish layout, spacing, and state feedback details.
- Always use app theme colors/tokens instead of ad-hoc hardcoded color choices.

## Startup Splash Contract
- Desktop apps use one standard splash treatment: centered app logo on the active theme background.
- Use the splash instead of rendering partial app chrome or placeholder runtime data before initial app state is ready.
- During splash, any underlying host/WebView regions must be pre-colored to the same theme surface so nothing flashes through.
- During splash, no browser/WebView/host scrollbar should be visible; boot state must suppress overflow until the first ready frame is shown.
- Desktop windows must start at their intended initial size before splash handoff; do not visibly resize the host window after opening just to reach the correct startup height.
- Splash handoff must be an atomic flip from splash to ready UI with no fade, no crossfade, and no staggered reveal.
- The main interface must stay hidden until initial data/theme/layout state is ready for first interaction.
- After splash hides, no delayed boot-only animations should continue loading core interface structure.
- Remove splash only after web UI signals readiness via bridge hook such as `__wizardry_host_boot_ready`.

## Theme System Contract
- Use centralized `wizardry-themes` palettes/tokens instead of creating app-specific theme systems.
- Theme colors should drive nearly the entire interface, including panels, lines, controls, menus, and scrollbars.
- Theme selection control must exist either on the main screen or in Settings for every theme-capable app.
- Selecting a theme must apply instantly with no reload and no deferred repaint artifacts.
- Opening and closing theme picker without changing value must preserve the current active selection state.
- With theme picker focused, `ArrowUp` and `ArrowDown` must cycle themes immediately and apply each step instantly.
- Persist selected theme via backend prefs for desktop apps; do not rely on browser-owned durability.

## Button And Icon Style Contract
- Use unobtrusive icon style for most minor icon-only actions (copy, reveal, overflow, helper actions).
- Unobtrusive icon style is borderless/backgroundless at rest and gains opaque rounded background on hover/focus.
- In dense toolbars, prefer icon-first controls for secondary actions and keep text labels for the highest-impact primary actions.
- Icon-only controls must include a clear tooltip/title and explicit `aria-label`.
- Keep toolbar icon sizing and stroke weight consistent across actions in the same bar.
- Use polite button style for most primary workflow buttons (Build, Run, Create, Save, Apply).
- Polite button style is a simple outlined button with rounded corners and a clear hover highlight.
- Polite toggle buttons must stay visibly highlighted while toggled on.
- For in-field icon helpers, reserve input padding so text never overlaps the icon hit target.
- Keep both button styles keyboard focusable with obvious focus-visible states.

## Visual Hierarchy Contract
- Prefer visual hierarchy with spacing, typography, and separating lines over heavy frame-within-frame boxes.
- Use separators and section headers to create structure before adding extra borders.
- Keep dense control groups compact, aligned, and scannable; avoid decorative wrappers that hide hierarchy.
- Avoid stacking multiple decorative borders around the same logical group; one container boundary is usually enough.
- Use background tint and spacing depth before introducing another card/border level.
- Flatten wrapper structure aggressively; remove structural `div`/panel layers that only restack or pad content already separated by cards, sections, or rails.

## Left-Right Panel Pattern
- When one primary data type is being managed, use left-right split layout: list/select on left, details/workflow on right.
- Left side should prioritize fast browsing/filtering and single-click selection.
- Right side should focus on selected item context, actions, and result/log output.
- In this pattern, place Settings icon at lower-left corner of the left rail.
- Place theme and optional LLM dropdown controls to the right of Settings in the same bottom-left rail bar.
- Keep left rail width bounded and persist user resize preference when a divider is provided.

## Sidebar and Drawer Pattern
- Use sidebars/drawers for contextual utilities (settings, activity, diagnostics) instead of route-switching away from the main workflow.
- Sidebar open/close must preserve current selection and scroll context in the main pane.
- Provide at least two close paths for sidebars: explicit toggle button and `Escape` (plus outside click when overlay behavior is used).
- Trigger sidebars from compact icon controls in rails/toolbars; keep explanatory text inside the opened panel header/body.
- Avoid full-screen modal takeover for routine settings; reserve modal blocking for confirmations or destructive actions.

## Right-Side Menu Bar Pattern
- For left-right apps, place a top bar above right pane containing item title, location/path widget, and primary actions.
- Path widget behavior standard is click to copy path and double-click to open/reveal path.
- Keep path text compact with ellipsis behavior and an icon-only fallback when horizontal space is tight.
- Keep primary action buttons in the same bar so item context and actions are colocated.

## Desktop Window Fit And GUI QA
- Desktop UIs must fit fully in-window; no important controls should render off-screen or clip outside viewport.
- Avoid layouts that force horizontal overflow for baseline app workflows.
- Desktop apps should keep their intended desktop composition at narrow sizes; do not collapse split-pane/two-column control surfaces into liquid single-column layouts and instead enforce the minimum host window width needed for the designed view.
- In scrollable desktop panes, do not leave decorative gutter outside the scrollbar; if the pane is intended to reach the window edge, make the scroll track sit flush to that edge and keep content padding inside the scrolling area instead.
- Validate GUI layout and interaction quality with Safari automations for desktop app surfaces when making GUI changes.
- Validate startup (no flicker), focus states, hover states, and split-pane behavior in that QA pass.

## Command and Bridge Rules
- Bridge calls use explicit argv arrays passed to `wizardry.exec(argv)`.
- Commands are selected from code-defined allowlists, not free-form user text.
- Avoid building shell fragments from user input; prefer positional args.
- Keep backend entrypoints in `scripts/*-backend.sh` and expose stable action names.
- Return machine-readable output for structured UI paths and plain text for logs.

## Storage Rules
- Desktop persistence goes through backend `get-ui-prefs` and `set-ui-pref` style actions.
- Persisted values live in plaintext key-value files under XDG config/state roots.
- Browser `localStorage` is not a desktop durability layer.
- In hosted-web-first apps, `localStorage` use can be acceptable when documented.
- Cache values in memory first, then sync to backend on change.

## Workflow Design Rules
- Replace “go do X and come back” with in-app guided workflows.
- Multi-step flows should expose current step, next step, and completion criteria.
- If an external action is required, pair instruction with immediate verification control.
- Gate sensitive actions behind explicit confirmation in the same interface.
- Surface undo/revert actions when behavior is irreversible or high-impact.
- For low-risk settings in control-plane apps, prefer autosave on edit/change over explicit Save buttons.
- For live runtime state in control-plane apps, prefer background refresh and visibility/focus refresh over explicit Refresh buttons.

## Feedback and Error Handling
- Show command status, outcome, and stderr/stdout context in-app.
- Keep status text factual and non-imperative.
- Prefer progress + result messaging over silent background work.
- Use short toasts for confirmation and durable panels for actionable errors.
- Keep logs inspectable, keyboard-selectable, and copyable from the GUI.

## Discoverability and Navigation
- Keep primary actions visible without deep nesting.
- Group actions by user intent, not by internal implementation layers.
- Keep settings easy to find and clearly separate global vs project state.
- Use consistent labels for repeated concepts across apps.
- Prefer one-screen comprehension over hidden routes and modal mazes.

## Admin List Pages
- Prefer row-based management tables over card grids for dense admin lists (users, drafts, posts, queue).
- Use full-width rows with alternating subtle background tint for scanability.
- Keep each row concise, ideally one-line with compact pills for status/source metadata.
- Put destructive or advanced actions behind a compact overflow menu to reduce visual noise.
- Keep list pages live-updating when visible, but pause refresh while menus/actions/drag operations are active.

## Live Refresh Safety
- Background refresh loops should pause while high-risk interactions are active (active command, drag, open menu, modal input).
- Refresh loops should run on visibility/focus regain for freshness without constant polling load.
- Keep current selection stable across refreshes whenever the selected item still exists.

## Cross-App Interaction Patterns
- Route GUI actions through one backend adapter that logs argv and normalizes command errors into concise summaries.
- Keep a persistent bridge/connectivity status surface separate from action-level toast messages.
- Keep one busy state for write actions and disable overlapping action triggers while a command is running.
- Keep logs prepend-timestamped, bounded in size, keyboard-selectable, and copy/clear capable.
- Keep at most one floating menu open at a time and keep trigger `aria-expanded` values in sync.
- Close floating menus on outside click and `Escape`, and restore focus to the triggering control when practical.
- Keep list rows keyboard-selectable (`Enter`/`Space`) and preserve selection across data refreshes when the item still exists.
- Keep path chips compact: basename label, ellipsis handling, icon-only fallback in narrow widths, click-to-copy, and double-click-to-open/reveal.
- For folder path utilities, provide an optional adjacent open-in-terminal control with explicit tooltip/aria labeling.
- For drag-and-drop folder import, only show drop cues for valid payload types and clear cues immediately on leave/drop.
- Parse dropped paths from both URI payloads and file payloads for host/runtime portability.
- Prefer section-local expansion/collapse (`details/summary`) for multi-step workflows to preserve one-screen comprehension.
- Keep motion subtle (roughly 180-220ms) and disable non-essential motion when `prefers-reduced-motion` is enabled.

## Host Drag-Region Geometry
- Keep drag behavior in native-host geometry and click behavior in WebView controls.
- Reserve drag-strip holes around interactive controls instead of placing drag layers over controls.
- Recompute host drag geometry on resize and dynamic title/control width changes.
- Keep a dedicated reserved width for right-side controls so host drag zones cannot steal clicks.
- For centered top tab bars (for example Headquarters), do not use the generic centered drag strip; use host left/right strips with a dynamic center hole driven by live tab bounds.
- The host command `__wizardry_host_priorities_drag_hole` takes `holeLeft`, `holeRight`, and `rightReserved` where `holeLeft/holeRight` are center-to-hole-edge distances (non-draggable), not drag-strip widths.

## Port and Runtime Safety
- Never hardcode a fixed localhost port for embedded site URLs.
- Resolve runtime port from canonical config files like `site.conf`.
- Handle port conflicts by selecting safe alternatives through backend actions.
- Show the resolved runtime endpoint in the UI when it matters.

## File and Path Conventions
- Keep app entrypoint at `apps/<slug>/index.html`.
- Keep app backend at `apps/<slug>/scripts/<slug>-backend.sh` when backend logic exists.
- Keep app-scoped docs in `apps/<slug>/README.md` for runtime paths and operator notes.
- Keep naming consistent with hyphenated app slugs.

## Icon Assets and Licensing
- Prefer local SVG icon assets over raster icons for toolbar/rail controls when possible.
- Prefer public-domain or permissive-license icon sources (for example CC0/public domain/0BSD) and keep attribution/license notes in app docs when required.
- Normalize imported SVGs for consistent sizing, stroke behavior, and theme-color compatibility before committing.
- Avoid mixing multiple incompatible icon styles in the same surface (for example heavy filled glyphs beside thin outline symbols).

## Accessibility and Input Ergonomics
- Use semantic controls and keyboard-operable interactions.
- Keep focus states visible and modal escape paths obvious.
- Avoid click-only critical actions; support keyboard submission where practical.
- Preserve native text-editing shortcuts in text-entry controls; do not intercept `Ctrl/Cmd/Alt` combos for cut/copy/paste/select-all/undo/redo/navigation.
- Global key handlers must early-return for editable targets with modifier keys instead of hardcoding app-level shortcut patches.
- Avoid defaulting buttons and short text-entry inputs to `width: 100%`; size them to content or a bounded width unless full-width is required by layout.
- Form controls should usually be content-sized or bounded-width rather than stretched full-width; reserve full-width controls for genuinely long freeform input areas or narrow sidebars where a bounded width would waste space.
- Numeric steppers and short number-entry boxes should be explicitly bounded to compact widths; do not let small scalar settings consume the same width as long text fields.
- Do not make buttons, pills, selects, or ordinary text inputs weirdly tall or fat; default control sizing should stay compact unless a larger target is required by a specific workflow.
- Keep motion subtle and meaningful, never required for comprehension.

## Conflict Resolution Order
- If an app implementation conflicts with this file, treat this file as canonical for new work and move touched legacy code toward it.
- Use Forge interaction patterns as the default baseline for new desktop control-plane apps.
- Treat simple wrapper apps (for example menu-app/chatroom) as compatibility references, not visual or interaction baselines.
- Legacy fixed-color screens may remain untouched, but any edited/new screens should migrate to theme-token styling.
- Shell-based fallback command resolution is acceptable only for fixed internal script lookup with no user-controlled executable or shell fragment input.
- When density conflicts with clarity, prioritize clear labels and explicit state feedback over packing additional controls.

## AI Agent Delivery Rules
- Prefer surgical edits that preserve each app’s existing visual language.
- Extend shared patterns already present in Forge/Priorities/Virtual Redditor first.
- When introducing a new pattern, document it in this file within the same change.
- Avoid speculative frameworks or architectural rewrites without explicit user request.
