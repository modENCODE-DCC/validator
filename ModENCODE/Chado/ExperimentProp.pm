package ModENCODE::Chado::ExperimentProp;

use strict;
use Class::Std;
use Carp qw(croak);

# Attributes
my %name             :ATTR( :name<name> );
my %value            :ATTR( :name<value>,               :default<''> );
my %rank             :ATTR( :name<rank>,                :default<0> );

# Relationships
my %termsource       :ATTR( :get<termsource>,           :default<undef> );
my %type             :ATTR( :get<type>,                 :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $termsource = $args->{'termsource'};
  if (defined($termsource)) {
    $self->set_termsource($termsource);
  }
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

sub set_termsource {
  my ($self, $this_termsource) = @_;
  ($this_termsource->isa('ModENCODE::Chado::DBXref')) or croak("Can't add a " . ref($this_termsource) . " as a termsource.");
  $termsource{ident $self} = $this_termsource;
}

sub to_string {
  my ($self) = @_;
  my $string;
  $string .= $self->get_rank() . ":" if (defined($self->get_rank()));
  $string .= $self->get_name() if $self->get_name();
  $string .= "<" . $self->get_type()->to_string() . ">" if $self->get_type();
  $string .= $self->get_termsource()->to_string() if $self->get_termsource();
  $string .= "='" . $self->get_value() . "'";
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name() && $self->get_value() eq $other->get_value() && $self->get_rank() eq $other->get_rank());

  if ($self->get_termsource()) {
    return 0 unless $other->get_termsource();
    return 0 unless $self->get_termsource()->equals($other->get_termsource());
  } else {
    return 0 if $other->get_termsource();
  }

  if ($self->get_type()) {
    return 0 unless $other->get_type();
    return 0 unless $self->get_type()->equals($other->get_type());
  } else {
    return 0 if $other->get_type();
  }

  return 1;
}



sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::ExperimentProp({
      'name' => $self->get_name(),
      'value' => $self->get_value(),
      'rank' => $self->get_rank(),
    });
  $clone->set_type($self->get_type()->clone()) if $self->get_type();
  $clone->set_termsource($self->get_termsource()->clone()) if $self->get_termsource();
  return $clone;
}

1;
