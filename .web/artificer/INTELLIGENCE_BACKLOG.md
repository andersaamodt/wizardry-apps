# Artificer Intelligence Backlog

This backlog tracks concrete implementation work for improving Artificer intelligence and conversation quality without autonomous unsafe self-modification.

## P0 (Now)

- INT-001 Failure taxonomy persistence
  - Goal: Record every run-loop failure into a normalized, file-backed taxonomy.
  - Storage: `mode-runtime/failure-taxonomy/events.tsv`
  - Acceptance:
    - Each failure ledger append writes one taxonomy row.
    - Taxonomy categories, severity, and recent events are queryable through API.
  - Progress:
    - Added `failure_taxonomy_query` API support with category/severity/surface/mode/time filters plus bounded result windows for deterministic analysis tooling.

- INT-002 User-visible learning memory
  - Goal: Surface taxonomy state in settings so users can inspect failure patterns.
  - Acceptance:
    - Settings show totals, top categories, and recent failures.
    - Data updates after new failures without app restart.
  - Progress:
    - Added settings-side taxonomy query controls (category/severity/surface/mode/since/limit) backed by `failure_taxonomy_query` for targeted pattern inspection.

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
    - Expanded high-order heuristics/fixtures for compliance-risk questions, deployment scope gaps, cloud/orchestration external actions, and destructive near-neighbor command cases.
    - Expanded fixture coverage with additional trigger/near-miss precedence cases and wired assay `decisions` runs to score full fixture signal parity (category + allow + all signal flags).
    - Added a multi-iteration assay mentor runner that executes full task panels per cycle, records decision-matrix outcomes per cycle, and produces cycle-over-cycle report tables.

- INT-006 Conversation flow latency and completion signaling
  - Goal: Remove dead-air gaps between run completion markers and assistant text rendering.
  - Acceptance:
    - UI always shows a live status until final assistant content is committed.
    - No visible completion state before content is actually available.
  - Progress:
    - Added assistant-delivery watch logic so finalizing feedback remains visible until assistant content lands (or fallback is inserted).
    - Strengthened finalizing-status rendering so the latest completed run keeps showing "Finalizing response..." until assistant output is actually present, reducing false-idle model-only states.
    - Updated `until-complete` to run with unbounded iteration sentinel semantics (runtime-budget bounded) instead of a hard numeric loop cap.
    - Added event-level `awaiting_assistant` signaling so completed runs continue surfacing finalization feedback even when pending counters race or clear out of order.
    - Upgraded `chat` quick-prompt construction to include recent conversation context, correction-aware follow-up guidance, and anti-platitude constraints to improve multi-turn conceptual continuity.
    - Added chat-specific off-topic detection + salvage reroute for correction turns (e.g., onboarding/non-sequitur drift, generic platitude lists) to improve relevance under weaker conversational models.
    - Upgraded conversational model preference scoring so `chat` fallback/salvage prefers general conversational strength over coder-specialized models when both are installed.
    - Added thread-focus anchors (recent user-turn summaries) to chat prompts so follow-up answers better preserve conceptual throughlines.
    - Added run-step text normalization so controller scaffolding markers render as cleaner human-readable timeline lines during live trace viewing.
    - Forced terminal run traces into collapsed rollup state by default to keep finished conversations scan-friendly while preserving expandable detail.

- INT-007 Thread/workspace ordering ergonomics
  - Goal: Improve recency-based thread placement and drag-reorder fluidity.
  - Acceptance:
    - New workspaces are inserted at top.
    - Thread moves to top on send with smooth reorder animation.
    - Workspace/thread drag reorder persists and remains stable on reload.

- INT-011 Mode-aware model recommendation and routing
  - Goal: Improve run quality by selecting models better matched to `chat` vs coding-heavy tasks.
  - Acceptance:
    - Backend can rank installed models per mode (conversation vs programming).
    - Chat fallback/salvage prefers high-conversation models over coder-specialized models when available.
  - Progress:
    - Added mode-aware model scoring and `model_recommendations` API output with ranked installed-model lists for `chat` and `programming`.
    - Wired conversational salvage to use the improved chat-preference selector.

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
    - Injected runtime learning summaries (latest failure taxonomy signals + quality scorecard trend) into each controller loop prompt so active runs can adapt to recent regressions.
    - Added mode-filtered accepted/applied proposal summaries as an additional runtime learning signal in controller prompts, including legacy title fallback when older proposals are missing explicit `source_mode`.
    - Added runtime adaptation guardrails derived from recent taxonomy/quality patterns, feeding actionable anti-regression instructions directly into controller prompts.
    - Added loop-stagnation detection that records repeated-transition failures and injects anti-repeat guardrails into subsequent controller iterations.

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
    - Added sustained-regression gating plus per-mode cooldown suppression to reduce repeated low-signal proposal spam while still escalating severe regressions.
    - Added mode-aware failure attribution and dedupe metadata (`source_mode`) so regression proposals are generated/suppressed per mode without cross-mode category contamination.
