# Wizardry Apps Rolling Audit Results

## Round 1
- Date: 2026-06-11
- Scope: built-in shipped app surfaces in `apps/`: `forge`, `wizardry-desktop`, `chatroom`
- Basis: `README.md`, Wizardry core audit docs, `.github/AI_DOCS.md`, `.github/WIZARDRY_APPS_ETHOS.md`, `.github/WIZARDRY_APPS_GUI_STANDARDS.md`, `.github/GUI_AUDIT.md`, `.github/adversarial-testing.md`, `.github/RELEASE_POLISH.md`

## Repo-Wide Language Inventory
- Primary app/runtime/orchestration surfaces remain shell, HTML, CSS, and JavaScript.
- Native host boundary files present:
  - `apps/.host/android/app/src/main/java/com/wizardry/apps/host/MainActivity.kt`
  - `apps/.host/ios/Host/WizardryHostApp.swift`
  - `apps/.host/ios/Host/WizardryWebView.swift`
  - `apps/.host/macos/main.m`
- Python helper present:
  - `tools/check-gh-issue.py`
- Cargo/Rust runtime inventory: none found in first-pass scope; no `Cargo.toml` surfaced in repo-owned runtime/app layers.
- Verdict:
  - `apps/.host` native files are acceptable as boundary-owned host machinery, consistent with `.github/AI_DOCS.md`.
  - `tools/check-gh-issue.py` is a real language exception and should stay on the explicit exception ledger in future rounds instead of remaining implicit.

## Cross-App Criteria Added This Round
- Passive reads and refreshes must not mutate durable prefs.
- Built-in app settings should live inside the main shell rather than a second settings document iframe.
- Fallback UX should avoid `alert()` and imperative send-away language.
- Endpoint and machine-state discovery should come through backend contracts, not direct frontend scraping of generic CGI/debug surfaces.
- Every shipped GUI app needs both backend and UI/static contract coverage.

## App Results

### App: forge
- Pass: yes
- Summary:
  - First-pass audit found no material standards drift.
  - Forge matches the current shell-first, backend-pref, autosave, keyboard, and regression-test posture expected for a flagship Wizardry app.
- Evidence:
  - Theme picker, settings shell, and bounded control patterns: `apps/forge/index.html:29-101`, `apps/forge/index.html:159-168`
  - Autosave workspace-profile contract: `apps/forge/index.html:254-264`
  - Backend-pref hydration and persistence: `apps/forge/index.html:620-650`
  - Theme picker keyboard behavior: `apps/forge/index.html:9347-9360`
  - Regression/UI test coverage: `.tests/apps/test-forge-ui-regressions.sh`, `.tests/apps/test-forge-backend.sh`, `.tests/apps/test-forge-release-install-adversarial.sh`, `.tests/apps/test-no-hardcoded-localhost-port.sh`
- Follow-up:
  - Recheck on round 2 against any new language-exception or read-path criteria discovered elsewhere.

### App: wizardry-desktop
- Pass: yes
- Summary:
  - First-pass audit found no material standards drift.
  - Wizardry Desktop is aligned with the listbox semantics, backend-pref persistence, theme keyboard support, and contract-test posture expected by the current standards.
- Evidence:
  - Semantic listbox navigation shell: `apps/wizardry-desktop/index.html:16-33`, `apps/wizardry-desktop/index.html:2054-2066`
  - Backend-pref persistence and theme hydration: `apps/wizardry-desktop/index.html:1769-1935`
  - Escape and arrow-key theme behavior: `apps/wizardry-desktop/index.html:3923-3940`
  - UI/backend test coverage: `.tests/apps/test-wizardry-desktop-ui-contract.sh`, `.tests/apps/test-wizardry-desktop-backend-contract.sh`, `.tests/apps/test-wizardry-desktop-menus-interactions-contract.sh`
- Follow-up:
  - Recheck on round 2 against any new language-exception or read-path criteria discovered elsewhere.

### App: chatroom
- Pass: no
- Severity: high
- Findings:
  - Resolved in fix-it pass: settings now live in the main shell, no separate `settings.html` document remains, and Chatroom has UI/static contract coverage.
  - Resolved in fix-it pass: frontend `sh -c` fallback execution was removed from Chatroom bridge calls.
  - Resolved in fix-it pass: passive endpoint reads no longer write durable prefs; `chat_url` is written only through explicit write/start-server paths.
  - Resolved in fix-it pass: generic `/cgi/system-info` scraping was replaced by the backend `get-network-info` contract.
  - Demo-site coupling is too hardcoded for a shipped built-in app. Backend logic is anchored to `$HOME/sites/demo` and `web-wizardry create demo`, which makes desktop behavior depend on one specific hosted-site instance rather than an app-owned contract.
  - Remaining: frontend-derived backend path detection is still open under the later host-owned backend-resolution standard.
- Evidence:
  - Integrated shell and settings panel: `apps/chatroom/index.html`
  - Backend-owned prefs plus network-info contract: `apps/chatroom/scripts/chatroom-backend.sh`
  - UI/static regression coverage: `.tests/apps/test-chatroom-ui-contract.sh`
  - Hardcoded demo-site architecture: `apps/chatroom/scripts/chatroom-backend.sh:58-122`
- Follow-up:
  - Move backend path resolution into a host-owned contract.
  - Replace demo-site coupling with an app-owned chatroom runtime contract.

## Recommended Round 2 Order
1. Re-audit `forge` and `wizardry-desktop` against the new read-path and language-exception criteria.
2. Modernize `chatroom` to current shell/settings/bridge standards.
3. Re-run the full pass so the round-1 learned criteria apply uniformly to every shipped app.

## Round 2 Partial
- Date: 2026-06-13
- Scope: focused re-audit of built-in theme surfaces against the newly added theme criteria

### App: forge
- Pass: yes
- Summary:
  - Forge still passes under the stricter theme audit.
  - It sources themes from the real shared Wizardry theme directories, normalizes and alphabetizes the list, and supports closed-picker arrow-key cycling.
- Evidence:
  - backend theme discovery from shared theme roots: `apps/forge/scripts/forge-backend.sh:2810-2833`
  - frontend normalization and alphabetical sorting: `apps/forge/index.html:2967-3006`
  - backend-loaded theme list and active-theme inclusion: `apps/forge/index.html:3008-3037`
  - closed-picker arrow-key cycling: `apps/forge/index.html:9348-9367`
- Follow-up:
  - Recheck later only if shared theme contracts or App Forge shell theming change materially.

### App: wizardry-desktop
- Pass: no
- Severity: medium
- Findings:
  - Theme source contract is only partially aligned. The app does query `list-themes`, but it still carries a hardcoded fallback theme catalog in the frontend instead of treating the shared Wizardry theme set as the sole source of truth.
  - The hardcoded fallback theme list is not alphabetized.
  - Closed-picker arrow-key cycling is missing. Arrow-key cycling is implemented only while the theme menu is already open, not when the theme picker button is focused and closed.
- Evidence:
  - backend theme discovery is correctly shared and alphabetized: `apps/wizardry-desktop/scripts/wizardry-desktop-backend.sh:292-312`
  - frontend hardcoded fallback list: `apps/wizardry-desktop/index.html:1795-1802`
  - backend-loaded list does not normalize/sort again in the frontend: `apps/wizardry-desktop/index.html:1804-1818`
  - open-menu-only arrow-key cycling: `apps/wizardry-desktop/index.html:3923-3940`, `apps/wizardry-desktop/index.html:4655-4672`
- Follow-up:
  - Remove the hardcoded fallback catalog, keep the shared theme contract authoritative, and add focused closed-picker arrow-key handling on the theme button itself.

## Round 2 Backend-Resolution Back-Application
- Date: 2026-06-13
- Scope: built-in shipped app surfaces checked against the late `frontend-derived-backend-path`, `bridge-shell-fragment-execution`, and `cargo-runtime-layer-present` criteria.

### App: forge
- Pass: no
- Severity: medium
- Findings:
  - Forge derives its backend script path from `window.location.pathname` through `inferAppDir()`, then executes `state.appDir + '/scripts/forge-backend.sh'` from the frontend bridge.
  - This is not a shell-fragment violation because the argv remains explicit, but it does violate the newer host-owned backend-resolution standard.
  - No Cargo-managed shipped runtime layer surfaced in the built-in Forge app path.
- Evidence:
  - frontend path inference: `apps/forge/index.html:588-590`
  - backend path construction: `apps/forge/index.html:1234-1236`
  - bridge argv construction: `apps/forge/index.html:1576-1586`
- Follow-up:
  - Move backend resolution behind a stable host/backend contract so Forge frontend code calls actions without constructing executable paths.

### App: wizardry-desktop
- Pass: no
- Severity: high
- Findings:
  - Wizardry Desktop derives backend script candidates from `window.location.pathname`, mutates root hints from those paths, and executes the selected script path from frontend bridge code.
  - It also retains a `sh -c` fallback for backend resolution, so the built-in app now fails both backend-resolution and shell-fragment criteria.
  - No Cargo-managed shipped runtime layer surfaced in the built-in Wizardry Desktop app path.
- Evidence:
  - frontend backend candidate detection: `apps/wizardry-desktop/index.html:320-354`
  - root hint inference from frontend-owned paths: `apps/wizardry-desktop/index.html:361-394`
  - frontend bridge execution of derived path: `apps/wizardry-desktop/index.html:415-440`
  - `sh -c` fallback: `apps/wizardry-desktop/index.html:451-458`
- Follow-up:
  - Replace frontend candidate detection and `sh -c` fallback with a host/backend-owned action contract.

### App: chatroom
- Pass: no
- Severity: high
- Findings:
  - Resolved in fix-it pass: Chatroom no longer uses `sh -c` fallback bridge execution.
  - Under the late backend-resolution criterion, it still fails because `index.html` derives backend script candidates from `window.location.pathname`.
  - No Cargo-managed shipped runtime layer surfaced in the built-in Chatroom app path.
- Evidence:
  - frontend backend candidate detection in main shell: `apps/chatroom/index.html`
  - explicit argv bridge execution with no shell fragment fallback: `apps/chatroom/index.html`
- Follow-up:
  - Move backend resolution into host-owned app actions rather than frontend path inference.
