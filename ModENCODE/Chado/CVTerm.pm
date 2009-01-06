package ModENCODE::Chado::CVTerm;
=pod

=head1 NAME

ModENCODE::Chado::CVTerm - A class representing a simplified Chado
I<cvterm> object.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado B<cvterm>
table. It provides accessors for the various attributes of a controlled
vocbulary term that are stored in the cvterm table itself, plus accessors for
relationships to certain other Chado tables (i.e. B<cv> and B<dbxref>).

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
ModENCODE::Chado::CVTerm({ 'name' =E<gt> 'gene', 'definition' =E<gt> 'A gene is
a gene' });> will create a new CVTerm object with a name of 'gene' and 'A gene
is a gene' as the definition. For complex types (other Chado objects), the
default L<Class::Std> setters and initializers have been replaced with
subroutines that make sure the type of the object being passed in is correct.

=back

=head2 Using ModENCODE::Chado::CVTerm

=over

  my $cvterm = new ModENCODE::Chado::CVTerm({
    # Simple attributes
    'name'              => 'gene',
    'definition'        => 'A gene is a gene',
    'is_obsolete'       => 0,

    # Object relationships
    'cv'                => new ModENCODE::Chado::CV(),
    'dbxref'            => new ModENCODE::Chado::DBXref()
  });

  $cvterm->set_name('New Name);
  my $cvterm_name = $cvterm->get_name();
  print $cvterm->to_string();

=back

=head1 ACCESSORS

=over

=item get_name() | set_name($name)

The name of this Chado controlled vocabulary term; it corresponds to the
cvterm.name field in a Chado database.

=item get_definition() | set_definition($definition)

The definition of this Chado controlled vocabulary term; it corresponds to the
cvterm.definition field in a Chado database.

=item get_is_obsolete() | set_is_obsolete($is_obsolete)

Whether or not this Chado controlled vocabulary term is obsolete; it corresponds
to the cvterm.is_obsolete field in a Chado database and is treated as a boolean
value by Perl L<DBI>. B<0> is false, most other values (including B<1>) are
true.

=item get_dbxref() | set_dbxref($dbxref) 

The dbxref of this Chado controlled vocabulary term. This must be a
L<ModENCODE::Chado::DBXref> or conforming subclass (via C<isa>). The dbxref
object corresponds to a dbxref in the Chado dbxref table, and the
cvterm.dbxref_id field is used to track the relationship.

=item get_cv() | set_cv($cv) 

The controlled vocabulary containing this Chado controlled vocabulary term. This
must be a L<ModENCODE::Chado::CV> or conforming subclass (via C<isa>). The
controlled vocabulary object corresponds to a controlled vocabulary in the Chado
cv table, and the cvterm.cv_id field is used to track the relationship.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this controlled vocabulary term and $obj are equal. Checks all
simple and complex attributes. Also requires that this object and $obj are of
the exact same type. (A parent class != a subclass, even if all attributes are
the same.)

=item clone()

Returns a deep copy of this object, recursing to clone all complex type
attributes.

=item to_string()

Return a string representation of this controlled vocabulary term.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::CV>, L<ModENCODE::Chado::DBXref>,
L<ModENCODE::Chado::Feature>, L<ModENCODE::Chado::Attribute>,
L<ModENCODE::Chado::Data>, L<ModENCODE::Chado::ExperimentProp>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

use strict;
use Class::Std;
use Carp qw(croak);

use ModENCODE::Chado::DB;
use ModENCODE::Chado::DBXref;
use ModENCODE::Cache;

# Attributes
my %cvterm_id        :ATTR( :name<id>,                  :default<undef> );
my %name             :ATTR( :get<name>,                 :init_arg<name> );
my %definition       :ATTR( :name<definition>,          :default<''> );
my %is_obsolete      :ATTR( :get<is_obsolete>,          :init_arg<is_obsolete>, :default<0> );

# Relationships
my %cv               :ATTR( :init_arg<cv> );
my %dbxref           :ATTR( :set<dbxref>,               :init_arg<dbxref>, :default<undef> );


sub new_no_cache {
  return Class::Std::new(@_);
}

sub new {
  my $temp = Class::Std::new(@_);
  my $cached_cvterm = ModENCODE::Cache::get_cached_cvterm($temp);

  if ($temp->get_name =~ /^\s*$/) {
    use Carp qw(confess);
    confess "Oh noes, created CVTerm with no name.";
  }
  if ($cached_cvterm) {
    # Update any cached cvterm
    my $need_save = 0;
    if ($temp->get_definition && !($cached_cvterm->get_object->get_definition())) {
      $cached_cvterm->get_object->set_definition($temp->get_definition);
      $need_save = 1;
    } 
    if ($temp->get_dbxref && !($cached_cvterm->get_object->get_dbxref())) {
      $cached_cvterm->get_object->set_dbxref($temp->get_dbxref);
      $need_save = 1;
    }
    ModENCODE::Cache::save_cvterm($cached_cvterm) if $need_save; # For update
    return $cached_cvterm;
  }

  # This is a new CVTerm
  my $self = $temp;
  return ModENCODE::Cache::add_cvterm_to_cache($self);
}

sub START {
  my ($self, $ident, $args) = @_;
  my $cv = $args->{'cv'};
}

sub get_cv_id {
  my $self = shift;
  return $cv{ident $self} ? $cv{ident $self}->get_id : undef;
}

sub get_cv {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $cv = $cv{ident $self};
  return undef unless defined $cv;
  return $get_cached_object ? $cv{ident $self}->get_object : $cv{ident $self};
}

sub get_dbxref_id {
  my $self = shift;
  return $dbxref{ident $self} ? $dbxref{ident $self}->get_id : undef;
}

sub get_dbxref {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $dbxref = $dbxref{ident $self};
  return undef unless defined $dbxref;
  return $get_cached_object ? $dbxref{ident $self}->get_object : $dbxref{ident $self};
}

sub to_string {
  my ($self) = @_;
  my $string = "{";
  $string .= $self->get_cv()->get_object->to_string() . ":" if $self->get_cv();
  $string .= $self->get_name();
  $string .= "}";
  return $string;
}

sub save {
  ModENCODE::Cache::save_cvterm(shift);
}

1;

