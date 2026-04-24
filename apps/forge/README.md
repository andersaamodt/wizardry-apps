# App Forge

App Forge is the flagship wizardry-apps desktop control plane.

It provides a native WebView UI backed by POSIX shell scripts for:
- building and running built-in wizardry apps
- staging assets for mobile hosts
- creating new workspaces through Create App (Cross-Platform App, Native Desktop App, or Game project type)
- emitting blank app workspaces under `AGPL-3.0-or-later` plus `Wizardry Addendum 1.0`
- scaffolding hosted web sites from `web` templates
- running core quality checks

The GUI is organized around two primary use-cases:
- App Pipeline: select app -> compile/run -> stage/publish checks
- Create App: project type -> starter -> platforms -> scaffold workspace
- Cross-platform starters: minimal, Wizardry Desktop Reference App, control panel, left sidebar, top bar + graph, dashboard, and studio
- Native desktop starter: blank IR-driven native desktop scaffold with macOS and Linux renderer outputs
- Unified left app list: built-in and user-created apps together, with organize filters and per-row run action
- Drag-and-drop import: drop a project folder onto Forge to register it into the left list
- Settings panel (bottom-left gear): roots, diagnostics, bridge status, and global quality checks
- Settings panel icon tooling: ImageMagick install/uninstall helpers plus a persisted "Make squircle when dropping icon" toggle
- Activity panel (top-right icon): artifacts and command logs
- Theme picker (left footer): all bundled wizardry themes, persisted locally
- Projects are external by default under `~/git`, and only folders with `wizardry.workspace.conf` are shown as managed workspaces.
- Workspace `Run` now executes `run_rebuild_command` from `wizardry.workspace.conf` first when that field is set; use `run_rebuild_command=:` for workspaces that do not need a pre-run rebuild step.
- Workspace selections in the right pane include a structured `Workspace settings` section for validated edits to supported `wizardry.workspace.conf` fields.
- Workspace rows can show a compact Git status pill (`Check Git`, `Sync`, `Push`, `Update`, `Current`) when the project folder is connected to a git repo.
- Workspace selections in the right pane include a `Git` section for repo initialization, `origin` URL updates, branch switching, fetch/pull/push flows, GitHub PR links, and latest-release installs when a supported asset exists for the current host.
- Native desktop workspaces keep their canonical UI in `ir/app.ir.yaml` as JSON-compatible YAML and regenerate platform source into `generated/macos` and `generated/linux`.

## Backend

The GUI calls:

- `apps/forge/scripts/forge-backend.sh`

This backend is the CLI parity surface for all Forge actions.

Forge stores transient Git cache/release-install state outside the repo under:
- `${XDG_STATE_HOME:-$HOME/.local/state}/wizardry-apps/forge/git`

Dropped icons are now normalized into platform asset sets under `assets/icons/` when
ImageMagick is available, including:
- `assets/icons/macos/forge.icns`
- `assets/icons/linux/<size>x<size>/forge-icon.png`
- `assets/icons/android/mipmap-*/ic_launcher.png`
- `assets/icons/ios/AppIcon.appiconset/*`
- `assets/icons/web/icon-*.png`

## Launch And Install

From repository root:

```sh
# Run immediately from checkout
./run-forge

# Install user-local launchers/integration
./install-forge

# macOS:
# install to /Applications (default)
./install-forge --system
# install to ~/Applications
./install-forge --user

# Remove launchers/integration
./uninstall-forge
```

After install:
- macOS: open `/Applications/App Forge.app` (falls back to `~/Applications` when needed)
- Linux: open `App Forge` from the desktop menu, or run `~/.local/bin/app-forge`

macOS install is a real app bundle with:
- native host binary embedded in the `.app`
- Finder/Dock icon via `.icns` resource wiring
- normal Dock association and menu bar behavior

If the repository is moved, rerun `./install-forge`.

Forge resolves `wizardry-apps` root using this order:
- explicit root passed to backend commands
- `WIZARDRY_APPS_ROOT`
- app-bundle pointer file (`wizardry-apps-root.txt`)
- user config file (`~/.config/wizardry-apps/forge-root`)
- upward search from script path/current directory

## Direct CLI usage

```sh
# Inspect workspace + tool availability
sh apps/forge/scripts/forge-backend.sh doctor /path/to/wizardry-apps

# Build and run a desktop app
sh apps/forge/scripts/forge-backend.sh build-desktop /path/to/wizardry-apps artificer
sh apps/forge/scripts/forge-backend.sh run-desktop /path/to/wizardry-apps artificer

# Scaffold a new app and a new site
sh apps/forge/scripts/forge-backend.sh scaffold-app /path/to/wizardry-apps my-tool "My Tool" minimal
sh apps/forge/scripts/forge-backend.sh scaffold-app /path/to/wizardry-apps reference-tool "Reference Tool" reference-app
sh apps/forge/scripts/forge-backend.sh scaffold-workspace /path/to/wizardry-apps my-tool "My Tool" web sidebar "hosted-web,macos,linux"
sh apps/forge/scripts/forge-backend.sh scaffold-workspace /path/to/wizardry-apps my-native-tool "My Native Tool" native-desktop blank "macos,linux"
sh apps/forge/scripts/forge-backend.sh scaffold-site /path/to/wizardry-apps my-site demo "$HOME/sites"

# Import an existing project folder into Forge's managed project list
sh apps/forge/scripts/forge-backend.sh import-workspace /path/to/wizardry-apps /path/to/existing/project "$HOME/git"
```
