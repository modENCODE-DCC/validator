package ModENCODE::Chado::Attribute;
=pod

=head1 NAME

ModENCODE::Chado::Attribute - A class representing a simplified Chado
I<attribute> object. B<NOTE:> The attribute table only exists in Chado instances
with the BIR-TAB extension installed.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<attribute> table. It provides accessors for the various attributes of an
attribute that are stored in the attribute table itself, plus accessors for
relationships to certain other Chado tables (i.e. B<dbxref>, B<cvterm>, and
B<organism>).

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_name()|/get_name() |
set_name($name)> or $obj->L<set_name()|/get_name() |
set_name($name)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new
ModENCODE::Chado::Attribute({ 'heading' =E<gt> 'An Attribute', 'value' =E<gt>
'something' });> will create a new Attribute object with a heading of 'An
Attribute' and a value of 'something'. For complex types (other Chado
objects), the default L<Class::Std> setters and initializers have been replaced
with subroutines that make sure the type of the object being passed in is
correct.

=back

=head2 Using ModENCODE::Chado::Attribute

=over

  my $attribute = new ModENCODE::Chado::Attribute({
    # Simple attributes
    'chadoxml_id'       => 'Feature_111',
    'name'              => 'name',
    'heading'           => 'Heading',
    'rank'              => 0,
    'value'             => 'some value',

    # Object relationships
    'termsource'        => new ModENCODE::Chado::DBXref(),
    'type'              => new ModENCODE::Chado::CVTerm(),
    'organisms'         => [ new ModENCODE::Chado::Organism(), ... ]
  });

  $attribute->set_name('a name');
  my $name = $attribute->get_name();
  print $attribute->to_string();

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

The name of this Chado attribute; it corresponds to the attribute.name field in
a Chado database. In a BIR-TAB document, the attribute columns have both a
L<heading|/get_heading() | set_heading($heading)> and a name in the format C<Heading
[Name]>.

=item get_heading() | set_heading($heading)

The heading of this Chado attribute; it corresponds to the attribute.heading
field in a Chado database. In a BIR-TAB document, the attribute columns have
both a heading and a L<name|/get_name() | set_name($name)> in the format C<Heading
[Name]>.

=item get_value() | set_value($value)

The value of this Chado attribute; it corresponds to the attribute.value field
in a Chado database. In a BIR-TAB document, this is the content of a single cell
in an attribute column.

=item get_rank() | set_rank($rank)

The rank of this Chado attribute; it corresponds to the attribute.rank field in
a Chado database. The rank is used when there is more than one attribute with
the same heading and name tied to a single
L<Protocol|ModENCODE::Chado::Protocol> or L<Data|ModENCODE::Chado::Data>.

=item get_termsource() | set_termsource($dbxref)

The dbxref for this Chado attribute. This must be a L<ModENCODE::Chado::DBXref>
or conforming subclass (via C<isa>). The dbxref object corresponds to a dbxref
in the Chado dbxref table, and the attribute.dbxref_id field is used to track
the relationship. In the context of BIR-TAB, a termsource dbxref is the
reference to a term controlled by a Term Source REF column. (For instance, an
attribute with a value of 'gene' coule have a Term Source REF of 'SO', the
sequence ontology. The dbxref would then point at the dbxref for SO:gene in the
Chado database.)

=item get_type() | set_type($type)

The type of the value of this Chado attribute. This must be a
L<ModENCODE::Chado::CVTerm> or conforming subclass (via C<isa>). The type object
corresponds to a cvterm in the Chado cvterm table, and the attribute.type_id
field is used to track the relationship.

=item get_organisms() | add_organism($organism) | set_organisms(\@organisms)

A list of all the organisms associated with this Chado attribute. The link to
the organism table is akin to the dbxref - it provides a more controlled view of
the L<value|/get_value() | set_value($value)> of the attribute, assuming the
value is an organism. (For example, a value of "Drosophila melanogaster" with a
L<type|/get_type() | set_type($type)> of 'organism' should have an associated
organism in the organism table.)

The organisms are L<ModENCODE::Chado::Organism> objects. The adder adds another
organism to the list, the getter returns an arrayref of
L<ModENCODE::Chado::Organism> objects, and the setter replaces the current list,
given an (empty or populated) array of L<Organism|ModENCODE::Chado::Organism>
objects. The organism objects may also be conforming subclasses (via C<isa>) of
L<ModENCODE::Chado::Organism>.  The organism objects corresponds to the
organisms in the Chado organisms table, and the attribute_organism.attribute_id
and attribute_organism.organism_id fields are used to track the relationship.

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

Return a string representation of this attribute. Attempts to print the
associated L<type|/get_type() | set_type($type)> and
L<termsource|/get_termsource() | set_termsource($dbxref)> as well as the simple
attributes.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::Data>, L<ModENCODE::Chado::Protocol>,
L<ModENCODE::Chado::CVTerm>, L<ModENCODE::Chado::DBXref>,
L<ModENCODE::Chado::Organism>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

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
