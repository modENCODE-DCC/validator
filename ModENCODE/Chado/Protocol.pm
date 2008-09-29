package ModENCODE::Chado::Protocol;
=pod

=head1 NAME

ModENCODE::Chado::Protocol - A class representing a simplified Chado I<protocol>
object.  B<NOTE:> The protocol table only exists in Chado instances with the
BIR-TAB extension installed.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<protocol> table. It provides accessors for the various attributes of a
protocol that are stored in the protocol table itself, plus accessors for
relationships to certain other Chado tables (i.e. B<attribute> and B<dbxref>,
etc.)

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_name()|/get_name() | set_name($name)> or
$obj->L<set_name()|/get_name() | set_name($name)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new
ModENCODE::Chado::Protocol({ 'name' =E<gt> 'A Protocol', 'version' =E<gt> 1 });>
will create a new Protocol object with a name of 'A Protocol' and a version of
1. For complex types (other Chado objects), the default L<Class::Std> setters
and initializers have been replaced with subroutines that make sure the type of
the object being passed in is correct.

=back

=head2 Using ModENCODE::Chado::Protocol

=over

  my $protocol = new ModENCODE::Chado::Protocol({
    # Simple attributes
    'chadoxml_id'       => 'Protocol_111',
    'name'              => 'A Protocol',
    'version'           => 1,
    'description'       => 'A Description',

    # Object relationships
    'termsource'        => new ModENCODE::Chado::DBXref(),
    'attributes'        => [ new ModENCODE::Chado::Attribute(), ... ]
  });

  $protocol->set_name('a name');
  my $name = $protocol->get_name();
  print $protocol->to_string();

=back

=head1 ACCESSORS

=over

=item get_chadoxml_id() | set_chadoxml_id($chadoxml_id)

The I<chadoxml_id> is used by L<ModENCODE::Chado::XMLWriter> to keep track of
the ChadoXML Macro ID (used to refer to the same feature in XML multiple times).
It is also populated when using L<ModENCODE::Parser::Chado> to pull data out of
a Chado database. (Note that the XMLWriter will generate new I<chadoxml_id>s in
this case; it does so whenever the I<chadoxml_id> is purely numeric.

=item get_name() | set_name($name)

The name of this Chado protocol; it corresponds to the protocol.name field in a
Chado database.

=item get_version() | set_version($version)

The version of this Chado protocol; it corresponds to the protocol.version field
in a Chado database.

=item get_description() | set_description($description)

The description of this Chado protocol; it corresponds to the
protocol.description field in a Chado database.

=item get_termsource() | set_termsource($dbxref)

The dbxref for this Chado protocol. This must be a L<ModENCODE::Chado::DBXref>
or conforming subclass (via C<isa>). The dbxref object corresponds to a dbxref
in the Chado dbxref table, and the protocol.dbxref_id field is used to track the
relationship. In the context of BIR-TAB, a termsource dbxref is the reference to
a term controlled by a Term Source REF column. (For instance, an if a protocol
is referenced elsewhere (for example, in the MGED ontology), then the dbxref
would then point at the dbxref for that protocol in the Chado database.

=item get_attributes() | add_attribute($attribute) | set_attributes(\@attributes)

A list of all the attributes associated with this Chado protocol. The attributes
provide more information about this protocol and reside in the Chado attribute
table. These attributes are generally attached from a BIR-TAB document - columns
with headings that are not specifically defined as data, protocol, or term
source columns are assumed to be attribute columns for the preceding data or
protocol column.

The attributes are L<ModENCODE::Chado::Attribute> objects. The adder adds
another attribute to the list, the getter returns an arrayref of
L<ModENCODE::Chado::Attribute> objects, and the setter replaces the current
list, given an (empty or populated) array of
L<Attribute|ModENCODE::Chado::Attribute> objects. The attribute objects may also
be conforming subclasses (via C<isa>) of L<ModENCODE::Chado::Attribute>. The
attribute objects corresponds to the attributes in the Chado attributes table,
and the protocol_attribute.attribute_id and protocol_attribute.data_id fields
are used to track the relationship.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this feature and $obj are equal. Checks all simple and complex
attributes. Also requires that this object and $obj are of the exact same type.
(A parent class != a subclass, even if all attributes are the same.)

=item clone()

Returns a deep copy of this object, recursing to clone all complex type
attributes.

=item to_string()

Return a string representation of this protocol. Attempts to print the
associated L<attributes|/get_attributes() | add_attribute($attribute) |
set_attributes(\@attributes)> and L<termsource|/get_termsource() |
set_termsource($dbxref)> as well as the simple attributes.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::AppliedProtocol>,
L<ModENCODE::Chado::Attribute>, L<ModENCODE::Chado::DBXref>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut
use strict;
use Class::Std;
use Carp qw(croak);

my %all_protocols;

# Attributes
my %chadoxml_id      :ATTR( :name<chadoxml_id>,         :default<undef> );
my %name             :ATTR( :name<name>,                :default<''> );
my %version          :ATTR( :name<version>,             :default<undef> );
my %description      :ATTR( :name<description>,         :default<''> );

# Relationships
my %termsource       :ATTR( :get<termsource>,           :default<undef> );
my %attributes       :ATTR( :get<attributes>,           :default<[]> );

sub new {
  my $self = Class::Std::new(@_);
  # Caching protocols
#  $all_protocols{$self->get_name()} = {} if (!defined($all_protocols{$self->get_name()}));
#
#  my $cached_protocol = $all_protocols{$self->get_name()}->{$self->get_version()};
#
#  if ($cached_protocol) {
#    # Add any additional info
#    $cached_protocol->set_description($self->get_description()) if ($self->get_description() && !($cached_protocol->get_description()));
#    return $cached_protocol;
#  } else {
#    $all_protocols{$self->get_name()}->{$self->get_version()} = $self;
#  }
  return $self;
}

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
