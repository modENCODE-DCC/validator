package ModENCODE::Chado::CV;

use strict;
use Class::Std;
use Carp qw(croak);

# Attributes
my %name             :ATTR( :name<name>,                :default<''> );
my %definition       :ATTR( :name<definition>,          :default<''> );

sub to_string {
  my ($self) = @_;
  return $self->get_name();
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name() && $self->get_definition() eq $other->get_definition());

  return 1;
}

1;
