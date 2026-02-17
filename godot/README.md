# Godot Tooling

This folder tracks optional Godot-based Wizardry tools and desktop export pipeline assets.

v1 scope:
- desktop exports (macOS/Linux)
- CI export smoke with reproducible artifacts

## Project

- `tools/wizardry-lab/` contains a minimal Godot desktop tool project.
- `export-presets/export_presets.cfg` defines Linux/X11 and macOS release presets.

## Local Export

```sh
# Linux export
sh godot/scripts/export-godot-desktop.sh dist/godot linux

# macOS export
sh godot/scripts/export-godot-desktop.sh dist/godot macos
```

Requires a `godot4`/`godot` CLI binary and matching export templates.
