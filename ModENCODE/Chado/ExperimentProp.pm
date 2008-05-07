package ModENCODE::Chado::ExperimentProp;
=pod

=head1 NAME

ModENCODE::Chado::ExperimentProp - A class representing a simplified Chado
I<experiment_prop> object. B<NOTE:> The experiment_prop table only exists in
Chado instances with the BIR-TAB extension installed.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<experiment_prop> table. It provides accessors for the various attributes of an
experiment property that are stored in the experiment_prop table itself, plus
accessors for relationships to certain other Chado tables (i.e. B<dbxref> and
B<cvterm>).

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
ModENCODE::Chado::Attribute({ 'name' =E<gt> 'A property', 'value' =E<gt>
'something' });> will create a new ExperimentProp object with a name of 'A
property' and a value of 'something'. For complex types (other Chado objects),
the default L<Class::Std> setters and initializers have been replaced with
subroutines that make sure the type of the object being passed in is correct.

=back

=head2 Using ModENCODE::Chado::ExperimentProp

=over

  my $experiment_prop = new ModENCODE::Chado::ExperimentProp({
    # Simple attributes
    'name'              => 'name',
    'value'             => 'some value',
    'rank'              => 0,

    # Object relationships
    'termsource'        => new ModENCODE::Chado::DBXref(),
    'type'              => new ModENCODE::Chado::CVTerm(),
  });

  $experiment_prop->set_name('a name');
  my $name = $experiment_prop->get_name();
  print $experiment_prop->to_string();

=back

=head1 ACCESSORS

=over

=item get_name() | set_name($name)

The name of this Chado experiment property; it corresponds to the
experiment_prop.name field in a Chado database. In a BIR-TAB document, many of
the fields in the IDF become experiment properties.

=item get_value() | set_value($value)

The value of this Chado experiment property; it corresponds to the
experiment_prop.value field in a Chado database.In a BIR-TAB document, many of
the fields in the IDF become experiment properties.

=item get_rank() | set_rank($rank)

The rank of this Chado experiment property; it corresponds to the
experiment_prop.rank field in a Chado database. The rank is used when there is
more than one experiment property with the same name tied to a given
L<Experiment|ModENCODE::Chado::Experiment>.

=item get_termsource() | set_termsource($dbxref)

The dbxref for this Chado experiment property. This must be a
L<ModENCODE::Chado::DBXref> or conforming subclass (via C<isa>). The dbxref
object corresponds to a dbxref in the Chado dbxref table, and the
experiment_prop.dbxref_id field is used to track the relationship. In the
context of BIR-TAB, a termsource dbxref is the reference to a term controlled by
a Term Source REF column. (For instance, an experiment property with a value of
'gene' coule have a Term Source REF of 'SO', the sequence ontology. The dbxref
would then point at the dbxref for SO:gene in the Chado database.)

=item get_type() | set_type($type)

The type of the value of this Chado experimnt property. This must be a
L<ModENCODE::Chado::CVTerm> or conforming subclass (via C<isa>). The type object
corresponds to a cvterm in the Chado cvterm table, and the
experiment_prop.type_id field is used to track the relationship.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this experiment property and $obj are equal. Checks all simple
and complex attributes. Also requires that this object and $obj are of the exact
same type.  (A parent class != a subclass, even if all attributes are the same.)

=item clone()

Returns a deep copy of this object, recursing to clone all complex type
attributes.

=item to_string()

Return a string representation of this experiment property. Attempts to print
the associated L<type|/get_type() | set_type($type)> and
L<termsource|/get_termsource() | set_termsource($dbxref)> as well as the simple
attributes.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::Experiment>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

use strict;
use Class::Std;
use Carp qw(croak);

# Attributes
my %name             :ATTR( :name<name> );
my %value            :ATTR( :name<value>,               :default<''> );
my %rank             :ATTR( :name<rank>,                :default<0> );

# Relationships
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

sub to_string {
  my ($self) = @_;
  my $string;
  $string .= $self->get_rank() . ":" if (defined($self->get_rank()));
  $string .= $self->get_name() if $self->get_name();
  $string .= "<" . $self->get_type()->to_string() . ">" if $self->get_type();
  $string .= $self->get_termsource()->to_string() if $self->get_termsource();
  $string .= "='" . $self->get_value() . "'";
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name() && $self->get_value() eq $other->get_value() && $self->get_rank() eq $other->get_rank());

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

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::ExperimentProp({
      'name' => $self->get_name(),
      'value' => $self->get_value(),
      'rank' => $self->get_rank(),
    });
  $clone->set_type($self->get_type()->clone()) if $self->get_type();
  $clone->set_termsource($self->get_termsource()->clone()) if $self->get_termsource();
  return $clone;
}

1;
