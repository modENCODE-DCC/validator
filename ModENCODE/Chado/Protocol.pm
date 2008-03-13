package ModENCODE::Chado::Protocol;

use strict;
use Class::Std;
use Carp qw(croak);


# Attributes
my %name             :ATTR( :name<name>,                :default<''> );
my %version          :ATTR( :name<version>,             :default<undef> );
my %description      :ATTR( :name<description>,         :default<''> );
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );

# Relationships
my %attributes       :ATTR( :get<attributes>,           :default<[]> );
my %termsource       :ATTR( :get<termsource>,           :default<undef> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $attributes = $args->{'attributes'};
  if (defined($attributes)) {
    if (ref($attributes) ne 'ARRAY') {
      $attributes = [ $attributes ];
    }
    foreach my $attribute (@$attributes) {
      $self->add_attribute($attribute);
    }
  }
  my $termsource = $args->{'termsource'};
  if (defined($termsource)) {
    $self->set_termsource($termsource);
  }
}

sub add_attribute {
  my ($self, $attribute) = @_;
  ($attribute->isa('ModENCODE::Chado::Attribute')) or croak("Can't add a " . ref($attribute) . " as a attribute.");
  push @{$attributes{ident $self}}, $attribute;
}

sub set_attributes {
  my ($self, $attributes) = @_;
  $attributes{ident $self} = [];
  foreach my $attribute (@$attributes) {
    $self->add_attribute($attribute);
  }
}

sub set_termsource {
  my ($self, $termsource) = @_;
  ($termsource->isa('ModENCODE::Chado::DBXref')) or croak("Can't add a " . ref($termsource) . " as a termsource.");
  $termsource{ident $self} = $termsource;
}

sub to_string {
  my ($self) = @_;
  my $string = "'" . $self->get_name() . "." . $self->get_version() . "'";
  $string .= "\n      Description:     " . $self->get_description() if $self->get_description();
  $string .= "\n      Attributes:      <" . join(", ", map { $_->to_string() } @{$self->get_attributes()}) . ">" if scalar(@{$self->get_attributes()});
  $string .= "\n      Term Source REF: " . $self->get_termsource()->to_string() if ($self->get_termsource());
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_version() eq $other->get_version() && $self->get_description() eq $other->get_description() && $self->get_version() eq $other->get_version());

  my @attributes = @{$self->get_attributes()};
  return 0 unless scalar(@attributes) == scalar(@{$other->get_attributes()});
  foreach my $attribute (@attributes) {
    return 0 unless scalar(grep { $_->equals($attribute) } @{$other->get_attributes()});
  }

  if ($self->get_termsource()) {
    return 0 unless $other->get_termsource();
    return 0 unless $self->get_termsource()->equals($other->get_termsource());
  } else {
    return 0 if $other->get_termsource();
  }


  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Protocol({
      'name' => $self->get_name(),
      'version' => $self->get_version(),
      'description' => $self->get_description(),
      'chadoxml_id' => $self->get_chadoxml_id(),
    });
  foreach my $attribute (@{$self->get_attributes()}) {
    $clone->add_attribute($attribute->clone());
  }
  $clone->set_termsource($self->get_termsource()->clone()) if $self->get_termsource();
  return $clone;
}

1;
