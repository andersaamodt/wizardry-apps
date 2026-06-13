# Wizardry Apps Copilot Instructions

## Read First
- Read `/Users/andersaamodt/git/wizardry-apps/.github/AI_DOCS.md` first.
- Then read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_ETHOS.md`.
- Then read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_LICENSING.md` before changing Forge scaffolding, starter templates, emitted project files, or licensing behavior.
- Then read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_GUI_STANDARDS.md`.
- For cross-app GUI checks, read `/Users/andersaamodt/git/wizardry-apps/.github/GUI_AUDIT.md`.

## Hard Rules
- Follow Wizardry ethos and keep behavior file-first, explicit, and discoverable.
- Wizardry-family projects are POSIX sh-first by default; Python or Rust are never implicitly authorized just because the ecosystem can touch them, and an AI must not introduce or preserve them without explicit user approval.
- Keep user-facing language non-imperative and self-healing in tone.
- Desktop-first apps do not use `localStorage` for durable state.
- Persist desktop preferences/state through backend plaintext files in XDG paths.
- Never put app-instance state, user settings, runtime logs, browser profiles, temp homes, caches, or other operator-local cruft inside a repo checkout.
- Treat repo folders as canonical source/development context only, never as per-machine app-instance directories.
- Put transient output in an appropriate temp path such as `/tmp` or `${TMPDIR:-/tmp}`, and put durable operator-local state in XDG/user-local state directories outside the checkout.
- If an app or tool writes cruft into a repo, treat that as a bug to fix at the source, not a mess to preserve or paper over with ignores.
- Keep command execution constrained to hardcoded argv patterns in GUI code.
- Do not let user input construct executable names or arbitrary shell syntax.
- Preserve CLI parity for new GUI capabilities.
- Keep AI-facing docs in `.github/`, not the repo root.

## Change Discipline
- Prefer small, surgical edits over broad rewrites.
- Reuse existing app patterns before inventing new abstractions.
- Update AI docs in the same PR when policy or patterns change.
