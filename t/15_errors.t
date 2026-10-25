use Test2::V0;

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

my $vdb = eval { SQLite::VecDB->new(db_file => ':memory:', dimensions => 3) };
skip_all "sqlite-vec not available: $@" unless $vdb;

my $coll = $vdb->collection('errors');

# --- Missing required arguments ---

like dies { $coll->add(vector => [1,0,0]) },
  qr/id is required/, 'add without id croaks';

like dies { $coll->add(id => 'x') },
  qr/vector is required/, 'add without vector croaks';

like dies { $coll->search() },
  qr/vector is required/, 'search without vector croaks';

like dies { $coll->get() },
  qr/id is required/, 'get without id croaks';

like dies { $coll->delete() },
  qr/id is required/, 'delete without id croaks';

# --- Wrong vector dimensions ---

like dies { $coll->add(id => 'x', vector => [1,0]) },
  qr/3 dimensions/, 'add with too few dimensions croaks';

like dies { $coll->add(id => 'x', vector => [1,0,0,0]) },
  qr/3 dimensions/, 'add with too many dimensions croaks';

# --- Duplicate IDs ---

$coll->add(id => 'dup', vector => [1,0,0]);
is $coll->count, 1, 'first add succeeds';

like dies { $coll->add(id => 'dup', vector => [0,1,0]) },
  qr/Failed to add/, 'duplicate id croaks';

is $coll->count, 1, 'count unchanged after duplicate id error (rollback works)';

# Verify original is still intact
my $r = $coll->get(id => 'dup');
ok $r, 'original vector still accessible after duplicate error';

# --- Delete then search ---

$coll->add(id => 'a', vector => [0.9, 0.1, 0.0]);
$coll->add(id => 'b', vector => [0.0, 0.9, 0.1]);
$coll->add(id => 'c', vector => [0.0, 0.1, 0.9]);
is $coll->count, 4, 'four vectors total';

my @before = $coll->search(vector => [1.0, 0.0, 0.0], limit => 10);
my %ids_before = map { $_->id => 1 } @before;
ok $ids_before{a}, 'vector a found in search before delete';

$coll->delete(id => 'a');
is $coll->count, 3, 'count 3 after delete';

my @after = $coll->search(vector => [1.0, 0.0, 0.0], limit => 10);
my %ids_after = map { $_->id => 1 } @after;
ok !$ids_after{a}, 'deleted vector a is gone from search results';
ok $ids_after{b}, 'vector b still in results';
ok $ids_after{c}, 'vector c still in results';

# --- Batch add with failure (duplicate) rolls back entirely ---

my $coll2 = $vdb->collection('batch_errors');
$coll2->add(id => 'existing', vector => [1,0,0]);
is $coll2->count, 1, 'pre-existing vector for batch test';

like dies {
  $coll2->add_batch(
    { id => 'new1', vector => [0,1,0] },
    { id => 'existing', vector => [0,0,1] },  # duplicate!
    { id => 'new2', vector => [0.5,0.5,0] },
  );
}, qr/Batch add failed/, 'batch with duplicate croaks';

is $coll2->count, 1, 'batch rolled back entirely — count still 1';
ok !$coll2->get(id => 'new1'), 'new1 was rolled back';

# --- Batch inside the caller's transaction joins it ---

my $coll3 = $vdb->collection('batch_outer');
my $dbh   = $vdb->dbh;

$dbh->begin_work;
is $coll3->add_batch(
  { id => 'x', vector => [1,0,0] },
  { id => 'y', vector => [0,1,0] },
), 2, 'add_batch inside an outer transaction succeeds';
ok !$dbh->{AutoCommit}, 'add_batch did not commit the caller\'s transaction';
$dbh->rollback;
is $coll3->count, 0, 'the caller\'s rollback undoes the batch';

$dbh->begin_work;
$coll3->add(id => 'keep', vector => [1,0,0]);
like dies { $coll3->add_batch({ id => 'keep', vector => [0,1,0] }) },
  qr/Batch add failed/, 'failing batch inside an outer transaction croaks';
ok !$dbh->{AutoCommit}, 'failing batch did not end the caller\'s transaction';
$dbh->commit;
is $coll3->count, 1, 'the caller\'s earlier work survives the failed batch';

# --- Names and metrics are validated before any SQL runs ---

my $evil = 'x" USING vec0(embedding float[3]); DROP TABLE "meta_errors"; --';
like dies { $vdb->collection($evil) },
  qr/Invalid collection name/, 'name with quote and SQL croaks';
like dies { $vdb->collection('has space') },
  qr/Invalid collection name/, 'name with a space croaks';
like dies { $vdb->collection('') },
  qr/Invalid collection name/, 'empty name croaks';
ok !(grep { $_ eq $evil } $vdb->collections),
  'rejected name left no registry row behind';

my $bad_metric = SQLite::VecDB->new(
  db_file => ':memory:', dimensions => 3, distance_metric => 'cosnie',
);
like dies { $bad_metric->collection('typo') },
  qr/Invalid distance_metric 'cosnie'/, 'unknown distance_metric croaks';
is [ $bad_metric->collections ], [], 'rejected metric left no registry row behind';

for my $metric (qw( cosine l2 l1 )) {
  my $ok = SQLite::VecDB->new(
    db_file => ':memory:', dimensions => 3, distance_metric => $metric,
  );
  ok lives { $ok->collection('fine_1') }, "metric $metric is accepted";
}

done_testing;
