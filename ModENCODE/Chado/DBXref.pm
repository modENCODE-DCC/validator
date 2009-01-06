package ModENCODE::Chado::DBXref;
=pod

=head1 NAME

ModENCODE::Chado::DBXref - A class representing a simplified Chado
I<dbxref> object.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado B<dbxref>
table. It provides accessors for the various attributes of a database external
reference that are stored in the dbxref table itself, plus accessors for
relationships to certain other Chado tables (i.e. B<db>).

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. Therefore, many
of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_accession()|/get_accession() |
set_accession($accession)> or $obj->L<set_accession()|/get_accession() |
set_accession($accession)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new
ModENCODE::Chado::DBXref({ 'accession' =E<gt> 'AI515079', 'version' =E<gt> 1
});> will create a new DBXref object with an accession of 'AI515079' and a
version of 1. For complex types (other Chado objects), the default L<Class::Std>
setters and initializers have been replaced with subroutines that make sure the
type of the object being passed in is correct.

=back

=head2 Using ModENCODE::Chado::DBXref

=over

  my $dbxref = new ModENCODE::Chado::Feature({
    # Simple attributes
    'accession'         => 'AI515079',
    'version'           => 1,

    # Object relationships
    'db'                => new ModENCODE::Chado::DB()
  });

  $dbxref->set_accession('New Name);
  my $dbxref = $dbxref->get_accession();
  print $dbxref->to_string();

=back

=head1 ACCESSORS

=over

=item get_accession() | set_accession($accession)

The accession of this Chado external database reference; it corresponds to the
dbxref.accession field in a Chado database.

=item get_version() | set_version($version)

The version of this Chado external database reference; it corresponds to the
dbxref.version field in a Chado database.

=item get_db() | set_db($db) 

The external database containing this Chado external database reference term.
This must be a L<ModENCODE::Chado::DB> or conforming subclass (via C<isa>). The
database object corresponds to a database in the Chado db table, and the
dbxref.db_id field is used to track the relationship.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this external database reference and $obj are equal. Checks all
simple and complex attributes. Also requires that this object and $obj are of
the exact same type. (A parent class != a subclass, even if all attributes are
the same.)

=item clone()

Returns a deep copy of this object, recursing to clone all complex type
attributes.

=item to_string()

Return a string representation of this external database reference.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::DB>, L<ModENCODE::Chado::CVTerm>,
L<ModENCODE::Chado::Feature>, L<ModENCODE::Chado::Attribute>,
L<ModENCODE::Chado::Data>, L<ModENCODE::Chado::ExperimentProp>,
L<ModENCODE::Chado::Protocol>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

use strict;
use Class::Std;
use Carp qw(croak);
use ModENCODE::Cache;

# Attributes
my %dbxref_id        :ATTR( :name<id>,          :default<undef> );
my %dirty            :ATTR( :default<1> );
my %accession        :ATTR( :get<accession>,    :init_arg<accession> );
my %version          :ATTR( :get<version>,      :init_arg<version>,     :default<''> );

# Relationships
my %db               :ATTR( :init_arg<db> );

use Carp qw(confess);

sub dirty {
  $dirty{ident shift} = 1;
}

sub is_dirty {
  return $dirty{ident shift};
}

sub clean {
  $dirty{ident shift} = 0;
}

sub new_no_cache {
  return Class::Std::new(@_);
}

sub new {
  my $temp = Class::Std::new(@_);
  my $cached_dbxref = ModENCODE::Cache::get_cached_dbxref($temp);

  if ($cached_dbxref) {
    # Nothing to update
    return $cached_dbxref;
  }

  # This is a new DBXref
  my $self = $temp;
  return ModENCODE::Cache::add_dbxref_to_cache($self);
}

sub get_db_id {
  my $self = shift;
  return $db{ident $self} ? $db{ident $self}->get_id : undef;
}

sub get_db {
  my $self = shift;
  my $get_cached_object = shift || 0;
  my $db = $db{ident $self};
  return undef unless defined $db;
  return $get_cached_object ? $db{ident $self}->get_object : $db{ident $self};
}


sub to_string {
  my ($self) = @_;
  my $string = "[REF:" . $self->get_db()->get_object->to_string() . ".";
  $string .= ($self->get_accession() || "xxx");
  $string .= "(" . $self->get_version() . ")" if defined($self->get_version());
  $string .= "]";
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless $self == $other;
  return 1;
}

sub save {
  my $self = shift;
  if ($dirty{ident $self}) {
    $dirty{ident $self} = 0;
    ModENCODE::Cache::save_dbxref($self);
  }
}


1;

