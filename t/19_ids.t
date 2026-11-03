#!/usr/bin/env perl
use Test2::V0;

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

my $vdb = eval { SQLite::VecDB->new(db_file => ':memory:', dimensions => 3) };
skip_all "sqlite-vec not available: $@" unless $vdb;

my $coll = $vdb->collection('ids');
is [ $coll->ids ], [], 'empty collection has no ids';

$coll->add(id => 'b', vector => [1, 0, 0]);
$coll->add(id => 'a', vector => [0, 1, 0]);
$coll->add(id => 'c', vector => [0, 0, 1]);
is [ $coll->ids ], [qw( b a c )], 'ids come back in insertion order';

$coll->delete(id => 'a');
is [ $coll->ids ], [qw( b c )], 'deleted ids are gone';

my $other = $vdb->collection('ids_other');
$other->add(id => 'z', vector => [1, 1, 1]);
is [ $coll->ids ], [qw( b c )], 'ids are per collection';

done_testing;
