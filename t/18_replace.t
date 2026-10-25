use Test2::V0;

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

my $vdb = eval { SQLite::VecDB->new(db_file => ':memory:', dimensions => 3) };
skip_all "sqlite-vec not available: $@" unless $vdb;

my $coll = $vdb->collection('replace');
$coll->add(id => 'doc', vector => [1, 0, 0], metadata => { v => 1 }, content => 'old');
$coll->add(id => 'other', vector => [0, 0, 1]);

like dies { $coll->add(id => 'doc', vector => [0, 1, 0]) },
  qr/Failed to add/, 'plain add of an existing id still croaks';

is $coll->add(id => 'doc', vector => [0, 1, 0], metadata => { v => 2 }, replace => 1),
  'doc', 'replace returns the id';
is $coll->count, 2, 'replace does not grow the collection';

my $r = $coll->get(id => 'doc', include_vectors => 1);
is $r->metadata, { v => 2 }, 'replace rewrote the metadata';
ok !$r->has_content, 'replace rewrote the content (not carried over)';
is $r->vector, [0, 1, 0], 'replace rewrote the vector';

my ($nearest) = $coll->search(vector => [0, 1, 0], limit => 1);
is $nearest->id, 'doc', 'search sees the new vector';
my @old = $coll->search(vector => [1, 0, 0], limit => 5);
is [ map { $_->id } grep { $_->distance < 0.01 } @old ], [], 'nothing is left at the old vector';

# Atomic: a failing replace keeps the stored entry.
like dies { $coll->add(id => 'doc', vector => [0, 1], replace => 1) },
  qr/3 dimensions/, 'replace with a wrong vector croaks';
is $coll->get(id => 'doc', include_vectors => 1)->vector, [0, 1, 0],
  'the stored entry survives a rejected replace';

ok lives { $coll->add(id => 'fresh', vector => [1, 1, 0], replace => 1) },
  'replace of an unknown id just adds it';
is $coll->count, 3, 'fresh id was added';

# Inside the caller's transaction the replace stays undoable.
my $dbh = $vdb->dbh;
$dbh->begin_work;
$coll->add(id => 'doc', vector => [0, 0, 1], replace => 1);
$dbh->rollback;
is $coll->get(id => 'doc', include_vectors => 1)->vector, [0, 1, 0],
  'the caller\'s rollback restores the replaced entry';

done_testing;
