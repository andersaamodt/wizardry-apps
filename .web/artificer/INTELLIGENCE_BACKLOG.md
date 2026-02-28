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
  - Progress:
    - Added a fixture-driven live decision-surfacing test pack for deterministic category/signal validation.

- INT-006 Conversation flow latency and completion signaling
  - Goal: Remove dead-air gaps between run completion markers and assistant text rendering.
  - Acceptance:
    - UI always shows a live status until final assistant content is committed.
    - No visible completion state before content is actually available.
  - Progress:
    - Added assistant-delivery watch logic so finalizing feedback remains visible until assistant content lands (or fallback is inserted).
    - Strengthened finalizing-status rendering so the latest completed run keeps showing "Finalizing response..." until assistant output is actually present, reducing false-idle model-only states.

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
  - Progress:
    - Added file-backed controller variant store with baseline + proposal-derived candidates, manual promote/rollback gates, and per-variant quality aggregates.
    - Wired run-time variant selection into controller prompt construction and recorded run-level telemetry for before/after quality deltas.
    - Surfaced controller variant state and promote/rollback controls in Mode Runtime settings.

- INT-009 Security specialist modes
  - Goal: Strengthen `pentest` and `security-audit` modes with stricter evidence contracts.
  - Acceptance:
    - Mode policies emit structured finding reports (severity, evidence, remediation).
    - Unsafe offensive behavior remains policy-blocked.
  - Progress:
    - Added post-run security output normalization that enforces structured findings with Severity, Evidence, Remediation, and Status when model output is underspecified.
    - Added stronger synthesis contract prompts for `pentest` and `security-audit` finalization paths.

- INT-010 Quality scorecard automation
  - Goal: Continuously track intelligence and flow quality trends.
  - Acceptance:
    - Scorecard file updates per cycle with before/after deltas.
    - Regressions auto-create proposals tagged to affected failure categories.
  - Progress:
    - Added file-backed quality scorecard entries and markdown summary refresh on each scored run.
    - Added regression-triggered proposal generation from scorecard deltas, tagged to recent failure taxonomy categories.
