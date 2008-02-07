package ModENCODE::Chado::Data;

use strict;
use Class::Std;
use Carp qw(croak);


# Attributes
my %name             :ATTR( :name<name>,                :default<''> );
my %heading          :ATTR( :name<heading>,             :default<''> );
my %value            :ATTR( :name<value>,               :default<''> );
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );
my %anonymous        :ATTR( :set<anonymous>,            :init_arg<anonymous>,           :default<0> );

# Relationships
my %attributes       :ATTR( :get<attributes>,           :default<[]> );
my %termsource       :ATTR( :get<termsource>,           :default<undef> );
my %type             :ATTR( :get<type>,                 :default<undef> );
my %feature          :ATTR( :get<feature>,              :default<undef> );
my %wiggle_data      :ATTR( :get<wiggle_data>,          :default<undef> );

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
  my $feature = $args->{'feature'};
  if (defined($feature)) {
    $self->set_feature($feature);
  }
  my $wiggle_data = $args->{'wiggle_data'};
  if (defined($wiggle_data)) {
    $self->set_wiggle_data($wiggle_data);
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

sub is_anonymous {
  my ($self) = @_;
  return $anonymous{ident $self};
}

sub set_feature {
  my ($self, $feature) = @_;
  ($feature->isa('ModENCODE::Chado::Feature')) or croak("Can't add a " . ref($feature) . " as a feature.");
  $feature{ident $self} = $feature;
}

sub set_wiggle_data {
  my ($self, $wiggle_data) = @_;
  ($wiggle_data->isa('ModENCODE::Chado::Wiggle_Data')) or croak("Can't add a " . ref($wiggle_data) . " as a wiggle_data.");
  $wiggle_data{ident $self} = $wiggle_data;
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
  $string .= "=" if ($self->get_value() || $self->get_feature() || $self->get_wiggle_data());
  $string .= $self->get_value();
  $string .= "," . $self->get_feature()->to_string() if $self->get_feature();
  $string .= "," . $self->get_wiggle_data()->to_string() if $self->get_wiggle_data();
  return $string;
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
  if ($self->get_feature()) {
    return 0 unless $other->get_feature();
    return 0 unless $self->get_feature()->equals($other->get_feature());
  }
  if ($self->get_wiggle_data()) {
    return 0 unless $other->get_wiggle_data();
    return 0 unless $self->get_wiggle_data()->equals($other->get_wiggle_data());
  }

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Data({
      'name' => $self->get_name(),
      'heading' => $self->get_heading(),
      'value' => $self->get_value(),
      'chadoxml_id' => $self->get_chadoxml_id(),
      'anonymous' => $self->is_anonymous(),
    });
  foreach my $attribute (@{$self->get_attributes()}) {
    $clone->add_attribute($attribute->clone());
  }
  $clone->set_termsource($self->get_termsource()->clone()) if $self->get_termsource();
  $clone->set_type($self->get_type()->clone()) if $self->get_type();
  $clone->set_feature($self->get_feature()->clone()) if $self->get_feature();
  $clone->set_wiggle_data($self->get_wiggle_data()->clone()) if $self->get_wiggle_data();
  return $clone;
}

sub mimic {
  my ($self, $other) = @_;
  croak "Datum " . $self->to_string() . " cannot mimic an object of type " . ref($other) if (ref($self) ne ref($other));
  $self->set_name($other->get_name());
  $self->set_heading($other->get_heading());
  $self->set_value($other->get_value());
  $self->set_chadoxml_id($other->get_chadoxml_id());
  $self->set_anonymous($other->is_anonymous());
  $attributes{ident $self} = [];
  foreach my $attribute (@{$other->get_attributes()}) {
    $self->add_attribute($attribute->clone());
  }
  $termsource{ident $self} = undef;
  $type{ident $self} = undef;
  $feature{ident $self} = undef;
  $wiggle_data{ident $self} = undef;
  $self->set_termsource($other->get_termsource()->clone()) if $other->get_termsource();
  $self->set_type($other->get_type()->clone()) if $other->get_type();
  $self->set_feature($other->get_feature()->clone()) if $other->get_feature();
  $self->set_wiggle_data($other->get_wiggle_data()->clone()) if $other->get_wiggle_data();
}


1;
