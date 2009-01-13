package ModENCODE::Chado::FeatureProp;

use strict;
use Class::Std;
use Carp qw(carp croak);

# Attributes
my %value            :ATTR( :name<value>,                               :default<undef> );
my %rank             :ATTR( :name<rank>,                                :default<undef> );

# Relationships
my %type             :ATTR(                     :init_arg<type> );

sub get_type_id {
  my $self = shift;
  return $type{ident $self} ? $type{ident $self}->get_id : undef;
}

sub get_type {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $type = $type{ident $self};
  return undef unless defined $type;
  return $get_cached_object ? $type{ident $self}->get_object : $type{ident $self};
}

sub set_type {
  my ($self, $type) = @_;
  ($type->get_object->isa('ModENCODE::Chado::CVTerm')) or Carp::confess("Can't add a " . ref($type) . " as a type.");
  $type{ident $self} = $type;
}


1;
