package ModENCODE::Chado::DB;
=pod

=head1 NAME

ModENCODE::Chado::DB - A class representing a simplified Chado I<cv> object.

=head1 SYNOPSIS

This class is an object-oriented representation of an entry in a Chado
B<db> table. It provides accessors for the various attributes of
a Chado db object that are stored in the db table itself.

=head1 USAGE

=head2 Implications Of Class::Std

=over

As with all of the ModENCODE::Chado::* object classes, this module utilizes
L<Class::Std> to enforce object-oriented programming practices. For this class,
all of the accessor functions are automatically generated, and are of the form
<get|set>_<attribute>, e.g. $obj->L<get_name()|/get_name() | set_name($name)> or
$obj->L<set_name()|/get_name() | set_name($name)>.

ModENCODE::Chado::* objects can also be created with values at initialization
time by passing in a hash. For instance, C<my $obj = new ModENCODE::Chado::CV({
'name' =E<gt> 'dbEST', 'url' =E<gt> 'http://www.ncbi.nlm.nih.gov/dbEST/' });>
will create a new DB object with a name of 'dbEST' and a url of
'http://www.ncbi.nlm.nih.gov/dbEST/'.

=back

=head2 Using ModENCODE::Chado::DB

=over

  my $db = new ModENCODE::Chado::DB({
    # Simple attributes
    'name'              => 'dbEST',
    'url'               => 'http://www.ncbi.nlm.nih.gov/dbEST/',
    'description'       => 'NCBI EST database'
  });

  $db->set_description('New Description');
  my $definition = $db->get_description();
  print $db->to_string();

=back

=head1 ACCESSORS

=over

=item get_name() | set_name($name)

The name of this Chado database reference; it corresponds to the db.name field
in a Chado database.

=item get_url() | set_url($url)

The URL of this Chado database reference; it corresponds to the db.url field
in a Chado database.

=item get_description() | set_description($description)

The description of this Chado database reference; it corresponds to the
cv.description field in a Chado database.

=back

=head1 UTILITY FUNCTIONS

=over

=item equals($obj)

Returns true if this feature and $obj are equal. Checks all attributes. Also
requires that this object and $obj are of the exact same type.  (A parent class
!= a subclass, even if all attributes are the same.)

=item clone()

Returns a deep copy of this object. There are no complex objects that this
object can reference, so this just creates a copy of the existing attributes.

=item to_string()

Return a string representation of this database reference.

=back

=head1 SEE ALSO

L<Class::Std>, L<ModENCODE::Chado::DBXref>

=head1 AUTHOR

E.O. Stinson L<mailto:yostinso@berkeleybop.org>, ModENCODE DCC
L<http://www.modencode.org>.

=cut

use strict;
use Class::Std;
use Carp qw(croak);

my %all_dbs;

# Attributes
my %name             :ATTR( :name<name>,                :default<''> );
my %url              :ATTR( :name<url>,                 :default<undef> );
my %description      :ATTR( :name<description>,         :default<undef> );

sub new {
  my $self = Class::Std::new(@_);
  # Caching CVs
  my $cached_db = $all_dbs{$self->get_name()};
  if ($cached_db) {
    $cached_db->set_url($self->get_url()) if ($self->get_url() && !($cached_db->get_url));
    $cached_db->set_description($self->get_description()) if ($self->get_description() && !($cached_db->get_description));
    return $cached_db;
  }
  $all_dbs{$self->get_name()} = $self;
  return $self;
}

sub to_string {
  my ($self) = @_;
  my $string = $self->get_name();
  $string .= "(" if (defined($self->get_url()) || defined($self->get_description()));
  $string .= $self->get_description() . ":" if defined($self->get_description());
  $string .= $self->get_url() if defined($self->get_url());
  $string .= ")" if (defined($self->get_url()) || defined($self->get_description()));
  return $string;
}

sub equals {
  my ($self, $other) = @_;
  return 0 unless ref($self) eq ref($other);

  return 0 unless ($self->get_name() eq $other->get_name());

  return 1;
}

sub clone {
  my ($self) = @_;
  my $clone = new ModENCODE::Chado::DB({
      'name' => $self->get_name(),
      'url' => $self->get_url(),
      'description' => $self->get_description(),
    });
  return $clone;
}

1;
