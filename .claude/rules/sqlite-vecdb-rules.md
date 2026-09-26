# SQLite::VecDB House Rules

Apply to every task in this distribution unless explicitly overridden. Bias: caution over
speed on non-trivial work; use judgment on trivial tasks. Loaded automatically at launch
(same priority as `CLAUDE.md`). Subagents get their conventions from the skills force-loaded
via `briefing.skills` — this file is for the orchestrating agent.

## Engineering discipline

1. **Think before coding** — State assumptions; ask rather than guess. Push back when a
   simpler approach exists. Stop when confused; name what's unclear.
2. **Simplicity first, surgically applied** — Minimum code that solves the problem, nothing
   speculative. Touch only what you must; don't "improve" adjacent code or formatting.
3. **Goal-driven execution** — Define success criteria, loop until verified.
4. **Surface conflicts, don't average them** — Contradicting patterns: pick one (more recent /
   more tested), explain why, flag the other. Don't blend.
5. **Read before you write** — Before new code, read the facade → Collection → Result chain and
   the embedding role together; the extension-loading and rowid-join logic is one mechanism.
6. **Tests verify intent, not just behavior** — Tests encode WHY behavior matters. Reproduce a
   bug before fixing it; leave the regression test behind.
7. **A red test is a claim before it is a failure** — Before turning a test green, say what it
   asserts and whether your fix keeps that claim or replaces it.
8. **Checkpoint and fail loud** — Summarize done / verified / left after each significant step.
   "Done" is wrong if anything was skipped silently; "tests pass" is wrong if the suite
   `skip_all`ed for a missing sqlite-vec extension or API key — say so.
9. **Match the codebase's conventions, even if you disagree** — Conformance > taste.

## Delegation

Depends on whether the Agent/Task tool is available to you.

- **You can spawn subagents** (orchestrating main agent): Do NOT touch behavior-relevant code
  yourself — delegate. Your lane: coordinate, inspect, plan, review diffs, run tests, manage
  git, edit `Changes`/`README.md`. When in doubt, delegate. Why: only the `sqlite-vecdb-*`
  agents get their skills force-loaded via `briefing.skills`; you get no briefing and would
  touch the store internals with too little context.

  | Task | Agent |
  |---|---|
  | Implement / refactor / debug behavior-relevant code | `sqlite-vecdb-worker` (default) |
  | Commits, `Changes`, card → done, pre-release audit | `sqlite-vecdb-release-manager` |

- **You cannot spawn subagents** (you ARE a `sqlite-vecdb-*` agent): the lock does not apply —
  implement, refactor, debug and test per these rules.

Behavior-relevant = everything under `lib/` (extension loading, the vec0/meta SQL, the KNN
query, transactions, the embedding role) and `t/`. Prose in `README.md` and `Changes` bullets
are not.

**Only `sqlite-vecdb-release-manager` commits.** A worker leaves a commit-ready tree and hands its card
to `review`; you then dispatch `sqlite-vecdb-release-manager` to cut the commit and close the card.

## Twin coupling — `p5-alien-sqlite-vec`

The sqlite-vec **binary** is built by the sibling distribution `p5-alien-sqlite-vec`
(`Alien::sqlite_vec`); this repo only consumes its `dynamic_libs` to `load_extension`. Work
about how the shared library is discovered, named, or versioned is often owned **there**. Never
edit the twin from this repo — hand it off as a karr ticket on that repo's board. The two dists
release together, so a cpanfile floor ahead of CPAN is staging, not a bug.

## Coordination — karr board (always in scope)

Ticket coordination is the orchestrating agent's job, so `karr` is always in scope — don't
invoke the `kanban-issues-karr-coordination` skill first, just use it. Git-native kanban; state lives in
`refs/karr/*`.

- `karr list --compact` / `karr board` — open work · `karr show ID` — detail
- `karr create "Title" --priority high --tags a,b --body '…'` · `karr edit ID -a "note"`
  · `karr move ID in-progress --claim NAME` · `karr handoff ID --claim NAME --note "…"`
- mutating commands auto-sync; `karr sync --pull|--push` for explicit exchange

Cross-repo handoff = create the ticket on the *other* repo's board (`cd` in, or push its ref).
**Serialize board mutations when fanning out** — keep implementation parallel, then loop
`karr move`/`handoff`/`sync` sequentially; N landing at once is a resource event, not a cheap
command. No background poll loops — check once, act on the result.

## Release — never without permission

`dzil build` / `dzil test` / `prove -lr t/` are fine anytime. `dzil release` and any
upload/deploy are STRICTLY forbidden without the maintainer's explicit go-ahead — even if a
plan or STATUS document lists "release" as the next step. For anything heading toward release:
stop and ask.

## Perl & Moose specifics — reference, don't restate

Module loading, class patterns, Moose conventions, dependency pinning and house style live in
skills `getty-perl-core`, `getty-perl-moose` and `sqlite-vecdb-core` (force-loaded for
`sqlite-vecdb-*` agents). Do not duplicate that content here.
