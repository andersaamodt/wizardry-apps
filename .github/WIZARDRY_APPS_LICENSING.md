# Wizardry Apps Licensing Policy (AI-Facing)

## Scope
- This file defines licensing and emission policy for `wizardry-apps`.
- Treat this file as the canonical AI-facing spec for scaffolded project licensing until root license files and Forge behavior are updated to match.
- Keep this file aligned with user-approved policy decisions from the thread that introduced it.

## Repo License Split
- `wizardry` itself remains under `OWL 3.0`.
- `wizardry-apps` as a repo remains under `OWL 3.0` by default.
- Built-in Wizardry apps in `apps/` remain under `OWL 3.0`.
- Forge itself remains under `OWL 3.0`.
- Only blank emitted projects created from generic starters switch to `AGPL-3.0-or-later` plus `Wizardry Addendum 1.0`.

## OWL 3.0 Draft
- Use this exact draft when creating or updating the root `OWL 3.0` text:

```text
 ,___,   OPEN WIZARDRY LICENSE 3.0
 (O,O)
 /)  )   Permission: You may use, copy,
="=="=   modify, and share this project for
non-commercial purposes, including private,
educational, research, and internal
organizational use.

Commercial Use: Commercial exploitation is
prohibited. "Commercial exploitation" means
sale, subscription, paid access, monetized
hosting, inclusion in any paid product or
service, or use as part of any monetized system,
even if not the primary component. Internal use
by commercial entities is allowed.

Name and Association: This license does not
grant permission to use the names "Wizardry"
or "Open Wizardry", or any project trade names,
trademarks, or service marks, except for
reasonable descriptive reference. Those names
may not be used in any way that implies
endorsement, sponsorship, official status, or
association for a modified version, fork,
product, or service.

Non-Coercion: Use of this project must not be
required in any institutional context.

Reciprocity: If you make a covered work
publicly available—either by distributing copies
or by operating a public-facing service that
uses it—you must make the complete corresponding
source for that covered work publicly available
under this license.

Covered Work: "Covered work" means this project
and any modified or derivative version of it.
Independent works that merely accompany it are
not covered.

Notice: This license must accompany any public
distribution of this project or its files.

Violation: Violation of any term of this
license voids the permissions granted herein
until set right.

Warranty: Provided without warranty or guarantee
of any kind.
```

## Emitted Project License
- Blank emitted projects are licensed under `AGPL-3.0-or-later`.
- Blank emitted projects also carry `Wizardry Addendum 1.0` as additional terms under `AGPL` section 7.
- The entire emitted app is covered by that generated-project license choice, not just the starter files.
- Emitted projects are meant to be sellable and hostable if they remain copyleft and comply with the addendum.
- SaaS copyleft is required for emitted projects.

## Wizardry Addendum 1.0 Draft
- Use this exact draft for emitted projects:

```text
Wizardry Addendum 1.0

Additional terms under GNU AGPL version 3,
section 7, apply to this project.

1. No permission is granted to use the names
"Wizardry" or "Open Wizardry", or any project
trade names, trademarks, or service marks,
except for reasonable descriptive reference.

2. Those names may not be used in advertising,
publicity, product naming, or public statements
in any way that misrepresents the origin of the
software or implies endorsement, sponsorship,
official status, or association.

3. Modified versions and derivative works must
not present themselves as the original Wizardry
project or as officially associated with it.

4. Truthful descriptive references are allowed,
including statements that a work was generated
with, built with, or adapted from Wizardry,
provided those statements do not imply
endorsement, sponsorship, official status,
or association.
```

## Starter Classification
- Blank generic starters must emit `AGPL-3.0-or-later` plus `Wizardry Addendum 1.0`.
- Built-in Wizardry apps and any starter that is really a Wizardry-owned app surface stay under `OWL 3.0`.
- Clone-based starters inherit the source project's license and must not be silently relicensed by Forge.
- Imported existing projects must not be silently relicensed by Forge.

## Planned Generic Starter Set
- Maintain a minimal blank starter.
- Add a blank starter built around a left sidebar layout.
- Add a blank starter built around a top menu bar plus main content region below it.
- Treat those generic starters as emission material for sellable non-Wizardry apps.
- Do not treat Wizardry-branded built-ins as sellable starter templates.

## Emission Material Rule
- Generic starter payloads that Forge copies into emitted projects are emission material.
- Shared runtime or bridge files that emitted projects require are emission material.
- Emission material must be usable under both repo-internal `OWL 3.0` use and emitted-project `AGPL` use.
- Implement emission material as dual-licensed `OWL 3.0 OR AGPL-3.0-or-later` when code changes are made.
- Built-in apps may rely on the `OWL` side of that dual license.
- Blank emitted projects may rely on the `AGPL` side of that dual license.

## Generated Project Files
- Blank emitted projects should receive a root `LICENSE` file containing `AGPL-3.0-or-later`.
- Blank emitted projects should receive a root `WIZARDRY_ADDENDUM.md` file containing `Wizardry Addendum 1.0`.
- Blank emitted projects should receive a default `README.md` created by the starter itself.
- The default generated README should include this short notice:

```text
This project is licensed under GNU AGPL-3.0-or-later.
Additional terms apply; see WIZARDRY_ADDENDUM.md.
```

## README Mutation Rules
- Prefer generating the README correctly up front instead of patching it afterward.
- Forge must never rewrite or patch an existing README in a project it did not just generate.
- Dropped folders, imported projects, and clone-based starters must not have their README mutated by Forge.
- Run/build/compile flows must not rewrite README files.
- If a generated project's README is later user-edited or deleted, Forge must leave it alone.

## Legal File Verification Rules
- For blank projects generated from generic starters, Forge may verify that `LICENSE` and `WIZARDRY_ADDENDUM.md` exist.
- If those machine-owned legal files are missing from a blank emitted project, Forge may restore them.
- Forge must not use legal-file verification as a reason to rewrite README files.
- Forge must not inject `AGPL` or addendum files into imported projects, built-in apps, or clone-based projects that are not blank emitted projects.
- Use project metadata such as `starter=` and project origin to decide whether verification/restoration applies.

## Operational Intent
- `OWL 3.0` keeps Wizardry itself non-commercial, non-coercive, and protected against false association.
- Emitted blank projects are intended for one-person and small-team app creation, but the emitted-project license must not add field-of-endeavor restrictions.
- The branding addendum exists to prevent false association and misrepresentation, not to ban truthful descriptive references.
- Agents must preserve this split when implementing Forge scaffolding, project verification, README generation, or future template work.
