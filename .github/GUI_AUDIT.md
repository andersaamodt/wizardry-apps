# Wizardry Apps GUI Audit Checklist (AI-Facing)

## Purpose
- Use this file for periodic cross-app GUI audits to catch drift in basic control behavior and interaction quality.
- This file is an audit index, not a second standards source; canonical policy stays in `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_GUI_STANDARDS.md`.
- Keep checks short and reference canonical sections instead of restating policy text.

## Audit Inputs
- Read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_GUI_STANDARDS.md` first.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/GUI_LESSONS.md` for known regressions.
- Audit all shipped app surfaces in `apps/`: `forge`, `wizardry-desktop`, `chatroom`, and `menu-app`.

## Audit Output Contract
- Produce per-app pass/fail notes with file evidence (`apps/<slug>/...`) for every check group below.
- If a check fails, fix code first when safe; if not safe, log a concrete blocker and owner.
- If a fix introduces a new cross-app pattern, update canonical standards in the same change.
- Keep audit reports non-redundant: cite section names from standards rather than copying full rules.

## Cross-App Checklist
- [ ] Startup and splash behavior matches `Startup Splash Contract` where applicable to the app host.
- [ ] Theme controls and theme application match `Theme System Contract`.
- [ ] Desktop theme persistence uses backend prefs and plaintext files, not browser-owned durability (`Theme System Contract` + `Storage Rules`).
- [ ] Minor icon actions and primary actions match `Button And Icon Style Contract`.
- [ ] Buttons/selects/short inputs are fit-to-content or bounded-width by default (`Accessibility and Input Ergonomics`).
- [ ] Settings surfaces follow `Sidebar and Drawer Pattern` or modal guidance (`Modal dialog` behavior in standards sections).
- [ ] Settings/dialog close paths include explicit close control plus `Escape`, and backdrop click-close when overlay behavior is used (`Sidebar and Drawer Pattern`).
- [ ] Most low-risk settings autosave; explicit Save is reserved for higher-risk/batched edits (`Workflow Design Rules`).
- [ ] Refresh behavior avoids manual-refresh-only drift when background/visibility refresh is appropriate (`Workflow Design Rules` + `Live Refresh Safety`).
- [ ] Persistent status surfaces are separate from transient confirmations (`Feedback and Error Handling` + `Cross-App Interaction Patterns`).
- [ ] Logs/output surfaces are bounded, selectable, and copyable where logs exist (`Feedback and Error Handling` + `Cross-App Interaction Patterns`).
- [ ] Keyboard paths work for primary controls: `Tab`, `Shift-Tab`, `Enter`, `Space`, `Escape`, and arrow-key pickers where relevant (`Accessibility and Input Ergonomics` + `Cross-App Interaction Patterns`).
- [ ] Focus-visible states are obvious for interactive controls (`Button And Icon Style Contract` + `Accessibility and Input Ergonomics`).
- [ ] Listbox-style selected rows use inset rounded highlights instead of edge-to-edge full-width highlight fill (`Cross-App Interaction Patterns`).
- [ ] Runtime endpoint/port handling avoids fixed localhost ports and resolves canonical config (`Port and Runtime Safety`).
- [ ] Bridge execution remains hardcoded argv with no user-composed shell fragments (`Command and Bridge Rules`).
- [ ] Safari GUI QA is run for GUI changes and verifies layout, focus/hover, and panel behavior (`Desktop Window Fit And GUI QA`).

## App-Specific Minimum Checks
- `forge`: left-right rail behavior, resizable divider persistence, path chip interactions, theme picker key handling.
- `wizardry-desktop`: right activity drawer behavior, compact settings modal behavior, theme application and persistence.
- `chatroom`: embedded viewport loading, integrated settings controls, server/client mode behavior, endpoint persistence.
- `menu-app`: baseline control sizing and button behavior; treat as compatibility reference, not style baseline.

## Lightweight Report Template
- `App:` `<slug>`
- `Pass:` `yes/no`
- `Checks failed:` `<check bullets or "none">`
- `Evidence:` `<absolute file paths>`
- `Fixes shipped:` `<commit or file summary>`
- `Follow-up:` `<none or concrete next action>`
