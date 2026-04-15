# Wizardry Apps Copilot Instructions

## Read First
- Read `/Users/andersaamodt/git/wizardry-apps/.github/AI_DOCS.md` first.
- Then read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_ETHOS.md`.
- Then read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_LICENSING.md` before changing Forge scaffolding, starter templates, emitted project files, or licensing behavior.
- Then read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_GUI_STANDARDS.md`.
- For cross-app GUI checks, read `/Users/andersaamodt/git/wizardry-apps/.github/GUI_AUDIT.md`.

## Hard Rules
- Follow Wizardry ethos and keep behavior file-first, explicit, and discoverable.
- Keep user-facing language non-imperative and self-healing in tone.
- Desktop-first apps do not use `localStorage` for durable state.
- Persist desktop preferences/state through backend plaintext files in XDG paths.
- Keep command execution constrained to hardcoded argv patterns in GUI code.
- Do not let user input construct executable names or arbitrary shell syntax.
- Preserve CLI parity for new GUI capabilities.
- Keep AI-facing docs in `.github/`, not the repo root.

## Change Discipline
- Prefer small, surgical edits over broad rewrites.
- Reuse existing app patterns before inventing new abstractions.
- Update AI docs in the same PR when policy or patterns change.
