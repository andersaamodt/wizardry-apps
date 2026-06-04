# Governed Work Kernel

The Governed Work Kernel is the external durable work-record kernel used by
Wizardry-family governed execution paths.

It is installed as a separately licensed AGPL-3.0-or-later upstream workspace.
Wizardry, Forge, and Artificer call it across a process/file boundary and do
not vendor, link, or copy its Rust crates into OWL-licensed code.

## Install

```sh
spells/.arcana/governed-work-kernel/install-governed-work-kernel
```

The installer stores source under:

```text
${XDG_DATA_HOME:-~/.local/share}/wizardry-apps/governed-work-kernel/source
```

It installs this wrapper into `XDG_BIN_HOME`, a user-writable PATH directory
such as `~/.cargo/bin`, or `~/.local/bin` as a fallback:

```text
governed-work-kernel
```

## Check

```sh
spells/.arcana/governed-work-kernel/check-governed-work-kernel
governed-work-kernel status
governed-work-kernel check
```

## License Boundary

- Wizardry and Forge remain under OWL 3.1.
- The external kernel source remains AGPL-3.0-or-later.
- The wrapper is Wizardry-owned POSIX shell glue.
- Integration must stay at CLI/files/JSON boundaries.
- Do not vendor or link the upstream Rust crates into OWL-licensed projects.
