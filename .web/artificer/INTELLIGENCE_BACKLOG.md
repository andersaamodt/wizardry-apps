# Artificer Intelligence Backlog

This backlog tracks concrete implementation work for improving Artificer intelligence and conversation quality without autonomous unsafe self-modification.

## P0 (Now)

- INT-001 Failure taxonomy persistence
  - Goal: Record every run-loop failure into a normalized, file-backed taxonomy.
  - Storage: `mode-runtime/failure-taxonomy/events.tsv`
  - Acceptance:
    - Each failure ledger append writes one taxonomy row.
    - Taxonomy categories, severity, and recent events are queryable through API.

- INT-002 User-visible learning memory
  - Goal: Surface taxonomy state in settings so users can inspect failure patterns.
  - Acceptance:
    - Settings show totals, top categories, and recent failures.
    - Data updates after new failures without app restart.

- INT-003 Contained self-improvement proposals
  - Goal: Generate improvement proposals from recurring failure categories.
  - Storage: `mode-runtime/improvement-proposals/<proposal-id>/`
  - Acceptance:
    - Proposal generation endpoint creates proposals from repeated failure clusters.
    - Proposal status workflow supports `proposed`, `accepted`, `applied`, `rejected`.
    - Applying requires explicit manual confirmation; no autonomous pipeline edits.

- INT-004 Manual governance controls in UI
  - Goal: Let users generate and decide proposals in settings.
  - Acceptance:
    - "Generate from failures" control exists.
    - Per-proposal Accept/Apply/Reject actions update state in UI.

## P1 (Next)

- INT-005 Decision-surfacing coverage expansion
  - Goal: Increase recall/precision for advanced decision categories.
  - Acceptance:
    - Add deterministic prompt fixtures for each decision type and near-miss variants.
    - Add regression tests ensuring category-specific routing remains stable.

- INT-006 Conversation flow latency and completion signaling
  - Goal: Remove dead-air gaps between run completion markers and assistant text rendering.
  - Acceptance:
    - UI always shows a live status until final assistant content is committed.
    - No visible completion state before content is actually available.

- INT-007 Thread/workspace ordering ergonomics
  - Goal: Improve recency-based thread placement and drag-reorder fluidity.
  - Acceptance:
    - New workspaces are inserted at top.
    - Thread moves to top on send with smooth reorder animation.
    - Workspace/thread drag reorder persists and remains stable on reload.

## P2 (Scale)

- INT-008 Multi-run learning loop for controller prompts
  - Goal: Feed accepted proposals into versioned controller prompt variants with rollback.
  - Acceptance:
    - Prompt variants are file-versioned and reversible.
    - A/B telemetry compares quality deltas before promotion.

- INT-009 Security specialist modes
  - Goal: Strengthen `pentest` and `security-audit` modes with stricter evidence contracts.
  - Acceptance:
    - Mode policies emit structured finding reports (severity, evidence, remediation).
    - Unsafe offensive behavior remains policy-blocked.

- INT-010 Quality scorecard automation
  - Goal: Continuously track intelligence and flow quality trends.
  - Acceptance:
    - Scorecard file updates per cycle with before/after deltas.
    - Regressions auto-create proposals tagged to affected failure categories.
