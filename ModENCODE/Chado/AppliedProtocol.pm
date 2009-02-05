package ModENCODE::Chado::AppliedProtocol;
=pod

=head1 NAME

ModENCODE::Chado::AppliedProtocol - A class representing a Chado
I<applied_protocol> object. B<NOTE:> The applied_protocol table only exists in
Chado instances with the BIR-TAB extension installed.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<applied_protocol> table. It provides accessors for the various attributes of
an applied_protocol that are stored in the applied_protocol table itself, plus
accessors for relationships to certain other Chado tables (i.e. B<data> and
B<protocol>).

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_chadoxml_id()|/get_chadoxml_id() |
set_chadoxml_id($chadoxml_id)> or $obj->L<set_chadoxml_id()|/get_chadoxml_id() |
set_chadoxml_id($chadoxml_id)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new
ModENCODE::Chado::AppliedProtocol({ 'chadoxml_id' =E<gt> 'Feature_001',
'input_data' =E<gt> \@input_datums });> will create a new AppliedProtocol object
with a chadoxml_id of 'Feature_001' and the L<Data|ModENCODE::Chado::Data> in
@input_datums as the input_data. For complex types (other Chado objects), the
default L<Class::Std> setters and initializers have been replaced with
subroutines that make sure the type of the object being passed in is correct.

=back

=head2 Using ModENCODE::Chado::AppliedProtocol

=over

  my $applied_protocol = new ModENCODE::Chado::AppliedProtocol({
    # Simple attributes
    'chadoxml_id'       => 'Feature_111',

    # Object relationships
    'input_data'        => [ new ModENCODE::Chado::Data(), ... ],
    'output_data'       => [ new ModENCODE::Chado::Data(), ... ],
    'protocol'          => new ModENCODE::Chado::Protocol()
  });

  $applied_protocol->set_protocol(new ModENCODE::Chado::Protocol());
  $applied_protocol->add_input_datum(new ModENCODE::Chado::Data());
  $applied_protocol->remove_input_datum($old_input_datum);
  my $input_data = $applied_protocol->get_input_data();
  print $applied_protocol->to_string();

=back

=head1 ACCESSORS

=over

=item get_chadoxml_id() | set_chadoxml_id($chadoxml_id)

The I<chadoxml_id> is used by L<ModENCODE::Chado::XMLWriter> to keep track of
the ChadoXML Macro ID (used to refer to the same feature in XML multiple times).
It is also populated when using L<ModENCODE::Parser::Chado> to pull data out of
a Chado database. (Note that the XMLWriter will generate new I<chadoxml_id>s in
this case; it does so whenever the I<chadoxml_id> is purely numeric.

=item add_input_datum($datum) | add_output_datum($datum)

Add the supplied L<ModENCODE::Chado::Data> (or subclass as tested by C<isa>)
object to the list of inputs or ouputs for this applied protocol. No checking is
done to make sure that the new datum is unique, so some care should be taken -
things will probably work with duplicated data but it certainly won't be as
efficient.

=item remove_input_datum($datum) | remove_output_datum($datum)

Removes I<all> data from the input or output lists where the datum in the list
equals $datum by the L<ModENCODE::Chado::Feature/equals($obj)> method.

=item get_protocol() | set_protocol($protocol)

The protocol applied as part of this Chado applied protocol. This must be a
L<ModENCODE::Chado::Protocol> or conforming subclass (via C<isa>). The protocol
object corresponds to a protocol in the Chado protocol table (as defined in the
BIR-TAB extension to Chado - not the same as in the MAGE-TAB extension). The
applied_protocol.protocol_id field is used to track the relationship.

=item equals($obj)

Returns true if this applied_protocol and $obj are equal. Checks all simple and
complex attributes. Also requires that this object and $obj are of the exact
same type. (A parent class != a subclass, even if all attributes are the same.)

=item clone()

Returns a deep copy of this object, recursing to clone all complex type
attributes.

=item to_string()

Return a string representation of this applied_protocol. Attempts to print all
input and output data, which can potentially recurse through all features
referenced by those data. May thus be very slow; primarily useful for
debugging.)

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::Data>, L<ModENCODE::Chado::Feature>,
L<ModENCODE::Chado::Protocol>, L<ModENCODE::Chado::Experiment>,
L<ModENCODE::Chado::Experiment/Applied Protocols>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

use strict;
use Class::Std;
use Carp qw(confess croak);

# Attributes
my %applied_protocol_id :ATTR( :name<id>,               :default<undef> );

# Relationships
my %protocol            :ATTR(           :init_arg<protocol> );
my %input_data          :ATTR( :init_arg<input_data>,   :default<[]> );
my %output_data         :ATTR( :init_arg<output_data>,  :default<[]> );

# Don't cache applied protocols, since there's really nothing to make them uniquely hashable

sub set_protocol {
  my ($self, $protocol) = @_;
  ($protocol->isa('ModENCODE::Cache::Protocol')) or confess("'" . ref($protocol) . "' is not an protocol to be added to protocol_slots");
  $protocol{ident $self} = $protocol;
}

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $input_data = $args->{'input_data'};
  if (defined($input_data)) {
    if (ref($input_data) ne 'ARRAY') {
      $input_data = [ $input_data ];
    }
    foreach my $input_datum (@$input_data) {
      $self->add_input_datum($input_datum);
    }
  }
  my $output_data = $args->{'output_data'};
  if (defined($output_data)) {
    if (ref($output_data) ne 'ARRAY') {
      $output_data = [ $output_data ];
    }
    foreach my $output_datum (@$output_data) {
      $self->add_output_datum($output_datum);
    }
  }
  my $protocol = $args->{'protocol'};
  if (defined($protocol)) {
    $self->set_protocol($protocol);
  }
}

sub add_input_datum {
  my ($self, $input_datum) = @_;
  ($input_datum->isa('ModENCODE::Cache::Data')) or croak("Can't add a " . ref($input_datum) . " as a input_datum.");
  return if grep { $_->get_id == $input_datum->get_id } @{$input_data{ident $self}};
  push @{$input_data{ident $self}}, $input_datum;
}

sub add_output_datum {
  my ($self, $output_datum) = @_;
  ($output_datum->isa('ModENCODE::Cache::Data')) or croak("Can't add a " . ref($output_datum) . " as a output_datum.");
  return if grep { $_->get_id == $output_datum->get_id } @{$output_data{ident $self}};
  push @{$output_data{ident $self}}, $output_datum;
}

sub remove_output_datum {
  my ($self, $output_datum) = @_;
  for (my $i = 0; $i < scalar(@{$output_data{ident $self}}); $i++) {
    my $existing_datum = $output_data{ident $self}->[$i];
    if ($existing_datum->get_id == $output_datum->get_id) {
      splice(@{$output_data{ident $self}}, $i, 1);
    }
  }
}

sub get_input_data {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $input_data = $input_data{ident $self};
  return $get_cached_object ? map { $_->get_object } @$input_data : @$input_data;
}

sub get_input_data_ids {
  my $self = shift;
  return map { $_->get_id } @{$input_data{ident $self}};
}

sub get_output_data_ids {
  my $self = shift;
  return map { $_->get_id } @{$output_data{ident $self}};
}

sub get_output_data {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $output_data = $output_data{ident $self};
  return $get_cached_object ? map { $_->get_object } @$output_data : @$output_data;
}

sub remove_input_datum {
  my ($self, $input_datum) = @_;
  for (my $i = 0; $i < scalar(@{$input_data{ident $self}}); $i++) {
    my $existing_datum = $input_data{ident $self}->[$i];
    if ($existing_datum->get_id == $input_datum->get_id) {
      splice(@{$input_data{ident $self}}, $i, 1);
    }
  }
}

sub get_protocol_id {
  my $self = shift;
  return $protocol{ident $self} ? $protocol{ident $self}->get_id : undef;
}

sub get_protocol {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $protocol = $protocol{ident $self};
  return undef unless defined $protocol;
  return $get_cached_object ? $protocol{ident $self}->get_object : $protocol{ident $self};
}

sub to_string {
  my ($self) = @_;
  my $string = "Applied Protocol \"" . $self->get_protocol()->get_object->get_name() . "\"->";
  $string .= "(" . join(", ", sort map { $_->get_object->to_string() } $self->get_input_data) . ")";
  $string .= " = (" . join(", ", sort map { $_->get_object->to_string() } $self->get_output_data) . ")";
  $string .= "\n    with protocol: " . $self->get_protocol->get_object->to_string();
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  my @input_data = $self->get_input_data;
  return 0 unless scalar(@input_data) == scalar($other->get_input_data);
  foreach my $datum (@input_data) {
    return 0 unless scalar(grep { $_->get_id == $datum->get_id } $other->get_input_data);
  }

  my @output_data = $self->get_output_data;
  return 0 unless scalar(@output_data) == scalar($other->get_output_data);
  foreach my $datum (@output_data) {
    return 0 unless scalar(grep { $_->get_id == $datum->get_id } $other->get_output_data);
  }

  if ($self->get_protocol()) {
    return 0 unless $other->get_protocol();
    return 0 unless $self->get_protocol->get_id == $other->get_protocol->get_id;
  } else {
    return 0 if $other->get_protocol();
  }


  return 1;
}

1;
