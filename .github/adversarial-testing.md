# Wizardry Apps Adversarial Testing Standard

Use this when auditing Wizardry app backends, WebView bridges, release helpers, Forge-generated projects, and GUI surfaces. The goal is hostile-but-plausible testing that finds real bugs, then fixes only the issues that can corrupt state, escape intended paths, run the wrong command, break packaging, or hide meaningful failures.

## Method
- Read `AI_DOCS.md`, `WIZARDRY_APPS_ETHOS.md`, `WIZARDRY_APPS_GUI_STANDARDS.md`, and `~/.wizardry/.github/adversarial-testing.md` first.
- Pick one narrow surface: backend args, profile files, bridge actions, GUI input, release metadata, app packaging, or drag/drop payloads.
- Reproduce the failure with a temp-root test or Safari/WebKit GUI probe before editing code.
- Add the smallest regression test that proves the adversarial case cannot recur.
- Fix by reusing existing validators and command patterns; do not introduce broad policy layers for one local bug.
- Run `banish 8`, syntax checks, focused tests, and Safari automation for GUI behavior changes.
- Keep test output, screenshots, logs, and scratch projects outside the repo unless they are deliberate fixtures.
- Commit each completed adversarial batch before starting a different surface.

## High-Value App Bug Classes
- Path segment values must reject `.`, `..`, `/`, `\`, line breaks, and empty values before filesystem side effects.
- Identifiers used in both paths and metadata need one shared validator across create, edit, rename, build, and release paths.
- Names later interpolated into `grep`, nginx, Tor, or service-file matching must reject regex metacharacters even when paths are quoted.
- Composite refs such as `source:name` must be parsed structurally; shell word splitting must not accept trailing words or unsupported source kinds.
- CSV-like fields must reject leading commas, trailing commas, empty entries, unsupported characters, and line-break injection.
- Key-value profile writes must keep keys allowlisted and values single-line unless multi-line is the explicit contract.
- Tab-, pipe-, and comma-delimited records must reject delimiter characters in fields before persisting or emitting rows for GUI parsers.
- Machine-readable `key=value` backend output must not echo raw request values that can introduce newlines or forged keys.
- Generated config, plist, desktop, JSON, YAML, and shell files must not receive raw GUI text that can break the target format.
- Imported config paths rendered into nginx, service, plist, or shell snippets must reject the target format's control characters.
- Release asset names must be basenames only; reject archive or API metadata before download, extraction, install, or chmod.
- Store/release IDs such as App Store key IDs, bundle IDs, Play package names, tracks, and version lists must be validated before paths, JWTs, query strings, or API URLs are built.
- Store credential IDs should be validated consistently across upload, promote, and build helpers before platform tools receive them.
- Release-control flags should reject unsupported values instead of silently changing deploy, review, or publish behavior.
- Store release-status values should be allowlisted before upload/promotion helpers perform irreversible API work.
- Release manifests are build inputs; validate slugs, names, targets, bundle IDs, publish flags, and optional source records before workflows iterate them.
- Manifest "single-line" string validators should reject tabs as well as CR/LF because tabs are row delimiters in GUI/backend contracts.
- Manifest catalog `source.subdir` values are repo-internal paths; reject absolute paths, empty path components, `.`, `..`, backslashes, tabs, and CR/LF before clone/copy/cache removal code runs.
- Git remotes are user-controlled metadata; sanitize CR/LF and validate `owner/repo` slugs before emitting status rows or GitHub API URLs.
- Git remote write commands must reject CR/LF before persisting URLs, even if imported remote status readers sanitize later.
- Publish-surface sync helpers must be argument-driven, scoped to documented paths, preserve local-only host directories, and copy dotfiles explicitly.
- Staging helpers that delete/recreate destinations must reject destinations that overlap any source directory before `rm -rf`.
- Generated metadata committed to the repo must not preserve machine-local absolute paths; readers should resolve project-relative paths and ignore out-of-project config paths.
- Workspace relative paths must resolve inside the workspace after symlinks, not just pass string checks.
- Workspace path arguments should reject line breaks before Git/status helpers echo paths or run Git side effects.
- Workspace mutation commands must enforce the same path output contract as list/status commands before writing profiles or renaming folders.
- Workspace rebuild/run/install and icon mutation commands also emit machine-readable rows; reject line-break project paths before build, launch, install, or asset writes.
- Imported project profiles are untrusted input; runtime/build paths should sanitize or fall back before writing bundle IDs, file names, or launchers.
- Imported display names can contain CR even when the key/value reader is line-based; sanitize or fall back before printing `app_name`, writing desktop entries, or naming bundles.
- When deriving bundled entry suffixes, compare canonical workspace and app paths; `/var` versus `/private/var` mismatches can turn a relative app path into a nested absolute path.
- Hosted-web site configs are generated by project scripts; revalidate domain and port after reading them before printing `url=...`.
- Bridge commands must use fixed action names and argv arrays; never let GUI input choose executables, shell fragments, or free-form argv vectors.
- Busy/write actions must reject overlapping triggers so double-clicks cannot race profile writes, installs, icon generation, or release downloads.

## GUI Adversarial Inputs
- Try empty strings, whitespace-only strings, very long labels, quotes, angle brackets, ampersands, slashes, backslashes, leading hyphens, `..`, commas, and line breaks.
- Try values that are valid on create but later edited through rename/settings/advanced fields; validators must be consistent across both paths.
- Try keyboard-only flows: `Tab`, `Shift-Tab`, `Enter`, `Space`, `Escape`, arrow keys, and native text shortcuts inside inputs.
- Try actions while menus, drawers, modals, drag operations, and background refresh loops are active.
- Try rapid repeated clicks on Build, Run, Install, Save, icon import, workspace import, release install, and destructive actions.
- Try narrow desktop widths, long paths, long project titles, and missing icons; controls must remain visible and fit-to-content unless a full-width field is intentional.
- Try stale app state: missing workspace, deleted app subpath, changed `site.conf`, absent bridge, missing optional tool, or failed backend command.
- Try drag/drop payload variants: URI list, plain text path, file payload, unsupported text, internal row drags, and leaving the window mid-drag.
- Try malformed image data URLs, empty decoded images, unsupported image types, and missing original icon sources.
- Try theme changes and refresh/focus regain during pending commands so repaint does not hide errors or reset selection.

## GUI QA Contract
- Use Safari/WebKit automation for GUI changes because WebKit layout, drag/drop, focus, and compositing differ from generic browser assumptions.
- Check initial paint, splash handoff, focus-visible states, hover states, menus, drawers, scroll tracks, and split-pane behavior.
- Verify invalid input is rejected before backend side effects and the user-facing message states what happened.
- Verify failed backend commands preserve selection, form values, scroll context, and durable status/log context.
- Verify no routine control becomes full-width or oversized when adversarial text is present.

## Regression Patterns
- Prefer backend shell tests for command contracts and static UI contract tests for required controls/semantics.
- Use temp workspaces, fake homes, fake bins, and stubbed tools to keep tests realistic without touching user state.
- Assert both failure message and absence of side effects, especially outside sibling paths or install roots.
- For eval-printing helpers, evaluate the success output with quote-bearing paths and assert no injected command runs.
- For create/edit parity bugs, test the edit path that bypassed create-time validation.
- For release/API bugs, stub network tools and feed hostile metadata before any real network access.
- For GUI-only regressions, pair a static contract test with a Safari automation note or screenshot stored outside the repo.

## Current Wizardry Apps Lessons
- Site names, workspace slugs, release asset names, and store IDs are path-like even when they look like labels.
- Site names that become service units, launchd labels, Tor blocks, process matches, or security users need the same strict validator as create/configure paths.
- A create path having validation does not prove rename/edit/import paths share the same contract.
- Hand-edited service config values such as Tor hidden-service ports must be revalidated before rendering daemon config, even if the normal edit command validates them.
- Domains read from site config must be revalidated before certbot, certificate path construction, nginx rendering, or GUI/status output.
- Site-user config values need user-name validation before user/group creation, ownership changes, sudo re-exec, or daemon User/UserName rendering.
- Allowlist files that drive recursive ownership or permission changes must reject root, web-root ancestors, non-directories, and other overly broad paths on both write and read.
- Imported path values passed through `sh -c` must be supplied as argv or environment values, never interpolated into the shell program string.
- Template-create paths write both filesystem paths and profile metadata; use the same site/template validators as blank-create paths.
- Profile fields later used in shell, XML, desktop files, API URLs, or filesystem paths need validation at the write boundary and fallback at the read boundary.
- Site config paths such as `cgi-dir` are code-generation inputs when they render into nginx directives.
- Legacy/imported site directories can bypass create-time rules; maintenance spells must revalidate site names before Tor or nginx matching.
- Release automation should reject unsafe metadata before invoking credentials, curl, xcrun, tar, unzip, chmod, or platform installers.
- Release helper scripts must revalidate manifest fields they print, even when CI normally runs the manifest validator first.
- Generated asset directories should be treated as partial unless each expected file exists; avoid all-or-nothing globs under `set -e`.
- Platform icon staging must verify generated icon sets are complete before copying them; partial generated directories should fall back or fail loudly.
- GUI adversarial testing should include stale state, racing clicks, WebKit drag payload differences, and narrow-width layout pressure.
- Native desktop IR display strings are code-generation inputs; validate or escape them before rendering Swift, C, plist, desktop, or package files.
- Backend text records consumed by GUIs need record-shape tests: line-break rejection alone does not protect tab- or pipe-separated output.
- Validators that print `key=value` summaries must validate or sanitize the file paths they echo, not only the structured data being validated.
- TSV list rows need tab-specific sanitization; key/value sanitizers that only replace CR/LF are not enough for sidebar/catalog rows.
- Installed helper output is GUI input when backend rows forward it; sanitize record delimiters in status/details text and reject delimiter-shaped module or action filenames before emitting rows.
- GUI list/count commands must share the same name validator as run commands; otherwise unsafe files can create visible but un-runnable rows or inflated category counts.
- Hand-edited user metadata files can bypass create-time GUI/backend validation; list/import paths must reapply delimiter and identifier contracts before emitting GUI rows.
- Workspace profile fields are imported metadata; sanitize every field before printing profile `key=value` rows, not only the fields that are validated for write actions.
- GUI preference/config readers must not `cat` hand-edited files back to the bridge; parse valid keys and sanitize values just like the writer.
- Starter templates need the same preference/config import checks as first-party apps, or new projects will regenerate fixed bug classes.
- Fallback/cache readers that emit tab-delimited GUI rows must reject unsafe filenames and tab/CR/LF-bearing contents even when the primary writer already validates them.
- Imported logs are GUI state too; list/tail commands should re-check row shape and strip CR before emitting historical rows.
- Helper list commands are GUI input; filter helper TSV output for exact column count and CR before forwarding rows.
- GUI bridge refs should reject unsupported namespaces and extra tokens before listing or running backend actions.
- URL-shaped bridge inputs are still output fields; reject CR/LF before echoing them as `key=value` rows.
- Environment-derived status fields such as shell, cwd, platform, and helper-detected labels are hostile output values when echoed in `key=value` rows.
- Diagnostic commands such as `doctor` are GUI/backend contracts too; sanitize env and path fields there the same way as action results.
- Terminal-launch helpers that print `command=...` rows should sanitize CR/LF in the displayed command, even when the underlying argv/script path remains valid for execution.
- Rebuild/run helpers that print configured shell commands or log paths must sanitize those status fields; a successful command can hide CR/LF inside shell comments and still forge GUI rows.
- Git accepts newline-bearing remote URLs, so Forge status rows must sanitize remotes before deriving browser URLs, GitHub slugs, or release checks.
- Sync/import helpers are release tools: test missing sources, source=target, dotfile copies, and local-only host directory preservation before relying on workflow automation.
- Sync/import helpers that print `key=value` rows must reject line-break paths before echoing canonical source or target paths.
- Icon metadata is project state, not host state; store project-relative paths and test that regeneration will not read absolute paths outside the project.
- Manifest validation should include hostile records added by future commits, not just the currently checked-in happy path.
- Single-record manifest status commands must sanitize manifest fields as output too; a separate validator does not protect GUI calls that read a hand-edited manifest directly.
- Optional app/template download paths must revalidate manifest source subdirs at runtime, because a hand-edited manifest can bypass CI validation and reach catalog cache replacement.
- Release upload helpers should adversarially test each credential field, not just the credential field used in a temp filename.
- Release version strings are project-file inputs; validate them before rendering Xcode, Gradle, plist, YAML, or package metadata.
- Remote API IDs, versions, and states need revalidation after `jq` extraction before reuse in URLs or machine-readable status rows.
- Remote API tokens should be revalidated after parsing before they are used in HTTP headers.
- Service account JSON is release input; validate identity fields before rendering JWT claims.
- Deploy and notarization secrets should reject control/path metacharacters before reaching remote-shell, codesign, or notarytool arguments.
- Icon generators emit backend rows and metadata files, so input/project paths and stored extensions must be output-safe before generation starts.
- File-artifact builders that print `key=value` status rows should reject line-break output paths and constrain output suffixes before writing.
- Icon staging should preflight every required output before copying so missing fallbacks cannot leave stale platform assets in place.
- Installer paths rendered into shell shims or desktop files must reject shell-expansion characters unless they are structurally escaped.
- Bundle IDs rendered into plist or native project files need direct validation at each packaging entrypoint, not just manifest-derived paths.
- Backend status paths derived from XDG or environment values must be sanitized even when the command only writes a preference file.
- Root hints are GUI/backend inputs even when output is plain text; reject line breaks before fallback resolution.
- Launcher root paths persisted for later app starts must reject line breaks before writing config files.
- Install/uninstall helpers that accept explicit replacement or removal paths must constrain them to the artifact type they own before `rm -rf`.
- Build helpers that accept explicit artifact output paths must constrain them to the artifact type they own before replacing the destination.
