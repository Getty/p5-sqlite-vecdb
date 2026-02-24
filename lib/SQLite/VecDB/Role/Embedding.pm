package SQLite::VecDB::Role::Embedding;
# ABSTRACT: Langertha embedding integration for SQLite::VecDB collections
our $VERSION = '0.002';

use Moose::Role;
use Carp qw( croak );

requires qw( add search embedding );

sub add_text {
  my ( $self, %args ) = @_;
  my $text = delete $args{text} // croak "text is required";
  my $vector = $self->embedding->simple_embedding($text);
  return $self->add(
    %args,
    vector  => $vector,
    content => $args{content} // $text,
  );
}

=method add_text

  $coll->add_text(
    id   => 'doc1',
    text => 'Some text to embed and store.',
  );

Generates an embedding for C<text> using the configured Langertha engine,
then stores the vector. The text is also saved as C<content> unless you
provide your own C<content> value.

=cut

sub search_text {
  my ( $self, %args ) = @_;
  my $text = delete $args{text} // croak "text is required";
  my $vector = $self->embedding->simple_embedding($text);
  return $self->search(
    %args,
    vector => $vector,
  );
}

=method search_text

  my @results = $coll->search_text(
    text  => 'search query',
    limit => 10,
  );

Generates an embedding for the query C<text>, then performs KNN search.

=cut

1;

=synopsis

  # Applied automatically when SQLite::VecDB has an embedding engine:
  use SQLite::VecDB;
  use Langertha::Engine::Ollama;

  my $vdb = SQLite::VecDB->new(
    db_file    => 'vectors.db',
    dimensions => 768,
    embedding  => Langertha::Engine::Ollama->new(
      url             => 'http://localhost:11434',
      embedding_model => 'nomic-embed-text',
    ),
  );

  my $coll = $vdb->collection('docs');
  $coll->add_text(id => 'doc1', text => 'Some text to embed and store.');
  my @results = $coll->search_text(text => 'search query', limit => 5);

=description

This role is automatically applied to L<SQLite::VecDB::Collection> instances
when the parent L<SQLite::VecDB> has an C<embedding> engine set. It adds
C<add_text> and C<search_text> methods that use L<Langertha::Role::Embedding>
to generate vectors from text automatically.

=cut
