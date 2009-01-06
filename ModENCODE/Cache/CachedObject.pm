package ModENCODE::Cache::CachedObject;

use strict;
use Class::Std;

my %content      :ATTR( :name<content> );

sub START {
  my ($self, $ident, $args) = @_;
  use Carp qw(confess);
  confess "WTF, no object to cache" unless $self->get_content;
  confess "Should never build a CachedObject with an ID" unless ref($self->get_content);
}

sub get_id {
  my $self = shift;
  return ref($self->get_content) ? $self->get_content->get_id : $self->get_content;
}

sub shrink {
  my $self = shift;
  if (ref($self->get_content)) {
    $self->get_content->save;
    $self->set_content($self->get_content->get_id);
    return 1;
  }
  return 0;
}

sub get_object {
  my $self = shift;
  if (!ref($self->get_content)) {
    $self->uncompress;
  }
  return $self->get_content;
}

1;
