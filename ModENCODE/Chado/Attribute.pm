package ModENCODE::Chado::Attribute;

use strict;
use Class::Std;
use Carp qw(croak);


# Attributes
my %name             :ATTR( :name<name>,                :default<''> );
my %heading          :ATTR( :name<heading>,             :default<''> );
my %value            :ATTR( :name<value>,               :default<''> );
my %rank             :ATTR( :name<rank>,                :default<0> );

# Relationships
my %termsource       :ATTR( :get<termsource>,           :default<undef> );
my %type             :ATTR( :get<type>,                 :default<undef> );
my %organism         :ATTR( :get<organism>,             :default<undef> );

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
  my $organism = $args->{'organism'};
  if (defined($organism)) {
    $self->set_organism($organism);
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

sub set_organism {
  my ($self, $organism) = @_;
  ($organism->isa('ModENCODE::Chado::Organism')) or Carp::confess("Can't add a " . ref($organism) . " as an organism.");
  $organism{ident $self} = $organism;
}

sub to_string {
  my ($self) = @_;
  my $string = $self->get_heading() . "[" . $self->get_name() . "]";
  $string .= $self->get_type()->to_string() if $self->get_type();
  $string .= $self->get_termsource->to_string() if $self->get_termsource();
  $string .= "='" . $self->get_value() . "'";
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name() && $self->get_heading() eq $other->get_heading()&& $self->get_value() eq $other->get_value());

  if ($self->get_termsource()) {
    return 0 unless $other->get_termsource();
    return 0 unless $self->get_termsource()->equals($other->get_termsource());
  }
  if ($self->get_type()) {
    return 0 unless $other->get_type();
    return 0 unless $self->get_type()->equals($other->get_type());
  }
  if ($self->get_organism()) {
    return 0 unless $other->get_organism();
    return 0 unless $self->get_organism()->equals($other->get_organism());
  }

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Attribute({
      'name' => $self->get_name(),
      'heading' => $self->get_heading(),
      'value' => $self->get_value(),
    });
  $clone->set_termsource($self->get_termsource()->clone()) if $self->get_termsource();
  $clone->set_type($self->get_type()->clone()) if $self->get_type();
  $clone->set_organism($self->get_organism()->clone()) if $self->get_organism();
  return $clone;
}

sub mimic {
  my ($self, $other) = @_;
  croak "Attribute " . $self->to_string() . " cannot mimic an object of type " . ref($other) if (ref($self) ne ref($other));
  $self->set_name($other->get_name());
  $self->set_heading($other->get_heading());
  $self->set_value($other->get_value());
  $self->set_rank($other->get_rank());

  $termsource{ident $self} = undef;
  $type{ident $self} = undef;
  $self->set_termsource($other->get_termsource()->clone()) if $other->get_termsource();
  $self->set_type($other->get_type()->clone()) if $other->get_type();
  $self->set_organism($other->get_organism()->clone()) if $other->get_organism();
}

1;
