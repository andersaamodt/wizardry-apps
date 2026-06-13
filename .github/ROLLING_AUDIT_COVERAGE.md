# Rolling Audit Coverage

## Purpose
- Track which Wizardry-family repos and app surfaces already have first-pass rolling audit coverage.
- Keep a live list of clearly pending candidates so the remaining pass is planned from evidence instead of memory.

## Covered So Far

### Core And Shared
- `wizardry`
- `wizardry-apps`
- `theurgy`

### Built-In `wizardry-apps` Surfaces
- `forge`
- `wizardry-desktop`
- `chatroom`

### App Repos Audited
- `bellheim`
- `binder`
- `counterspell`
- `dictator`
- `eye`
- `fauxzilla`
- `hegelizer`
- `mecha`
- `organizer`
- `pieplate`
- `simplerchat`

## In Progress Branches
- `bellheim`: `codex/audit-bellheim-round1`
- `binder`: `codex/audit-binder-round1`
- `counterspell`: `codex/audit-counterspell-round1`
- `dictator`: `codex/audit-dictator-round1`
- `eye`: `codex/audit-eye-round1`
- `fauxzilla`: `codex/audit-fauxzilla-round1`
- `hegelizer`: `codex/audit-hegelizer-round1`
- `mecha`: `codex/audit-mecha-round1`
- `organizer`: `codex/audit-organizer-round1`
- `pieplate`: `codex/audit-pieplate-round1`
- `simplerchat`: `codex/audit-simplerchat-round1`
- `theurgy`: `codex/audit-theurgy-round1`
- `wizardry-apps`: `codex/rolling-audit-wizardry-apps`
- `wizardry`: `codex/audit-wizardry-round1`

## Likely Remaining Candidates
- `applegate`
- `book-club`
- `matchbook`

## Deferred For Worktree Safety Or Scope Triage
- `stellar`
  - unrelated dirty icon work was already present during audit passes
- `boycott`
  - unrelated dirty icon work was already present during audit passes
- `pleroma`
  - unrelated dirty work was already present during audit passes
- `serenity`
  - unrelated dirty work was already present during audit passes

## Notes
- This file is a planning surface, not a claim that every listed candidate definitely belongs in the final family scope.
- If a repo is later judged out of scope, move it out of `Likely Remaining Candidates` rather than silently forgetting it.
