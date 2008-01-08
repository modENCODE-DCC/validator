package ModENCODE::Chado::ExperimentProp;

use strict;
use Class::Std;
use Carp qw(croak);

# Attributes
my %value            :ATTR( :name<value>,               :default<''> );
my %rank             :ATTR( :name<rank>,                :default<0> );

# Relationships
my %type             :ATTR( :get<type>,                 :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $type = $args->{'type'};
  if (defined($type)) {
    $self->set_type($type);
  }
}

sub set_type {
  my ($self, $type) = @_;
  ($type->isa('ModENCODE::Chado::CVTerm')) or croak("Can't add a " . ref($type) . " as a type.");
  $type{ident $self} = $type;
}

sub to_string {
  my ($self) = @_;
  my $string;
  $string .= $self->get_rank() . ":" if (defined($self->get_rank()));
  $string .= $self->get_type()->to_string() . "=" if $self->get_type();
  $string .= "'" . $self->get_value() . "'";
  return $string;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::ExperimentProp({
      'value' => $self->get_value(),
      'rank' => $self->get_rank(),
    });
  $clone->set_type($self->get_type()->clone());
  return $clone;
}

1;
