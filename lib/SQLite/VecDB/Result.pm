package SQLite::VecDB::Result;
# ABSTRACT: Search result from SQLite::VecDB
our $VERSION = '0.001';

use Moose;

use overload '""' => sub { $_[0]->id }, fallback => 1;

has id => (
  is => 'ro',
  isa => 'Str',
  required => 1,
);

=attr id

The unique identifier of the stored vector.

=cut

has distance => (
  is => 'ro',
  isa => 'Num',
);

=attr distance

The distance from the query vector. Lower means more similar.
The scale depends on the distance metric (cosine: 0..2, l2: 0..inf).

=cut

has metadata => (
  is => 'ro',
  isa => 'HashRef',
  default => sub { {} },
);

=attr metadata

The metadata HashRef stored with this vector.

=cut

has content => (
  is => 'ro',
  isa => 'Str',
  predicate => 'has_content',
);

=attr content

The original text content, if stored.

=cut

has vector => (
  is => 'ro',
  isa => 'ArrayRef[Num]',
  predicate => 'has_vector',
);

=attr vector

The stored vector, if requested.

=cut

__PACKAGE__->meta->make_immutable;

1;

=synopsis

  my @results = $collection->search(vector => [...], limit => 5);

  for my $r (@results) {
    say $r->id;          # 'doc1'
    say $r->distance;    # 0.042
    say $r->metadata;    # { title => 'Hello' }
    say $r->content;     # 'Original text...'
    say "$r";            # 'doc1' (stringifies to id)
  }

=description

Immutable result object returned by L<SQLite::VecDB::Collection/search>.
Stringifies to C<id>.

=cut
