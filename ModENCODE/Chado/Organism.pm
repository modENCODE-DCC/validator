package ModENCODE::Chado::Organism;

use strict;
use Class::Std;

# Attributes
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );
my %genus            :ATTR( :name<genus>,               :default<undef> );
my %species          :ATTR( :name<species>,             :default<undef> );

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_genus() eq $other->get_genus() && $self->get_species() eq $other->get_species());

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Organism({
      'chadoxml_id' => $self->get_chadoxml_id(),
      'genus' => $self->get_genus(),
      'species' => $self->get_species(),
    });
  return $clone;
}

sub to_string {
  my ($self) = @_;
  return $self->get_genus() . " " . $self->get_species();
}

1;
