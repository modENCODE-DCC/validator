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
use ModENCODE::Cache;
use Carp qw(croak);

# Attributes

my %experimentprop_id   :ATTR( :name<id>,                  :default<undef> );
my %name                :ATTR( :get<name>,                 :init_arg<name> );
my %value               :ATTR( :name<value>,               :default<''> );
my %rank                :ATTR( :name<rank>,                :init_arg<rank>, :default<0> );

# Relationships
my %termsource          :ATTR( :set<termsource>,           :init_arg<termsource>, :default<undef> );
my %type                :ATTR( :set<type>,                 :init_arg<type>, :default<undef> );
my %experiment          :ATTR( :init_arg<experiment> );

sub new_no_cache {
  return Class::Std::new(@_);
}

sub new {
  my $temp = Class::Std::new(@_);
  return new ModENCODE::Cache::ExperimentProp({'content' => $temp }) if ModENCODE::Cache::get_paused();
  my $cached_experimentprop = ModENCODE::Cache::get_cached_experimentprop($temp);

  if ($cached_experimentprop) {
    # Update any cached experimentprop
    my $need_save = 0;
    if ($temp->get_value && !($cached_experimentprop->get_object->get_value())) {
      $cached_experimentprop->get_object->set_value($temp->get_value);
      $need_save = 1;
    } 
    if ($temp->get_rank && !($cached_experimentprop->get_object->get_rank())) {
      $cached_experimentprop->get_object->set_rank($temp->get_rank);
      $need_save = 1;
    }
    if ($temp->get_termsource && !($cached_experimentprop->get_object->get_termsource())) {
      $cached_experimentprop->get_object->set_termsource($temp->get_termsource);
      $need_save = 1;
    }
    if ($temp->get_type && !($cached_experimentprop->get_object->get_type())) {
      $cached_experimentprop->get_object->set_type($temp->get_type);
      $need_save = 1;
    }
    if ($temp->get_experiment && !($cached_experimentprop->get_object->get_experiment())) {
      $cached_experimentprop->get_object->set_experiment($temp->get_experiment);
      $need_save = 1;
    }
    ModENCODE::Cache::save_experimentprop($cached_experimentprop->get_object) if $need_save; # For update
    return $cached_experimentprop;
  }

  # This is a new ExperimentProp
  my $self = $temp;
  return ModENCODE::Cache::add_experimentprop_to_cache($self);
}

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

sub to_string {
  my ($self) = @_;
  my $string;
  $string .= $self->get_rank() . ":" if (defined($self->get_rank()));
  $string .= $self->get_name() if $self->get_name();
  $string .= "<" . $self->get_type()->get_object->to_string() . ">" if $self->get_type();
  $string .= $self->get_termsource()->get_object->to_string() if $self->get_termsource();
  $string .= "='" . $self->get_value() . "'";
  return $string;
}

sub get_termsource_id {
  my $self = shift;
  return $termsource{ident $self} ? $termsource{ident $self}->get_id : undef;
}

sub get_termsource {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $termsource = $termsource{ident $self};
  return undef unless defined $termsource;
  return $get_cached_object ? $termsource{ident $self}->get_object : $termsource{ident $self};
}

sub get_type_id {
  my $self = shift;
  return $type{ident $self} ? $type{ident $self}->get_id : undef;
}

sub get_type {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $type = $type{ident $self};
  return undef unless defined $type;
  return $get_cached_object ? $type{ident $self}->get_object : $type{ident $self};
}

sub get_experiment_id {
  my $self = shift;
  return $experiment{ident $self} ? $experiment{ident $self}->get_id : undef;
}

sub get_experiment {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $experiment = $experiment{ident $self};
  return undef unless defined $experiment;
  return $get_cached_object ? $experiment{ident $self}->get_object : $experiment{ident $self};
}

sub save {
  ModENCODE::Cache::save_experimentprop(shift);
}


1;

