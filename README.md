# wizardry-apps

wizardry-apps is the app-building companion to [wizardry](https://github.com/andersaamodt/wizardry).

Its main app is **App Forge**, a desktop tool for creating, running, installing, and publishing wizardry apps. Forge is meant for people who want the convenience of a GUI without hiding the files, scripts, and Git history that make an app understandable.

## What Forge Does

Forge helps you:
- create new app projects from starters
- run and rebuild apps while you work
- install wizardry apps locally
- import existing projects into your Forge app list
- manage project Git settings
- publish your own apps through GitHub-backed release flows

Forge keeps projects file-first. A generated app is an ordinary folder with source files, assets, metadata, and scripts that can be opened in an editor, committed to Git, and published from GitHub.

## Install And Run Forge

From this repository:

```sh
# Open the Forge menu
./forge-menu
```

The menu can install Forge, uninstall it, and run it after installation.

After installing Forge:
- macOS opens Forge as `App Forge.app` from `/Applications` or `~/Applications`
- Linux opens Forge as `App Forge` from the desktop menu, or with `~/.local/bin/app-forge`

On macOS, the installed Forge app is a normal app bundle with a Dock icon and menu bar behavior. On Linux, Forge installs a desktop launcher and local app files.

## App Types

Forge can scaffold several kinds of projects. You do not need to know every tool on day one, but it helps to understand what each target is made from.

**Cross-platform apps** use HTML, CSS, and JavaScript for the interface. They can run as hosted web apps and can also be wrapped in desktop or mobile WebView hosts. This is the most direct path for small tools, dashboards, control panels, and apps that should share one interface across platforms.

**Native desktop apps** start from a simple app description file, then generate platform-native code. macOS output uses Swift/SwiftUI. Linux output uses GTK. This path is for apps that should feel more like platform-owned desktop software, with native menus, windows, lists, settings, and file panels.

**Game projects** use Godot project scaffolding. This path is for interactive games or game-like tools where a dedicated game engine is a better fit than a document-style app UI.

**Hosted web sites** use wizardry web templates and shell-backed site tooling. This path is for sites and lightweight web surfaces that should remain easy to inspect and publish.

## Publishing

Forge expects publishing to happen through GitHub.

For your own app, Forge can help initialize or connect a Git repository, set an `origin`, switch branches, fetch, pull, push, and open GitHub URLs for the project. Release and install flows are built around GitHub-hosted repositories and release artifacts, so the path from "local app" to "shareable app" stays visible in Git.

Forge also supports installing wizardry apps from release artifacts when a supported macOS or Linux asset is available for the current machine.

## Built-In Apps And Your Apps

Forge shows built-in wizardry apps and your own managed projects in one app list.

Built-in apps come from this repository. Your apps usually live outside this repository, commonly under `~/git`, and Forge recognizes them by a `wizardry.workspace.conf` file in the project folder. You can create projects with Forge or drag an existing project folder into Forge to register it.

## Licensing

wizardry-apps, Forge itself, and built-in wizardry apps are licensed under `OWL 3.0`, which permits non-commercial use, copying, modification, and sharing.

Blank projects emitted from Forge's generic starters are different: they are generated under `AGPL-3.0-or-later` plus `Wizardry Addendum 1.0`. Those generated projects are intended to be sellable and hostable as long as the whole emitted app remains copyleft, complete corresponding source is made available, and the Wizardry name is not used in a way that implies endorsement or official status.

## Repository Map

The source tree is organized around apps, starters, hosts, release tools, and the shell-backed wizardry app pipeline:
- `apps/forge/` contains App Forge
- `apps/.host/` contains reusable desktop and mobile host wrappers
- `apps/<slug>/` contains built-in wizardry apps
- `templates/` contains Forge starters, shared web templates, and Godot material
- `runtime/config/` contains release and template configuration used by Forge and publishing tools
- `runtime/schemas/` contains app, RPC, event, metadata, and native desktop IR contracts
- `runtime/adapters/` contains shell and HTTP/CGI reference adapters
- `runtime/core/` contains wizardry-core code
- `assets/stock/` contains reusable stock icons and SVGs
- `spells/` contains wizardry app pipeline commands
- `tools/` contains validation, icon, sync, and release helpers
- `.github/` contains AI-facing standards and contributor policy

## For Contributors

This repository keeps one user-facing README: this file. App-specific implementation notes and agent guidance belong in `.github/`, not in nested README files.

For deeper implementation notes, read `.github/AI_DOCS.md` first.
