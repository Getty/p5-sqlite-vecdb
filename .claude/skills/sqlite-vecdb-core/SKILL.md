---
name: sqlite-vecdb-core
description: "Load on any SQLite::VecDB edit — the sqlite-vec extension-loading chain, the vec0 + metadata two-table layout per collection, the KNN MATCH/k query shape, Result objects, and the optional Langertha embedding role. Architecture and invariants, not Perl style."
---

# SQLite::VecDB — architecture and invariants

`SQLite::VecDB` turns a plain SQLite database into a vector store by loading the
[sqlite-vec](https://github.com/asg017/sqlite-vec) extension at connect time. It
stores vectors with metadata, does KNN search, and — only when handed a
[Langertha](https://metacpan.org/pod/Langertha) engine — embeds text for you.
**Moose throughout** (object-system rules: `getty-perl-moose`; Perl house rules:
`getty-perl-core` — do not restate them here).

## The class mesh

| Class | Role |
|---|---|
| `SQLite::VecDB` | facade: owns the `dbh`, resolves the extension, hands out collections |
| `SQLite::VecDB::Collection` | one named collection; `add`/`search`/`get`/`delete`/`count`/`add_batch` |
| `SQLite::VecDB::Result` | immutable search/get result; `id`/`distance`/`metadata`/`content`/`vector`; stringifies to `id` |
| `SQLite::VecDB::Role::Embedding` | `add_text`/`search_text`; applied to a Collection *only* when an embedding engine is present |

`SQLite::VecDB->new` requires `db_file` (path or `:memory:`) and `dimensions`.
`distance_metric` defaults to `cosine` (sqlite-vec also supports `l2`, `l1`).

## The extension-loading chain — the load-bearing invariant

Nothing works until the sqlite-vec shared library is loaded into the handle. The
`dbh` is a **lazy builder**; `sqlite_vec_path` resolves in this fixed order:

1. explicit `sqlite_vec_path` attribute
2. `$ENV{SQLITE_VEC_PATH}`
3. `Alien::sqlite_vec->dynamic_libs` (first lib), `require`d lazily inside the builder

Then `_build_dbh` calls `sqlite_enable_load_extension(1)` and
`SELECT load_extension(?)` **before** any `vec0` table can be created. A missing
library `croak`s with "Cannot find sqlite-vec extension…". This lazy resolution
is why almost every test guards with `skip_all "sqlite-vec not available"` — the
failure only surfaces on first `dbh` use, not at `new`.

### Twin coupling — `Alien::sqlite_vec` lives in `p5-alien-sqlite-vec`

Step 3 above depends on the **sibling distribution `p5-alien-sqlite-vec`**
(`Alien::sqlite_vec`), which builds/vendors the actual sqlite-vec binary. This
repo consumes its `dynamic_libs`; it does not build the extension. A change to
how the library is discovered, named, or versioned is often **owned by the twin,
not here** — coordinate via a karr ticket on that repo's board, never a direct
edit. Everything downstream of `load_extension` (SQL, `MATCH`, `float[N]`) is
this repo's.

## Storage layout — two tables per collection

`_ensure_tables` (run in `BUILD`, idempotent, guarded by `_initialized`) creates,
per collection `$name`:

- **`vec_${name}`** — a `vec0` **virtual table**: `embedding float[$dims]
  distance_metric=$metric`. The `$dims` is baked into the schema, so the
  collection's dimension count is fixed at creation.
- **`meta_${name}`** — a plain table: `rowid` (PK), `id` (TEXT UNIQUE), `metadata`
  (JSON text), `content`, `created_at`.

A registry table `_vecdb_collections` (created in `_build_dbh`) records each
collection's name/dimensions/metric. `$vdb->collections` reads it. The `rowid` is
the join key between the two tables — `add` inserts the meta row first, takes
`last_insert_id`, then inserts the vector under that same rowid.

## Invariants an implementer must hold

- **Dimension check is explicit.** `add` `croak`s unless `@$vector ==
  $self->dimensions`. The `float[N]` schema will not save you — enforce it in Perl.
- **Vectors cross the boundary as JSON.** `encode_json($vector)` in, and the
  `embedding` bind for the vec0 insert uses `SQL_INTEGER` only on the `rowid`
  param — the vector param is the JSON string. Don't "simplify" the bind types.
- **Metadata round-trips through JSON** (`JSON::MaybeXS`); `undef` when absent, and
  a Result's `metadata` defaults to `{}`, never undef.
- **Writes are transactional but nestable.** `add`/`delete` open a transaction
  only when `$dbh->{AutoCommit}` is on (`$need_txn`); `add_batch` wraps the whole
  loop in one `begin_work`/`commit` and calls `add`, which then sees AutoCommit
  off and does *not* nest. Preserve that guard or batch adds will double-commit.

## The KNN query shape — sqlite-vec specifics

`search` is not ordinary SQL. The vec0 virtual table takes the query vector via
`WHERE v.embedding MATCH ?` **and** a `k = ?` constraint for the neighbor count
(`limit`, default 10), then `ORDER BY v.distance`, joined to `meta_${name}` on
rowid. Both `MATCH` and `k =` are required by sqlite-vec's KNN API — a plain
`ORDER BY distance LIMIT n` is not the same and will not use the index. `distance`
scale depends on the metric (cosine 0..2, l2 0..inf); lower = more similar.

## Optional embeddings — the dynamic role

`add_text`/`search_text` do **not** exist on a bare Collection. When
`SQLite::VecDB` is constructed with an `embedding` engine, the facade passes it
down and `Collection::BUILD` applies `SQLite::VecDB::Role::Embedding` to the
instance at runtime (`->meta->apply($self)`). The role `requires add search
embedding`, calls `$self->embedding->simple_embedding($text)` (the
`Langertha::Role::Embedding` interface) to get a vector, then delegates to the
plain `add`/`search`. `has_embedding` (predicate) is the gate everywhere.

Consequence for tests: an embedding engine is mockable by any object answering
`simple_embedding` and `does('Langertha::Role::Embedding')` — no API key needed
(see `t/40_langertha_integration.t`). Live tests gate on
`TEST_SQLITE_VECDB_OPENAI_API_KEY` and skip without it. Langertha is a `suggests`,
not a hard dependency — the core store works with raw vectors alone.
