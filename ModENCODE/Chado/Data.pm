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
my %features         :ATTR( :get<features>,             :default<[]> );
my %wiggle_datas     :ATTR( :get<wiggle_datas>,         :default<[]> );
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
  my $features = $args->{'features'};
  if (defined($features)) {
    if (ref($features) ne 'ARRAY') {
      $features = [ $features ];
    }
    foreach my $feature (@$features) {
      $self->add_feature($feature);
    }
  }
  my $wiggle_datas = $args->{'wiggle_datas'};
  if (defined($wiggle_datas)) {
    if (ref($wiggle_datas) ne 'ARRAY') {
      $wiggle_datas = [ $wiggle_datas ];
    }
    foreach my $wiggle_data (@$wiggle_datas) {
      $self->add_wiggle_data($wiggle_data);
    }
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

sub set_attributes {
  my ($self, $attributes) = @_;
  $attributes{ident $self} = [];
  foreach my $attribute (@$attributes) {
    $self->add_attribute($attribute);
  }
}

sub add_feature {
  my ($self, $feature) = @_;
  ($feature->isa('ModENCODE::Chado::Feature')) or croak("Can't add a " . ref($feature) . " as a feature.");
  push @{$features{ident $self}}, $feature;
}

sub set_features {
  my ($self, $features) = @_;
  $features{ident $self} = [];
  foreach my $feature (@$features) {
    $self->add_feature($feature);
  }
}

sub add_wiggle_data {
  my ($self, $wiggle_data) = @_;
  ($wiggle_data->isa('ModENCODE::Chado::Wiggle_Data')) or croak("Can't add a " . ref($wiggle_data) . " as a wiggle_data.");
  push @{$wiggle_datas{ident $self}}, $wiggle_data;
}

sub set_wiggle_datas {
  my ($self, $wiggle_datas) = @_;
  $wiggle_datas{ident $self} = [];
  foreach my $wiggle_data (@$wiggle_datas) {
    $self->add_wiggle_data($wiggle_data);
  }
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
  $string .= "=" if ($self->get_value() || scalar(@{$self->get_features()}) || scalar(@{$self->get_wiggle_datas()}));
  $string .= $self->get_value();
  foreach my $feature (@{$self->get_features()}) {
    $string .= "," . $feature->to_string();
  }
  foreach my $wiggle_data (@{$self->get_wiggle_datas()}) {
    $string .= "," . $wiggle_data->to_string();
  }
  return $string;
}

sub equals {
  my ($self, $other) = @_;

  return 1 if ($self == $other);
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
  } else {
    return 0 if $other->get_termsource();
  }

  if ($self->get_type()) {
    return 0 unless $other->get_type();
    return 0 unless $self->get_type()->equals($other->get_type());
  } else {
    return 0 if $other->get_type();
  }

#  my @features = @{$self->get_features()};
#  return 0 unless scalar(@features) == scalar(@{$other->get_features()});
#  foreach my $feature (@features) {
#    return 0 unless scalar(grep { $_->equals($feature) } @{$other->get_features()});
#  }

#  my @wiggle_datas = @{$self->get_wiggle_datas()};
#  return 0 unless scalar(@wiggle_datas) == scalar(@{$other->get_wiggle_datas()});
#  foreach my $wiggle_data (@wiggle_datas) {
#    return 0 unless scalar(grep { $_->equals($wiggle_data) } @{$other->get_wiggle_datas()});
#  }

#  my @organisms = @{$self->get_organisms()};
#  return 0 unless scalar(@organisms) == scalar(@{$other->get_organisms()});
#  foreach my $organism (@organisms) {
#    return 0 unless scalar(grep { $_->equals($organism) } @{$other->get_organisms()});
#  }

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
  foreach my $feature (@{$self->get_features()}) {
    $clone->add_feature($feature->clone());
  }
  foreach my $wiggle_data (@{$self->get_wiggle_datas()}) {
    $clone->add_wiggle_data($wiggle_data->clone());
  }
  foreach my $organism (@{$self->get_organisms()}) {
    $clone->add_organism($organism->clone());
  }
  $clone->set_termsource($self->get_termsource()->clone()) if $self->get_termsource();
  $clone->set_type($self->get_type()->clone()) if $self->get_type();
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
  $features{ident $self} = [];
  $wiggle_datas{ident $self} = [];
  $organisms{ident $self} = [];
  foreach my $attribute (@{$other->get_attributes()}) {
    $self->add_attribute($attribute);
  }
  foreach my $feature (@{$other->get_features()}) {
    $self->add_feature($feature);
  }
  foreach my $wiggle_data (@{$other->get_wiggle_datas()}) {
    $self->add_wiggle_data($wiggle_data);
  }
  foreach my $organism (@{$other->get_organisms()}) {
    $self->add_organism($organism);
  }
  $termsource{ident $self} = undef;
  $type{ident $self} = undef;
  $self->set_termsource($other->get_termsource()) if $other->get_termsource();
  $self->set_type($other->get_type()) if $other->get_type();
}


1;
