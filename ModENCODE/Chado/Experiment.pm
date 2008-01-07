package ModENCODE::Chado::Experiment;

use strict;
use Class::Std;
use Carp qw(croak carp);


# Attributes
my %description             :ATTR( :name<description>,            :default<''> );

# Relationships
my %applied_protocol_slots  :ATTR( :get<applied_protocol_slots>,  :default<[]> );
my %properties              :ATTR( :get<properties>,              :default<[]> );

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $applied_protocol_slots = $args->{'applied_protocol_slots'};
  if (defined($applied_protocol_slots)) {
    croak "The 'applied_protocol_slots' argument must be an array" if (ref($applied_protocol_slots) ne 'ARRAY');
    for (my $i = 0; $i < scalar(@$applied_protocol_slots); $i++) {
      foreach my $applied_protocol (@{$applied_protocol_slots->[$i]}) {
        $self->add_applied_protocol_to_slot($applied_protocol, $i);
      }
    }
  }
  my $properties = $args->{'properties'};
  if (defined($properties)) {
    if (ref($properties) ne 'ARRAY') {
      $properties = [ $properties ];
    }
    foreach my $property (@$properties) {
      $self->add_property($property);
    }
  }
}
      

sub add_applied_protocol_to_slot {
  my ($self, $applied_protocol, $slot) = @_;
  ($applied_protocol->isa('ModENCODE::Chado::AppliedProtocol')) or croak("'" . ref($applied_protocol) . "' is not an applied_protocol to be added to applied_protocol_slots");
  (defined($slot)) or croak "Can't add applied_protocol\n  " . $applied_protocol->to_string() . "\nto an undefined slot";

  if (ref($applied_protocol_slots{ident $self}->[$slot]) != "ARRAY") {
    $applied_protocol_slots{ident $self}->[$slot] = [];
  }

  my @matching_applied_protocols = grep { $_->equals($applied_protocol) } @{$applied_protocol_slots{ident $self}->[$slot]};
  if (scalar(@matching_applied_protocols)) {
    carp "Not adding duplicate applied_protocol\n  " . $applied_protocol->to_string() . "\nto applied_protocol_slots";
    return;
  }

  push @{$applied_protocol_slots{ident $self}->[$slot]}, $applied_protocol;
}

sub get_num_applied_protocol_slots {
  my ($self) = @_;
  return scalar(@{$self->get_applied_protocol_slots()});
}

sub get_applied_protocols_at_slot {
  my ($self, $slot) = @_;
  return $applied_protocol_slots{ident $self}->[$slot] || [];
}

sub add_properties {
  my ($self, $properties) = @_;
  if (defined($properties)) {
    if (ref($properties) ne 'ARRAY') {
      $properties = [ $properties ];
    }
    foreach my $property (@$properties) {
      $self->add_property($property);
    }
  }
}

sub add_property {
  my ($self, $property) = @_;
  ($property->isa('ModENCODE::Chado::ExperimentProp')) or croak("Can't add a " . ref($property) . " as a property.");
  push @{$properties{ident $self}}, $property;
}

sub to_string {
  my ($self) = @_;
  my $string = "Experiment (" . $self->get_description() . ")\n";
  $string .= "  with properties [";
  $string .= "\n    " . join("\n    ", map { $_->to_string() } @{$self->get_properties()}) . "\n  " if scalar(@{$self->get_properties()});
  $string .= "]\n  has applied_protocols:\n";
  my @proto_slots = @{$self->get_applied_protocol_slots()};
  for (my $i = 0; $i < scalar(@proto_slots); $i++) {
    foreach my $applied_protocol (@{$proto_slots[$i]}) {
      $string .= "    " . $applied_protocol->to_string() . "\n";
    }
  }
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_description() eq $other->get_description());

  my @properties = @{$self->get_properties()};
  return 0 unless scalar(@properties) == scalar(@{$other->get_properties()});
  foreach my $property (@properties) {
    return 0 unless scalar(grep { $_->equals($property) } @{$other->get_properties()});
  }

  my @applied_protocol_slots = @{$self->get_applied_protocol_slots()};
  return 0 unless scalar(@applied_protocol_slots) == scalar(@{$other->get_applied_protocol_slots()});
  for (my $i = 0; $i < scalar(@applied_protocol_slots); $i++) {
    my $this_applied_protocols = $applied_protocol_slots[$i];
    my $other_applied_protocols = $other->get_applied_protocol_slots()->[$i];
    return 0 unless scalar(@$this_applied_protocols) == scalar(@$other_applied_protocols);
    foreach my $applied_protocol (@$this_applied_protocols) {
      return 0 unless scalar(grep { $_->equals($applied_protocol) } @$other_applied_protocols);
    }
  }

  return 1;
}
1;
