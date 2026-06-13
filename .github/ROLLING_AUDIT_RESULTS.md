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
  - Stale pre-standards GUI shell. The app still uses a generic gradient banner, inline styles, emoji heading treatment, anchor `onclick` tabs, and a separate settings document instead of the integrated shell/settings patterns required by Wizardry Apps standards.
  - Imperative and alert-driven fallback UX. The app tells the user to start the server from Settings and uses `alert()` fallback instructions for start, stop, and copy failures instead of durable guided state.
  - Execution boundary violation. Both `index.html` and `settings.html` fall back to `window.wizardry.exec(['sh', '-c', ...])`, which breaks the hardcoded-argv boundary.
  - Read path mutates durable state. `loadPort()` writes `chat_url` prefs during passive status loading, which violates the “reads remain non-mutating” ethos and is now a rolling-audit criterion.
  - Frontend scrapes generic CGI for machine state. `settings.html` pulls `/cgi/system-info` directly to infer IP and Tor state instead of using a dedicated backend contract.
  - Demo-site coupling is too hardcoded for a shipped built-in app. Backend logic is anchored to `$HOME/sites/demo` and `web-wizardry create demo`, which makes desktop behavior depend on one specific hosted-site instance rather than an app-owned contract.
  - Test coverage is thin relative to shipped GUI scope. Chatroom has backend coverage, but no matching UI/static contract tests surfaced in the shipped app test set.
- Evidence:
  - Old shell and non-semantic tabs: `apps/chatroom/index.html:7-77`
  - Separate settings document iframe: `apps/chatroom/index.html:79-81`, `apps/chatroom/index.html:260-276`
  - `sh -c` fallback execution: `apps/chatroom/index.html:138-174`, `apps/chatroom/settings.html:287-325`
  - Imperative/alert-driven fallback UX: `apps/chatroom/index.html:68-76`, `apps/chatroom/settings.html:475-499`, `apps/chatroom/settings.html:520-532`, `apps/chatroom/settings.html:649-660`
  - Read-path writes and CGI scraping: `apps/chatroom/settings.html:391-417`, `apps/chatroom/settings.html:544-640`
  - Hardcoded demo-site architecture: `apps/chatroom/scripts/chatroom-backend.sh:58-122`
  - Test gap: `.tests/apps/test-chatroom-backend.sh`
- Follow-up:
  - Rebuild Chatroom onto the current Wizardry Apps shell patterns before doing polish-only fixes.
  - Add UI/static contract coverage once the shell is modernized.

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
