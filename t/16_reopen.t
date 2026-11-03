#!/usr/bin/env perl
use Test2::V0;
use File::Temp qw( tempdir );

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

my $probe = eval { SQLite::VecDB->new(db_file => ':memory:', dimensions => 3) };
skip_all "sqlite-vec not available: $@" unless $probe;
eval { $probe->dbh };
skip_all "sqlite-vec not available: $@" if $@;

my $file = tempdir(CLEANUP => 1).'/reopen.db';

{
  my $vdb = SQLite::VecDB->new(db_file => $file, dimensions => 3, distance_metric => 'l2');
  $vdb->collection('docs')->add(id => 'a', vector => [1, 0, 0]);
}

# A stored collection is the truth: reopening it with other settings must not
# quietly reinterpret its vectors.
like dies {
  SQLite::VecDB->new(db_file => $file, dimensions => 4, distance_metric => 'l2')->collection('docs');
}, qr/docs.*dimensions.*3.*4|docs.*dimensions.*4.*3/s,
  'reopening with other dimensions croaks naming both values';

like dies {
  SQLite::VecDB->new(db_file => $file, dimensions => 3)->collection('docs');
}, qr/docs.*distance_metric.*l2.*cosine|docs.*distance_metric.*cosine.*l2/s,
  'reopening with the default metric croaks naming both values';

my $same = SQLite::VecDB->new(db_file => $file, dimensions => 3, distance_metric => 'l2');
my $coll;
ok lives { $coll = $same->collection('docs') }, 'reopening with matching settings works';
is $coll->count, 1, 'reopened collection keeps its data';

done_testing;
