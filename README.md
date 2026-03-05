# wizardry-apps

wizardry-apps is the dedicated repository for Wizardry application surfaces outside the canonical POSIX CLI suite.

This repository owns:
- hosted web templates and packaging
- desktop WebView hosts (macOS + Linux)
- mobile WebView hosts (iOS + Android)
- wizardry-core runtime contracts and implementation
- release pipelines for app distribution

The `wizardry` repository remains canonical for POSIX shell orchestration and spell implementations.

## Design Stance

wizardry-apps follows wizardry ethos:
- POSIX-first orchestration where shell is the reference semantics
- file-first data model (Markdown + filesystem metadata)
- low-to-the-ground implementation with minimal moving parts
- explicit behavior and compatibility-first command UX

## Repository Highlights

- `spells/web` and `spells/.arcana/web-wizardry` are migrated from `~/.wizardry`
- `spells/.arcana/wizardry-apps` provides the top-level app pipeline arcana and menus
- `web` templates are migrated from `~/.wizardry/web`
- `apps` desktop app surfaces are migrated from `~/.wizardry/apps`
- manifests in `config/` define production release allowlists
- contracts in `schemas/` define RPC/events/metadata formats
- CI workflows in `.github/workflows/` implement lint/test/build/release gates

## Assumptions

- The canonical `wizardry` CLI suite is installed (default: `~/.wizardry`)
- desktop/mobile correctness does not require CLI availability
- CLI-backed operations are optional and explicit

## Local Setup

```sh
# Validate manifests
sh tools/validate-manifest.sh

# Run core tests
sh core/tests/test_core.sh

# Run adapter tests
sh .tests/adapters/test-http-cgi.sh
sh .tests/adapters/test-shell-parity.sh
sh .tests/adapters/test-core-shell-parity.sh
sh .tests/adapters/test-bridge-contract.sh
sh .tests/adapters/test-bridge-behavior.sh

# Run wizardry-apps arcana tests
for t in .tests/.arcana/wizardry-apps/test-*.sh; do
  sh "$t"
done

# Run flagship desktop app tests
for t in .tests/apps/test-*.sh; do
  sh "$t"
done
```

## App Arcana Menus

```sh
# Open top-level apps arcana menu
spells/.arcana/wizardry-apps/wizardry-apps

# Open web/desktop/mobile admin submenus directly
spells/.arcana/wizardry-apps/wizardry-apps web-admin
spells/.arcana/wizardry-apps/wizardry-apps desktop-admin
spells/.arcana/wizardry-apps/wizardry-apps mobile-admin
```

## Flagship Desktop App

```sh
# App Forge (desktop control plane)
# Download-and-run from this repository:
./run-forge

# Install user-local app launcher integration (macOS/Linux):
./install-forge

# macOS options:
# force /Applications install
./install-forge --system
# force ~/Applications install
./install-forge --user

# Remove launcher integration:
./uninstall-forge

# Inspect backend directly:
sh apps/forge/scripts/forge-backend.sh --help
```

After `./install-forge`:
- macOS: launch `/Applications/App Forge.app` (falls back to `~/Applications` if needed)
- Linux: launch `App Forge` from your desktop app menu (or run `~/.local/bin/app-forge`)

The macOS app bundle is first-class:
- embedded native host binary
- Dock/Finder icon resource
- proper Dock + menu-bar app behavior

## Mobile Build Helpers

```sh
# Stage app assets for native hosts
sh tools/release/stage-web-assets.sh artificer apps/.host/android/app/src/main/assets

# iOS simulator smoke artifact
sh tools/release/build-ios-app.sh artificer dist/ios smoke
```

## Sync Policy

Use `tools/sync-from-wizardry.sh` for all upstream imports from `~/.wizardry`.
No other import path is considered canonical.
The sync preserves local `apps/.host` ownership for native desktop/mobile hosts.
