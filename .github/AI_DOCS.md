# Wizardry Apps AI Docs Map

## Read Order
- Read `/Users/andersaamodt/git/wizardry-apps/README.md` for repo stance and boundaries.
- Read `/Users/andersaamodt/.wizardry/.github/PUSH_READY_CHECKLIST.md` for canonical repo-hygiene, artifact, and publish-surface rules.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_ETHOS.md` for policy and tone.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_LICENSING.md` before changing licensing, scaffolding, starter templates, emitted project files, or Forge project-generation behavior.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/WIZARDRY_APPS_GUI_STANDARDS.md` for mandatory GUI patterns and behavior contracts.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/RELEASE_POLISH.md` when doing 1.0 polish, onboarding/readiness work, update surfaces, packaging, or Nostr-specific release hardening.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/GUI_AUDIT.md` when doing cross-app GUI sweeps so audits stay source-linked and non-redundant.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/adversarial-testing.md` when doing adversarial testing, security-minded bug hunts, release hardening, or GUI edge-case sweeps.
- Read `/Users/andersaamodt/git/wizardry-apps/.github/GUI_LESSONS.md` for known host/WebView pitfalls and regression lessons.
- For new cross-platform app shells, reference `/Users/andersaamodt/git/wizardry-apps/apps/forge/starter-templates/web/reference-app/` first; keep it updated when Wizardry standards evolve.
- Read app-local docs (for example `apps/forge/README.md`) before changing an app.

## Canonicality
- Wizardry core ethos in `~/.wizardry/README.md` is upstream-canonical.
- Wizardry core push-readiness and repo-hygiene rules in `~/.wizardry/.github/PUSH_READY_CHECKLIST.md` are upstream-canonical.
- This repo may specialize rules for GUI/runtime concerns without violating upstream ethos.
- If specialization conflicts with upstream, prefer upstream unless user instruction overrides.

## Authoring Style For AI Docs
- Keep docs as flat bullet lists.
- Keep bullets to short one-liners when possible.
- Keep guidance concrete, testable, and path-specific.
- Add new policy where agents will actually look first.
