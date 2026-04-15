# Architecture

## Boundaries

- `wizardry` is canonical for POSIX CLI orchestration.
- `wizardry-apps` is canonical for app packaging, UI, runtime adapters, and distribution.

## Runtime Model

- Hosted web remains shell/CGI reference semantics.
- Desktop/mobile use embedded `wizardry-core` for fast-path operations.
- `App Forge` (`apps/forge`) is the desktop control-plane app for build/run/scaffold workflows, implemented as WebView UI + POSIX shell backend.
- Forge can scaffold three workspace contexts in-repo: cross-platform web (`web`), native desktop IR (`native-desktop`), and Godot (`godot`).
- Native desktop workspaces keep canonical UI in `ir/app.ir.yaml` and regenerate platform source into standard macOS and GTK/Linux project trees.
- Core API contract is transport-agnostic JSON-RPC 2.0.
- Core v1 methods implemented in repository:
  - `core.ping`, `vault.mount`, `vault.info`
  - `doc.list`, `doc.read`, `doc.write`, `doc.delete`
  - `meta.get`, `meta.set`, `meta.unset`
  - `txn.begin`, `txn.commit`, `txn.rollback`

## Storage Model

- Markdown files remain canonical content source.
- POSIX xattrs are canonical metadata where supported.
- Mobile fallback uses sidecar `*.xattr.json` with equivalent semantics.

## Event Model

- Best-effort live event stream.
- No durable replay in v1.
- Event names include: `cardUpdated`, `tagSetChanged`, `txnCommitted`, `docChanged`, `vaultMounted`.

## Transport Adapters

- Desktop/mobile: JS bridge callbacks inside WebView.
- Hosted web: HTTP adapter + SSE stream for events.

## Release Model

- Tag-triggered build matrix.
- Protected approval gate before publishing.
- macOS notarization required for release.
- Mobile publication stages to TestFlight and Play internal first.
