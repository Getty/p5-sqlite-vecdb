# SQLite::VecDB

SQLite as a vector database via [sqlite-vec](https://github.com/asg017/sqlite-vec): store
vectors with metadata, KNN search, and optional automatic embeddings through Langertha. Moose
distribution. The sqlite-vec **binary** comes from the twin distribution `p5-alien-sqlite-vec`
(`Alien::sqlite_vec`) — coupling and handoff rules are in `.claude/rules/sqlite-vecdb-rules.md`.

## Delegation

Delegate behavior-relevant code to the right agent instead of touching it yourself — the
principle and the lane split are in `.claude/rules/sqlite-vecdb-rules.md`.

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code (lib/, t/) | `sqlite-vecdb-worker` (default) |
| Commits, `Changes`, card → done, pre-release audit | `sqlite-vecdb-release-manager` |

The agents carry their skills via `briefing.skills` (see `.claude/agents/`); the main agent
delegates rather than loading them. Skill sources live under `.claude/skills/` — architecture
and invariants in `sqlite-vecdb-core`, house conventions in `getty-perl-core` /
`getty-perl-moose`, release in `getty-perl-release-author-getty` / `perl-release-dist-ini`,
coordination in `kanban-issues-karr-coordination`.
