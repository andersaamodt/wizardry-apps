# Phronesis Extraction Plan

## Status
- Migration status: complete for the pass-2 standards baseline.
- Canonical repository: `/Users/andersaamodt/git/phronesis`
- Remote: `git@github.com:andersaamodt/phronesis.git`

## Canonical Homes
- Standards: `/Users/andersaamodt/git/phronesis/standards/`
- Decisions: `/Users/andersaamodt/git/phronesis/decisions/README.md`
- Audit method: `/Users/andersaamodt/git/phronesis/audits/`
- Policy matrix schema: `/Users/andersaamodt/git/phronesis/policies/policy-matrix-schema.yaml`
- Repo-local AI docs template: `/Users/andersaamodt/git/phronesis/templates/repo-ai-docs.md`
- Exception schema: `/Users/andersaamodt/git/phronesis/exceptions/README.md`
- Canonical `.gitignore`: `/Users/andersaamodt/git/phronesis/standards/repo-hygiene/wizardry-general.gitignore`

## What Stays In wizardry-apps
- Forge, templates, app hosts, bridges, build/release machinery, and app implementation detail.
- App-specific audit evidence and affected-app lists.
- Built-in app scope and wizardry-apps validation commands.
- Local exception instances and local pending fix-it notes.

## Rule
- New ecosystem-wide policy goes to `phronesis`.
- This repo may specialize policy only for wizardry-apps implementation detail, and the specialization must be documented locally.
