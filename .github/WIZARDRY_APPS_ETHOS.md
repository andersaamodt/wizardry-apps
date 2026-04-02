# Wizardry Apps Ethos (AI-Facing)

## Scope
- This file defines AI behavior expectations for `wizardry-apps`.
- Wizardry core ethos from `~/.wizardry/README.md` remains canonical when conflicts appear.
- `wizardry-apps` extends that ethos for GUI, packaging, and app runtime surfaces.

## North Star
- Keep Wizardry useful, menu-driven, file-first, minimal, and discoverable.
- Prefer explicit behavior over hidden automation and magic side effects.
- Preserve CLI parity so removing a GUI does not remove capability.
- Treat every interface as a thin skin over transparent shell-backed behavior.

## User Interaction Tone
- User-facing text stays descriptive, calm, and non-imperative.
- Error text states what happened, not commands for the user to execute alone.
- Flows prefer self-healing actions or in-app actions over sending users away.
- If outside action is unavoidable, present a guided step sequence with validation gates.
- Each guided step should unlock the next step only after verifiable success.

## Data and State Policy
- File-first is mandatory: state belongs in plain-text files.
- State paths stay standardized, documented, and easy to locate.
- State scattering is avoided; choose the fewest durable locations that cover the need.
- Desktop-first apps do not use browser `localStorage` for durable data.
- Hosted web apps may use `localStorage` when web deployment behavior requires it.
- Desktop UI preferences persist through backend file APIs, not browser-owned storage.
- Read operations remain non-mutating unless the action is explicitly a write/update flow.
- Runtime logs, assay reports, transcripts, downloads, and other operator-local output belong in documented user/XDG state paths, not inside app repos.
- Generated executables, packaged releases, and build products stay ignored locally and are published through CI/release flows instead of being committed.

## Standard Storage Locations
- App config defaults to `${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/...`.
- App runtime/state defaults to `${XDG_STATE_HOME:-$HOME/.local/state}/wizardry/...` when needed.
- Workspace metadata belongs in `wizardry.workspace.conf` near the managed workspace root.
- Hosted site runtime settings belong in site-local files like `site.conf`.
- Any new storage path must be documented in app README and AI-facing docs.
- Repo-local generated paths are a last resort; when unavoidable, ignore them and document why they cannot live in state/temp locations.

## Security and Execution Model
- GUI-triggered commands are hardcoded argv arrays, not user-composed shell strings.
- WebView-to-host execution avoids `/bin/sh -c` for user-influenced arguments.
- User input never gains direct control over executable names or free-form argv vectors.
- Keep the bridge contract explicit and inspectable in app code.
- Prefer least-complex designs that are auditable by reading one file.

## Architecture and Delivery
- Minimal moving parts beat framework-heavy abstractions.
- POSIX shell remains the reference orchestration layer when orchestration is needed.
- GUI code should expose capabilities already present in backend scripts where possible.
- New GUI features should add or preserve a matching CLI/backend action for parity.
- Behavior must remain cross-platform conscious for macOS, Linux, iOS, Android, and hosted web.

## Workflow and Documentation
- AI-facing documentation for this repo lives in `.github/`.
- Guidance should be dense, flat, and short-bullet oriented for token efficiency.
- Canonicality order is: Wizardry core ethos, this file, app-specific standards.
- When policy and existing code disagree, update code toward policy unless user directs otherwise.
- New conventions should be added here immediately after adoption.
- Reuse `~/.wizardry/.github/PUSH_READY_CHECKLIST.md` for general repo-hygiene policy; keep only app-specific additions here.
- App publish surfaces must be scrubbed of local paths, personal identifiers, private notes, and repo-local runtime/test debris before push.
