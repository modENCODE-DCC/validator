package ModENCODE::Chado::Data;

use strict;
use Class::Std;
use Carp qw(croak);


# Attributes
my %name             :ATTR( :name<name>,                :default<''> );
my %heading          :ATTR( :name<heading>,             :default<''> );
my %value            :ATTR( :name<value>,               :default<''> );
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );

# Relationships
my %attributes       :ATTR( :get<attributes>,           :default<[]> );
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
  my $attributes = $args->{'attributes'};
  if (defined($attributes)) {
    if (ref($attributes) ne 'ARRAY') {
      $attributes = [ $attributes ];
    }
    foreach my $attribute (@$attributes) {
      $self->add_attribute($attribute);
    }
  }
}


sub set_type {
  my ($self, $type) = @_;
  ($type->isa('ModENCODE::Chado::CVTerm')) or croak("Can't add a " . ref($type) . " as a type.");
  $type{ident $self} = $type;
}

sub set_termsource {
  my ($self, $termsource) = @_;
  ($termsource->isa('ModENCODE::Chado::DBXref')) or croak("Can't add a " . ref($termsource) . " as a termsource.");
  $termsource{ident $self} = $termsource;
}

sub add_attribute {
  my ($self, $attribute) = @_;
  ($attribute->isa('ModENCODE::Chado::Attribute')) or croak("Can't add a " . ref($attribute) . " as a attribute.");
  push @{$attributes{ident $self}}, $attribute;
}

sub to_string {
  my ($self) = @_;
  my $string = $self->get_heading();
  $string .= "['" . $self->get_name() . "']" if $self->get_name();
  $string .= $self->get_termsource()->to_string() if $self->get_termsource();
  if (scalar(@{$self->get_attributes()})) {
    $string .= "<";
    foreach my $attribute (@{$self->get_attributes()}) {
      $string .= $attribute->to_string();
    }
    $string .= ">";
  }
  $string .= $self->get_type()->to_string() if $self->get_type();
  $string .= "=" . $self->get_value();
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name() && $self->get_heading() eq $other->get_heading()&& $self->get_value() eq $other->get_value());

  my @attributes = @{$self->get_attributes()};
  return 0 unless scalar(@attributes) == scalar(@{$other->get_attributes()});
  foreach my $attribute (@attributes) {
    return 0 unless scalar(grep { $_->equals($attribute) } @{$other->get_attributes()});
  }

  if ($self->get_termsource()) {
    return 0 unless $other->get_termsource();
    return 0 unless $self->get_termsource()->equals($other->get_termsource());
  }
  if ($self->get_type()) {
    return 0 unless $other->get_type();
    return 0 unless $self->get_type()->equals($other->get_type());
  }

  return 1;
}

1;
