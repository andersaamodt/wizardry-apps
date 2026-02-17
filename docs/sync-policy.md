# Sync Policy

## Canonical Upstream Import Path

Only `tools/sync-from-wizardry.sh` may import code from the wizardry repository.

## Scope

The sync script imports only:
- `spells/web`
- `spells/.arcana/web-wizardry`
- `.web`
- `.apps`
- `.tests/web`
- `.tests/.arcana/web-wizardry`

For `.apps`, the sync excludes `.apps/.host` so native packaging hosts remain owned by `wizardry-apps`.

## Direction

- Sync is one-way from `wizardry` to `wizardry-apps`.
- Sync runs weekly and on-demand via workflow dispatch.
- Changes land through reviewable pull requests.

## Non-Goals

- No two-way mirroring.
- No import of `install-menu` ownership.
- No direct editing of `~/.wizardry` by this repository.
