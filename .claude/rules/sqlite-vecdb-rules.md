# SQLite::VecDB House Rules

The shared house rules come from skilletor — bundle `getty-cpan-dist@getty`: engineering
discipline, the delegation lock, the publish gate, karr coordination, CPAN release. They load
as `.claude/rules/.local.*.md`; if they are missing, run `skilletor sync` and publish nothing
until they load. This file adds what is true only here, and wins where it differs.

## What this repo is

SQLite as a vector database using sqlite-vec. Read first: the facade → Collection → Result
chain and the embedding role together; the extension-loading and rowid-join logic is one
mechanism.

## Agent team

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code | `sqlite-vecdb-worker` (default) |
| Commits, `Changes`, card → done, pre-release audit | `sqlite-vecdb-release-manager` |
| Read-only research, audit, gap analysis | `sqlite-vecdb-worker` ("read-only, change nothing") |

Behavior-relevant = everything under `lib/` (extension loading, the vec0/meta SQL, the KNN
query, transactions, the embedding role) and `t/`. Prose in `README.md` and `Changes` bullets
are not.

## Twin coupling — `p5-alien-sqlite-vec`

The sqlite-vec **binary** is built by the sibling distribution `p5-alien-sqlite-vec`
(`Alien::sqlite_vec`); this repo only consumes its `dynamic_libs` to `load_extension`. Work
about how the shared library is discovered, named, or versioned is often owned **there**. Never
edit the twin from this repo — hand it off as a karr ticket on that repo's board (`cd` in, or
push its ref). The two dists release together, so a cpanfile floor ahead of CPAN is staging,
not a bug.

## Hazards

- **The suite can `skip_all` into a green run** — "tests pass" is wrong if it skipped for a
  missing sqlite-vec extension or API key; say so.

## Perl & Moose specifics — reference, don't restate

Module loading, class patterns, Moose conventions, dependency pinning and house style live in
skills `getty-perl-core`, `getty-perl-moose` and `sqlite-vecdb-core` (force-loaded for
`sqlite-vecdb-*` agents).
