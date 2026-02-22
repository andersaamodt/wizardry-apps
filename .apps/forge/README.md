# App Forge

App Forge is the flagship wizardry-apps desktop control plane.

It provides a native WebView UI backed by POSIX shell scripts for:
- building and running built-in wizardry apps
- staging assets for mobile hosts
- creating new workspaces through Create App (Application or Game project type)
- scaffolding hosted web sites from `.web` templates
- running core quality checks

The GUI is organized around two primary use-cases:
- App Pipeline: select app -> compile/run -> stage/publish checks
- Create App: project type -> starter -> platforms -> scaffold workspace
- Unified left app list: built-in and user-created apps together, with organize filters and per-row run action
- Settings panel (bottom-left gear): roots, diagnostics, bridge status, and global quality checks
- Activity panel (top-right icon): artifacts and command logs
- Theme picker (left footer): all bundled wizardry themes, persisted locally
- Projects are external by default under `~/git`, and only folders with `wizardry.workspace.conf` are shown as managed workspaces.

## Backend

The GUI calls:

- `.apps/forge/scripts/forge-backend.sh`

This backend is the CLI parity surface for all Forge actions.

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
sh .apps/forge/scripts/forge-backend.sh doctor /path/to/wizardry-apps

# Build and run a desktop app
sh .apps/forge/scripts/forge-backend.sh build-desktop /path/to/wizardry-apps artificer
sh .apps/forge/scripts/forge-backend.sh run-desktop /path/to/wizardry-apps artificer

# Scaffold a new app and a new site
sh .apps/forge/scripts/forge-backend.sh scaffold-app /path/to/wizardry-apps my-tool "My Tool" minimal
sh .apps/forge/scripts/forge-backend.sh scaffold-workspace /path/to/wizardry-apps my-tool "My Tool" web panel "hosted-web,macos,linux"
sh .apps/forge/scripts/forge-backend.sh scaffold-site /path/to/wizardry-apps my-site demo "$HOME/sites"
```
