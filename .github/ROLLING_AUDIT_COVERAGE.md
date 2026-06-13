# Rolling Audit Coverage

## Purpose
- Track which Wizardry-family repos and app surfaces already have first-pass rolling audit coverage.
- Keep a live list of clearly pending candidates so the remaining pass is planned from evidence instead of memory.

## Covered So Far

### Pass 2 Preparation
- `phronesis` extraction plan started
- unreasoned variance ledger started
- late round-1 criterion back-application checklist started
- built-in Wizardry Apps surfaces checked for backend path derivation, shell-fragment fallback, and Cargo runtime layers
- first earlier app batch checked for backend path derivation and Cargo runtime layers: `bellheim`, `binder`, `dictator`, `counterspell`, `fauxzilla`
- clean/reference-like app batch checked for backend path derivation and Cargo runtime layers: `matchbook`, `book-club`, `organizer`, `simplerchat`
- remaining app batch checked for backend path derivation and Cargo runtime layers: `applegate`, `eye`, `mecha`, `pieplate`, `serenity`, `stellar`, `boycott`, `pleroma`
- no app code remediation has started

### Core And Shared
- `wizardry`
- `wizardry-apps`
- `theurgy`

### Built-In `wizardry-apps` Surfaces
- `forge`
- `wizardry-desktop`
- `chatroom`

### App Repos Audited
- `applegate`
- `bellheim`
- `boycott`
- `binder`
- `book-club`
- `counterspell`
- `dictator`
- `eye`
- `fauxzilla`
- `hegelizer`
- `matchbook`
- `mecha`
- `organizer`
- `pleroma`
- `pieplate`
- `serenity`
- `simplerchat`
- `stellar`

## In Progress Branches
- `applegate`: `codex/audit-applegate-round1`
- `bellheim`: `codex/audit-bellheim-round1`
- `boycott`: `codex/audit-boycott-round1`
- `binder`: `codex/audit-binder-round1`
- `book-club`: `codex/audit-book-club-round1`
- `counterspell`: `codex/audit-counterspell-round1`
- `dictator`: `codex/audit-dictator-round1`
- `eye`: `codex/audit-eye-round1`
- `fauxzilla`: `codex/audit-fauxzilla-round1`
- `hegelizer`: `codex/audit-hegelizer-round1`
- `matchbook`: `codex/audit-matchbook-round1`
- `mecha`: `codex/audit-mecha-round1`
- `organizer`: `codex/audit-organizer-round1`
- `pleroma`: `codex/audit-pleroma-round1`
- `pieplate`: `codex/audit-pieplate-round1`
- `serenity`: `codex/audit-serenity-round1`
- `simplerchat`: `codex/audit-simplerchat-round1`
- `stellar`: `codex/audit-stellar-round1`
- `theurgy`: `codex/audit-theurgy-round1`
- `wizardry-apps`: `codex/rolling-audit-wizardry-apps`
- `wizardry`: `codex/audit-wizardry-round1`

## Likely Remaining Candidates
- none currently

## Deferred For Worktree Safety Or Scope Triage
- none currently

## Notes
- This file is a planning surface, not a claim that every listed candidate definitely belongs in the final family scope.
- If a repo is later judged out of scope, move it out of `Likely Remaining Candidates` rather than silently forgetting it.
