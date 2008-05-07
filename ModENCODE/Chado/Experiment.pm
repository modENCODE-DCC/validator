package ModENCODE::Chado::Experiment;
=pod

=head1 NAME

ModENCODE::Chado::Experiment - A class representing a simplified Chado
I<experiment> object.  B<NOTE:> The experiment table only exists in Chado
instances with the BIR-TAB extension installed.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<experiment> table. It provides accessors for the various attributes of an
experiment that are stored in the experiment table itself, plus accessors for
relationships to certain other Chado tables (i.e. B<applied_protocol> and
B<experiment_prop>).

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_uniquename()|/get_uniquename() |
set_uniquename($uniquename)> or $obj->L<set_uniquename()|/get_uniquename() |
set_uniquename($uniquename)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new
ModENCODE::Chado::Protocol({ 'uniquename' =E<gt> 'An Experiment', 'descripton'
=E<gt> 'An experiment was run.' });> will create a new Experiment object with a
uniquename of 'An Experiment' and a description of 'An experiment was run.'. For
complex types (other Chado objects), the default L<Class::Std> setters and
initializers have been replaced with subroutines that make sure the type of the
object being passed in is correct.

=back

=head2 Using ModENCODE::Chado::Experiment

=over

  my $experiment = new ModENCODE::Chado::Experiment({
    # Simple attributes
    'chadoxml_id'               => 'Experiment_111',
    'uniquename'                => 'An Experiment',
    'description'               => 'A Description',

    # Object relationships
    'properties'                => [ new ModENCODE::Chado::ExperimentProp(), ... ]
    'applied_protocol_slots'    => [ 
        [ new ModENCODE::Chado::AppliedProtocol(), ... ],
        [ new ModENCODE::Chado::AppliedProtocol(), ... ],
        ...
    ]
  });

  $experiment->set_uniquename('a uniquename');
  my $uniquename = $experiment->get_uniquename();
  print $experiment->to_string();

=back

=head1 ACCESSORS

=over

=item get_chadoxml_id() | set_chadoxml_id($chadoxml_id)

The I<chadoxml_id> is used by L<ModENCODE::Chado::XMLWriter> to keep track of
the ChadoXML Macro ID (used to refer to the same feature in XML multiple times).
It is also populated when using L<ModENCODE::Parser::Chado> to pull data out of
a Chado database. (Note that the XMLWriter will generate new I<chadoxml_id>s in
this case; it does so whenever the I<chadoxml_id> is purely numeric.

=item get_uniquename() | set_uniquename($uniquename)

The uniquename of this Chado experiment; it corresponds to the
experiment.uniquename field in a Chado database.

=item get_description() | set_description($description)

The description of this Chado experiment; it corresponds to the
experiment.description field in a Chado database.

=item get_properties() | add_property($property) | add_properties(\@properties)

A list of all the properties associated with this Chado experiment. The getter
returns an arrayref of L<ModENCODE::Chado::ExperimentProp> objects, and the
adders add a single property or an arraref or multiple properties to the list.
The property objects must be a L<ModENCODE::Chado::ExperimentProp> or conforming
subclass (via C<isa>).  The property objects corresponds to the properties in
the Chado experiment_prop table, and the experiment_prop.experiment_id field is
used to track the relationship.

=back

=head2 Applied Protocols

=head3 Overview of applied protocols

The experiment object tracks all of the L<applied
protocols|ModENCODE::Chado::AppliedProtocol> used as part of this experiment in
an array of arrays called C<applied_protocol_slots>. The structure reflects the
shape of a columnar BIR-TAB SDRF file: The first entry in the outer array
corresponds to the first protocol column in an SDRF, the second entry to the
second protocol column, etc. Each inner array contains an entry for each
application of a protocol in that column/slot.

For instance, given an SDRF:
 Parameter Value [in]  Protocol REF  Result Value [out]  Protocol REF
 "1st input"           ProtocolA     "1st output"        ProtocolB
 "2nd input"           ProtocolA     "2nd output"        ProtocolB
 "3rd input"           ProtocolA     "2nd output"        ProtocolB

First let's consider ProtocolA. There are two applications of the protocol (even
though there are three rows). The first application takes in I<1st input> and
outputs I<1st output>. The second application takes in I<2nd input> and I<3rd
input> and outputs I<2nd output>. Therefore, the first "slot" in
C<applied_protocol_slots> will have two applied protocols. The second slot will
have two applications of ProtocolB: the one that takes in I<1st output> and the
one that takes in I<2nd output>.

The resulting C<applied_protocol_slots> could be created like so:

  $input1 = new ModENCODE::Chado::Data({
    'heading' => 'Parameter Value',
    'name'    => 'in',
    'value'   => '1st input'
  });
  $input2 = new ModENCODE::Chado::Data({
    'heading' => 'Parameter Value',
    'name'    => 'in',
    'value'   => '2nd input'
  });
  $input3 = new ModENCODE::Chado::Data({
    'heading' => 'Parameter Value',
    'name'    => 'in',
    'value'   => '3rd input'
  });
  $output1 = new ModENCODE::Chado::Data({
    'heading' => 'Result Value',
    'name'    => 'out',
    'value'   => '1st output'
  });
  $output2 = new ModENCODE::Chado::Data({
    'heading' => 'Result Value',
    'name'    => 'out',
    'value'   => '2nd output'
  });
  $apA_on_input1_output1 = new ModENCODE::Chado::AppliedProtocol({
    'input_data' => [ $input1 ],
    'output_data' => [ $output1 ]
  });
  $apA_on_input2and3_output2 = new ModENCODE::Chado::AppliedProtocol({
    'input_data' => [ $input2, $input3 ],
    'output_data' => [ $output2 ]
  });
  $apB_on_output1 = new ModENCODE::Chado::AppliedProtocol({
    'input_data' => [ $output1 ],
  });
  $apB_on_output2 = new ModENCODE::Chado::AppliedProtocol({
    'input_data' => [ $output2 ],
  });

  $applied_protocol_slots = [
    [ $apA_on_input1_output1, $apA_on_input2and3_output2 ],
    [ $apB_on_output1, $apB_on_output2 ]
  ];

=head3 Accessing applied protocols 

=over

=item get_num_applied_protocol_slots()

Return the number of applied protocol slots. This corresponds to the number of
protocol columns in a BIR-TAB SDRF document.

=item get_applied_protocols_at_slot($slotnum)

Return an array of the L<applied protocols|ModENCODE::Chado::AppliedProtocol> at
slot C<$slotnum>. This corresponds to the C<$slotnum>th protocol column in a
BIR-TAB SDRF document.

=item add_applied_protocol_to_slot($applied_protocol, $slotnum)

Given a L<ModENCODE::Chado::AppliedProtocol> or conforming subclass (via
C<isa>), attempt to add the applied protocol to the list of protocols at slot
C<$slotnum>. If the applied protocol has already been inserted (by checking
L<ModENCODE::Chado::AppliedProtocol::equals($obj)|ModENCODE::Chado::AppliedProtocol/equals($obj)>,
then it is not inserted again, but no error occurs.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this experiment and $obj are equal. Checks all simple and
complex attributes. Also requires that this object and $obj are of the exact
same type. (A parent class != a subclass, even if all attributes are the same.)

=item clone()

B<Unlike> most of the other ModENCODE::Chado::* features, this function returns
a partially shallow copy of this Experiment object. It copies the simple
attributes, and deep-copies the experiment properties, but does not deep-copy
the applied protocols; it merely copies the references. 

=item to_string()

Return a string representation of this experiment. Attempts to print all applied
protocols. (May be very slow; mostly useful for debugging.)

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::AppliedProtocol>,
L<ModENCODE::Chado::Protocol>, L<ModENCODE::Chado::ExperimentProp>,
L<ModENCODE::Chado::Data>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Class::Std;
use Carp qw(croak carp);


# Attributes
my %chadoxml_id             :ATTR( :name<chadoxml_id>,         :default<undef> );
my %uniquename              :ATTR( :name<uniquename>,          :default<undef> );
my %description             :ATTR( :name<description>,         :default<''> );

# Relationships
my %properties              :ATTR( :get<properties>,              :default<[]> );
my %applied_protocol_slots  :ATTR( :get<applied_protocol_slots>,  :default<[]> );

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
  my $string = "Experiment " . $self->get_uniquename() . "(" . $self->get_description() . ")\n";
  $string .= "  with properties [";
  $string .= "\n    " . join("\n    ", map { $_->to_string() } @{$self->get_properties()}) . "\n  " if scalar(@{$self->get_properties()});
  $string .= "]\n  has applied_protocols:\n";
  my @proto_slots = @{$self->get_applied_protocol_slots()};
  for (my $i = 0; $i < scalar(@proto_slots); $i++) {
    $string .= "------------------------------ROUND $i OF PROTOCOLS------------------------------\n";
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
  return 0 unless ($self->get_uniquename() eq $other->get_uniquename());

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

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::Experiment({
      'chadoxml_id' => $self->get_chadoxml_id(),
      'uniquename' => $self->get_uniquename(),
      'description' => $self->get_description(),
    });
  my $applied_protocol_slots = $self->get_applied_protocol_slots();
  for (my $i = 0; $i < scalar(@{$applied_protocol_slots}); $i++) {
    foreach my $applied_protocol (@{$applied_protocol_slots->[$i]}) {
      $clone->add_applied_protocol_to_slot($applied_protocol, $i);
    }
  }
  foreach my $property (@{$self->get_properties()}) {
    $clone->add_property($property->clone());
  }
  return $clone;
}

1;
