# Phronesis Extraction Plan

## Purpose
- Prepare a new `phronesis` repository as the Wizardry-family standards and judgment layer.
- Move ecosystem-wide policy out of implementation repos without weakening local repo specificity.
- Keep Wizardry focused on POSIX sh mastery, Wizardry Apps focused on app/runtime implementation, and Theurgy focused on native/runtime boundaries.

## Proposed Repository Role
- `phronesis` owns standards, decision records, exception policy, audit methodology, policy IDs, compliance schemas, and promoted lessons.
- `wizardry` owns spell layout, POSIX shell style, terminal interaction, and shell test practice.
- `wizardry-apps` owns Forge, templates, app hosts, app bridges, app build/release machinery, and app-specific audit evidence.
- `theurgy` owns native runtime generation, native boundary contracts, platform output, and higher-runtime fan-out.

## Repository Status
- GitHub: `git@github.com:andersaamodt/phronesis.git`
- Local seed: `/Users/andersaamodt/git/phronesis`
- Initial seed pushed: 2026-06-13
- License: Open Wizardry License 3.1
- First canonical ideal document: `/Users/andersaamodt/git/phronesis/standards/repo-hygiene/wizardry-general.gitignore`

## Founding Principle
- Treat unreasoned app-to-app variance as standards debt.
- Every meaningful difference between apps should be one of:
  - a canonical standard
  - an approved exception with rationale and evidence
  - a pending decision item with an owner and re-audit trigger

## Candidate `phronesis` Layout
- `README.md`
  - mission, repo map, and read order
- `standards/`
  - canonical rules, grouped by policy area
- `decisions/`
  - decision records for why each major standard exists
- `exceptions/`
  - required exception shape and approved exception registry
- `audits/`
  - rolling audit method, category schema, and re-audit process
- `policies/`
  - stable policy IDs and enforcement levels
- `templates/`
  - repo-local `AI_DOCS.md`, `CODEX.md`, exception ledger, policy matrix, and audit report templates
- `lessons/`
  - promoted lessons distilled from Wizardry-family audits
- `tools/`
  - future validation helpers for policy matrices and report consistency

## Material To Extract From `wizardry-apps`
- `.github/ROLLING_AUDIT.md`
  - extract: audit axes, rolling rule, storage/language/test/theme criteria
  - leave local: Wizardry Apps built-in app scope and repo-specific evidence paths
- `.github/ROLLING_AUDIT_COMPLIANCE_FRAMEWORK.md`
  - extract: policy/category/finding/status model and reporting rules
  - leave local: Wizardry Apps category seed list only if app-specific
- `.github/PHRONESIS_POLICY_MATRIX_SCHEMA.yaml`
  - extract: policy matrix status values, record shapes, seed policy groups, and app-record template
  - leave local: nothing long-term; keep only a pointer once `phronesis` owns the schema
- `.github/ROLLING_AUDIT_PROPOSED_STANDARDS.md`
  - extract: approved standards after user review
  - leave local: unapproved app-specific candidates until promoted
- `.github/ROLLING_AUDIT_LEDGER.yaml`
  - extract: category schema and policy IDs
  - leave local: affected app lists and evidence refs
- `.github/WIZARDRY_APPS_ETHOS.md`
  - extract: ecosystem-wide principles if not app-specific
  - leave local: Forge/app-host/runtime details
- `.github/WIZARDRY_APPS_GUI_STANDARDS.md`
  - extract: shared GUI policy that should apply across app families
  - leave local: Wizardry Apps host and template implementation details
- `.github/adversarial-testing.md`
  - extract: universal adversarial method and bug classes
  - leave local: Wizardry Apps-specific bridge/host examples

## Material To Extract From `wizardry`
- `.github/CODEX.md`
  - extract: language authorization boundary, adversarial testing posture, repo hygiene, no contradiction rule
  - leave local: spell layout, POSIX sh templates, imps, and terminal-specific testing commands
- `.github/PUSH_READY_CHECKLIST.md`
  - extract: general push-ready hygiene, no repo-local runtime state, generated-artifact policy, comprehensive `.gitignore` wisdom
  - leave local: Wizardry-specific release and spell readiness details
- `.github/PACT_LANGUAGE.md`
  - extract only if pact vocabulary becomes ecosystem-wide policy
  - leave local if it remains a Wizardry spell-language convention

## Material To Extract From `theurgy`
- Native boundary policy and generated-runtime exception rules.
- Human-edited contract format policy if promoted beyond Theurgy.
- Generated output, staging, and runtime-state hygiene rules.

## Material That Should Stay Local
- Concrete commands for one repo's tests, builds, releases, or deployment.
- Evidence paths from one app audit.
- Repo topology and implementation maps.
- App-specific exception approvals.
- Templates that are executable implementation assets rather than policy examples.

## First `phronesis` Standards To Seed
- `variance.reasoned`: unreasoned meaningful variance is standards debt.
- `language.shell-first`: Wizardry-family orchestration is POSIX sh-first.
- `language.exception-ledger`: Python, Rust, Swift, Java, Kotlin, Node, and native outputs require explicit boundary classification.
- `storage.app-home-default`: primary durable app data defaults to `~/<appname>`.
- `storage.plain-text`: durable app data is plain text unless explicitly justified.
- `format.user-yaml-md`: user-facing durable files prefer YAML plus Markdown-oriented text.
- `tests.dot-tests`: tests live under `.tests/`.
- `tests.shipped-backend-contract`: shipped apps need backend contract tests.
- `tests.shipped-ui-contract`: shipped GUI apps need UI/static contract tests.
- `themes.shared-catalog-authority`: apps using Wizardry themes must discover the real shared theme catalog.
- `themes.native-shared-catalog-parity`: generated native targets exposing Wizardry themes must use the same discovered catalog across platform outputs.
- `bridge.no-shell-fragments`: frontends call explicit backend actions and never send shell fragments.
- `bridge.backend-resolution-owned`: frontend code does not derive backend executable paths from document paths.
- `runtime.no-cargo-on-demand`: shipped backend paths do not compile Cargo-managed helpers on demand.
- `docs.local-exceptions`: each repo keeps local AI-facing docs for its own exceptions and boundaries.
- `docs.exception-ledger-shape`: local AI docs must enumerate storage, language, theme, runtime, test, release, generated-output, and repo-cruft boundaries in a predictable shape.
- `repo.no-disposable-cruft`: source repos do not receive tracked placeholders, logs, caches, build products, package outputs, or app-instance state.

## First Template To Seed
- Repo-local `AI_DOCS.md` should start with upstream standards imports.
- It should then include a local exception ledger with these headings:
  - language boundaries
  - storage roots
  - durable file formats
  - theme system
  - runtime and bridge ownership
  - tests and known gaps
  - release, build, generated-output, and cruft policy
  - approved exceptions and pending decisions
- Redirect-only docs are acceptable only for repos with no local exceptions; otherwise, the local exceptions must be named where agents look first.

## Open Design Decisions
- Whether `phronesis` should store only prose policy first, or include a machine-readable policy registry from day one.
- Whether policy IDs should use dotted names such as `storage.app-home-default` or existing category slugs such as `storage-default-home-missing`.
- Whether approved exceptions live centrally in `phronesis` or locally in each repo with central schema validation.
- Whether Wizardry-specific pact vocabulary belongs in `phronesis` as ecosystem philosophy or stays local to Wizardry.
- Whether app-local theme systems are allowed freely once documented, or whether Forge-generated apps must default to shared Wizardry themes unless explicitly opted out.

## Next Actions Before Fix-It Phase
- Review this extraction map with the user.
- Promote accepted proposed standards into `phronesis` seed docs.
- Replace duplicated ecosystem-wide text in Wizardry-family repos with short local references plus local exception ledgers.
- Promote `.github/PHRONESIS_POLICY_MATRIX_SCHEMA.yaml` into `phronesis`, then add app records so future apps can be generated with every meaningful choice already decisioned.
