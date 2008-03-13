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
my %organisms        :ATTR( :get<organisms>,            :default<[]> );

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
  my $organisms = $args->{'organisms'};
  if (defined($organisms)) {
    if (ref($organisms) ne 'ARRAY') {
      $organisms = [ $organisms ];
    }
    foreach my $organism (@$organisms) {
      $self->add_organism($organism);
    }
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

sub add_organism {
  my ($self, $organism) = @_;
  ($organism->isa('ModENCODE::Chado::Organism')) or croak("Can't add a " . ref($organism) . " as an organism.");
  push @{$organisms{ident $self}}, $organism;
}

sub set_organisms {
  my ($self, $organisms) = @_;
  $organisms{ident $self} = [];
  foreach my $organism (@$organisms) {
    $self->add_organism($organism);
  }
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
  } else {
    return 0 if $other->get_termsource();
  }

  if ($self->get_type()) {
    return 0 unless $other->get_type();
    return 0 unless $self->get_type()->equals($other->get_type());
  } else {
    return 0 if $other->get_type();
  }

  my @organisms = @{$self->get_organisms()};
  return 0 unless scalar(@organisms) == scalar(@{$other->get_organisms()});
  foreach my $organism (@organisms) {
    return 0 unless scalar(grep { $_->equals($organism) } @{$other->get_organisms()});
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
  foreach my $organism (@{$self->get_organisms()}) {
    $clone->add_organism($organism->clone());
  }
  return $clone;
}

1;
