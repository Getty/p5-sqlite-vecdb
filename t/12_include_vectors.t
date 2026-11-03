#!/usr/bin/env perl
use Test2::V0;

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

my $vdb = eval { SQLite::VecDB->new(db_file => ':memory:', dimensions => 3) };
skip_all "sqlite-vec not available: $@" unless $vdb;

my $coll = $vdb->collection('vectors');
$coll->add(id => 'a', vector => [1, 0, 0]);
$coll->add(id => 'b', vector => [0.5, 0.25, 0.125]);

# Without the option the vector stays absent: reading it back costs a lookup.
my ($plain) = $coll->search(vector => [1, 0, 0], limit => 1);
ok !$plain->has_vector, 'search does not load the vector by default';
ok !$coll->get(id => 'a')->has_vector, 'get does not load the vector by default';

my @hits = $coll->search(vector => [0.5, 0.25, 0.125], limit => 2, include_vectors => 1);
my ($b) = grep { $_->id eq 'b' } @hits;
ok $b->has_vector, 'search include_vectors populates the vector';
is $b->vector, [0.5, 0.25, 0.125], 'search returns the stored vector';

my $got = $coll->get(id => 'b', include_vectors => 1);
ok $got->has_vector, 'get include_vectors populates the vector';
is $got->vector, [0.5, 0.25, 0.125], 'get returns the stored vector';

done_testing;
